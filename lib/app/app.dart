import 'package:aptechka/app/router.dart';
import 'package:aptechka/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';

class AptechkaApp extends ConsumerWidget {
  const AptechkaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(appControllerProvider).asData?.value.settings ??
        const AppSettings();
    return MaterialApp.router(
      title: 'Аптечка',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (settings.appearance) {
        AppAppearance.system => ThemeMode.system,
        AppAppearance.light => ThemeMode.light,
        AppAppearance.dark => ThemeMode.dark,
      },
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: _AppTextScaler(media.textScaler, settings.textScale),
          ),
          child: child!,
        );
      },
      routerConfig: appRouter,
    );
  }
}

class _AppTextScaler extends TextScaler {
  const _AppTextScaler(this.system, this.factor);
  final TextScaler system;
  final double factor;
  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;
  @override
  double get textScaleFactor => scale(14) / 14;
}
