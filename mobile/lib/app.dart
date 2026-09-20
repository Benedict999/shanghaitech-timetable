import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'appearance/app_appearance.dart';
import 'data/appearance_repository.dart';
import 'features/home/home_page.dart';

class TimetableApp extends StatefulWidget {
  const TimetableApp({super.key});

  @override
  State<TimetableApp> createState() => _TimetableAppState();
}

class _TimetableAppState extends State<TimetableApp> {
  late final AppearanceController _appearance = AppearanceController(
    AppearanceRepository(),
  )..load();

  @override
  void dispose() {
    _appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appearance,
      builder: (context, _) {
        final appearance = _appearance.value;
        return MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          title: '上科大课表',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(appearance.preset, Brightness.light),
          darkTheme: buildAppTheme(appearance.preset, Brightness.dark),
          themeMode: themeModeFor(appearance),
          themeAnimationDuration: const Duration(milliseconds: 280),
          home: HomePage(appearanceController: _appearance),
        );
      },
    );
  }
}
