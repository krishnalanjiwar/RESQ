import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final services = await bootstrap();
    runApp(ProviderScope(
      overrides: [appServicesProvider.overrideWithValue(services)],
      child: const ResqApp(),
    ));
  } on BootstrapException catch (e) {
    runApp(StartupErrorApp('Startup failed at: ${e.step}.'));
  }
}
