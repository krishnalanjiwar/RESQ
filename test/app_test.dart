import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resq/app/app.dart';
import 'package:resq/app/bootstrap.dart';
import 'package:resq/app/mesh_runtime.dart';
import 'package:resq/app/providers.dart';
import 'package:resq/app/theme.dart';
import 'package:resq/core/clock.dart';
import 'package:resq/crypto/identity.dart';
import 'package:resq/crypto/signatures.dart';
import 'package:resq/data/resq_store.dart';
import 'package:resq/device/alerts.dart';
import 'package:resq/device/device_services.dart';
import 'package:resq/domain/models.dart';
import 'package:resq/mesh/sim_transport.dart';
import 'package:resq/node/resq_node.dart';
import 'package:resq/ui/brand.dart';

late ResqNode _node;
late AppServices _services;

Future<void> _pumpApp(WidgetTester tester) async {
  // A typical Android phone in portrait: 360 x 800 dp.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [appServicesProvider.overrideWithValue(_services)],
    child: const ResqApp(),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUpAll(() async {
    final identity = await LocalIdentity.generate();
    _node = await ResqNode.create(
      identity: identity,
      store: MemoryResqStore(),
      transport: SimRadio().attach('test-phone'),
      clock: ManualClock(),
      signatures: SignatureService(),
    );
    // The runtime is not started: no platform channels are touched in tests.
    final runtime = MeshRuntime(
      node: _node,
      battery: BatteryService(),
      location: LocationService(),
      permissions: PermissionsService(),
      foreground: ForegroundService(),
      alerts: AlertService(),
    );
    _services = AppServices(node: _node, runtime: runtime, keysRecovered: false);
  });

  group('Material 3 theme', () {
    test('light and dark schemes use Material 3', () {
      expect(ResqTheme.light.useMaterial3, isTrue);
      expect(ResqTheme.light.colorScheme.brightness, Brightness.light);
      expect(ResqTheme.dark.colorScheme.brightness, Brightness.dark);
    });
  });

  testWidgets('first launch shows the three role choices', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Works offline'), findsOneWidget);
    expect(find.byType(Wordmark), findsOneWidget);
    expect(find.byType(BrandMark), findsWidgets);
    await tester.scrollUntilVisible(find.text('Test and train'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('How will you use RES-Q?'), findsOneWidget);
    expect(find.text('I need help'), findsOneWidget);
    expect(find.text('I can help'), findsOneWidget);
    expect(find.text('Test and train'), findsOneWidget);
  });

  testWidgets('victim screen renders without layout errors and shows the SOS action', (tester) async {
    await _node.setRole(NodeRole.victim);
    await _pumpApp(tester);
    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('What is happening?'), findsOneWidget);
    expect(find.text('Mesh is off'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Need insulin for dad, ground floor flooded');
    await _settle(tester);
    await tester.scrollUntilVisible(find.text('How RES-Q reads this'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('How RES-Q reads this'), findsOneWidget);
    expect(find.text('Critical'), findsWidgets);

    // GPS is a platform call with no plugin in widget tests; send without location.
    await tester.scrollUntilVisible(find.text('Share my location'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Share my location'));
    await _settle(tester);
    // Back to the top so the SOS button is fully clear of the collapsed header.
    await tester.fling(find.byType(Scrollable).first, const Offset(0, 3000), 4000);
    await _settle(tester);
    await tester.tap(find.text('SOS'));
    // Signing uses real async work; let it finish outside the fake test clock.
    for (var i = 0; i < 10 && _node.mySos.isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    expect(_node.mySos, isNotEmpty, reason: 'tapping SOS must store the request');
    await _settle(tester);
    await tester.scrollUntilVisible(find.text('Waiting for a nearby phone'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Waiting for a nearby phone'), findsOneWidget);
    expect(find.text('Cancel request'), findsOneWidget);
  });

  testWidgets('responder screen renders without layout errors', (tester) async {
    await _node.setRole(NodeRole.responder);
    await _node.setProfile('staff nurse, boat hai');
    await _pumpApp(tester);
    expect(find.text('Matched to you'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Doctor / nurse'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Doctor / nurse'), findsOneWidget);
    expect(find.text('Boat'), findsOneWidget);
  });

  testWidgets('test & train screen renders all three tabs', (tester) async {
    await _node.setRole(NodeRole.diagnostics);
    await _pumpApp(tester);
    expect(find.text('Build simulated city'), findsOneWidget);
    await tester.tap(find.text('This phone'));
    await _settle(tester);
    expect(find.text('Nearby phones'), findsOneWidget);
    await tester.tap(find.text('Trust'));
    await _settle(tester);
    expect(find.text('Your fingerprint'), findsOneWidget);
  });

  testWidgets('status drawer opens and lists live status', (tester) async {
    await _node.setRole(NodeRole.victim);
    await _pumpApp(tester);
    await tester.tap(find.byTooltip('Status'));
    await _settle(tester);
    expect(find.text('Status'), findsWidgets);
    expect(find.text('Role'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Security'), 300, scrollable: find.byType(Scrollable).last);
    expect(find.text('Security'), findsOneWidget);
  });
}
