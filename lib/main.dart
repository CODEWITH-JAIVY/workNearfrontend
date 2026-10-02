import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/push_service.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushService.init(); // no-op until Firebase is configured
  runApp(const ProviderScope(child: WorkNearApp()));
}

class WorkNearApp extends ConsumerWidget {
  const WorkNearApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'WorkNear',
        routerConfig: ref.watch(routerProvider),
        theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      );
}
