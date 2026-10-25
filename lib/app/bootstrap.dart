import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/clock.dart';
import '../core/ids.dart';
import '../crypto/b64.dart';
import '../crypto/identity.dart';
import '../crypto/key_store.dart';
import '../crypto/signatures.dart';
import '../data/resq_store.dart';
import '../device/alerts.dart';
import '../device/device_services.dart';
import '../mesh/nearby_transport.dart';
import '../node/resq_node.dart';
import 'mesh_runtime.dart';

/// Everything the app needs, created once in a fixed order:
/// secure keys → encrypted storage → trust anchors → node → runtime.
class AppServices {
  const AppServices({required this.node, required this.runtime, required this.keysRecovered});

  final ResqNode node;
  final MeshRuntime runtime;

  /// True if secure storage was unreadable and keys were regenerated (e.g.
  /// after a restore or Keystore reset): local data started fresh.
  final bool keysRecovered;
}

class BootstrapException implements Exception {
  const BootstrapException(this.step, this.cause);

  final String step;
  final Object cause;

  @override
  String toString() => 'Startup failed at $step';
}

Future<AppServices> bootstrap() async {
  const secrets = SecureSecretStore();

  // Keys first. A Keystore that can't decrypt its own data (restored backup,
  // OS reset) must not brick the app: wipe the unreadable keys and start fresh.
  var recovered = false;
  LocalIdentity identity;
  List<int> storageKey;
  try {
    identity = await _loadOrCreateIdentity(secrets);
    storageKey = await _loadOrCreateStorageKey(secrets);
  } on Object {
    recovered = true;
    try {
      await secrets.delete('identity_v1');
      await secrets.delete('storage_key_v1');
      identity = await _loadOrCreateIdentity(secrets);
      storageKey = await _loadOrCreateStorageKey(secrets);
    } on Object catch (e) {
      throw BootstrapException('IDENTITY KEYS (secure storage)', e);
    }
  }

  final ResqStore store;
  try {
    store = await HiveResqStore.open(storageKey);
  } on Object catch (e) {
    throw BootstrapException('LOCAL STORAGE', e);
  }

  final anchors = <String>{};
  try {
    final json = jsonDecode(await rootBundle.loadString('assets/trust_anchors.json')) as Map<String, dynamic>;
    for (final a in (json['anchors'] as List? ?? const [])) {
      final key = a is Map ? a['key'] : a;
      if (key is String && key32Pattern.hasMatch(key)) anchors.add(key);
    }
  } on Object {
    // No provisioned anchors: users can still pin authorities in person.
  }

  final node = await ResqNode.create(
    identity: identity,
    store: store,
    transport: NearbyTransport(),
    clock: const SystemClock(),
    signatures: SignatureService(),
    provisionedAnchors: anchors,
  );

  final runtime = MeshRuntime(
    node: node,
    battery: BatteryService(),
    location: LocationService(),
    permissions: PermissionsService(),
    foreground: ForegroundService(),
    alerts: AlertService(),
  );
  await runtime.start();
  return AppServices(node: node, runtime: runtime, keysRecovered: recovered);
}

/// The identity seeds live only in OS-backed secure storage (Android Keystore).
Future<LocalIdentity> _loadOrCreateIdentity(SecretStore secrets) async {
  final saved = await secrets.read('identity_v1');
  final imported = saved == null ? null : await LocalIdentity.importSeeds(saved);
  if (imported != null) return imported;
  final fresh = await LocalIdentity.generate();
  await secrets.write('identity_v1', fresh.exportSeeds());
  return fresh;
}

/// 32-byte AES key for the local database, also held in secure storage.
Future<List<int>> _loadOrCreateStorageKey(SecretStore secrets) async {
  final saved = await secrets.read('storage_key_v1');
  final bytes = saved == null ? null : unb64(saved);
  if (bytes != null && bytes.length == 32) return bytes;
  final fresh = randomBytes(32);
  await secrets.write('storage_key_v1', b64(fresh));
  return fresh;
}
