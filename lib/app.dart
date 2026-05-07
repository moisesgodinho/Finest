import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/currency/exchange_rate_service.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

class FinestApp extends ConsumerWidget {
  const FinestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themePreference = ref.watch(themeControllerProvider);
    ref.watch(exchangeRatesBootstrapProvider);

    return MaterialApp.router(
      title: 'Finest',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themePreference.themeMode,
      routerConfig: router,
      builder: (context, child) {
        return AnnotatedRegion(
          value: AppTheme.systemOverlayStyleFor(context),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
