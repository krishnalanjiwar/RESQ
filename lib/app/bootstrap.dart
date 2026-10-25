import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/clock.dart';
import '../crypto/b64.dart';
import '../crypto/identity.dart';
import '../crypto/key_store.dart';
import '../crypto/signatures.dart';
import '../data/resq_store.dart';
import '../device/device_services.dart';
import '../mesh/nearby_transport.dart';
import '../node/resq_node.dart';

/// Everything the app needs, created once in a fixed order:
/// storage → identity (secure storage) → trust anchors → node.
class AppServices {
  const AppServices({
    required this.node,
    required this.battery,
    required this.location,
    required this.permissions,
    required this.foreground,
  });

  final ResqNode node;
  final BatteryService battery;
  final LocationService location;
  final PermissionsService permissions;
  final ForegroundService foreground;
}

class BootstrapException implements Exception {
  const BootstrapException(this.step, this.cause);

  final String step;
  final Object cause;

  @override
  String toString() => 'Startup failed at $step';
}

Future<AppServices> bootstrap() async {
  final ResqStore store;
  try {
    store = await HiveResqStore.open();
  } on Object catch (e) {
    throw BootstrapException('LOCAL STORAGE', e);
  }

  final LocalIdentity identity;
  try {
    identity = await _loadOrCreateIdentity(const SecureSecretStore());
  } on Object catch (e) {
    throw BootstrapException('IDENTITY KEYS (secure storage)', e);
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

  return AppServices(
    node: node,
    battery: BatteryService(),
    location: LocationService(),
    permissions: PermissionsService(),
    foreground: ForegroundService(),
  );
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
