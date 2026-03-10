import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/dd_theme.dart';
import 'navigation/app_router.dart';

void main() {
  runApp(const ProviderScope(child: DingDongApp()));
}

class DingDongApp extends ConsumerWidget {
  const DingDongApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'DingDong',
      theme: DDTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
