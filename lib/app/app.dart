import 'package:aptechka/app/router.dart';
import 'package:aptechka/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class AptechkaApp extends StatelessWidget {
  const AptechkaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Аптечка',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
