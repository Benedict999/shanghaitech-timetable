import 'package:flutter/material.dart';

enum AppThemePreset { clean, moon, shanghaitech }

enum TimetableCardStyle { solid, translucent }

enum AppThemePreference { system, light, dark, preset }

class AppAppearance {
  const AppAppearance({
    this.preset = AppThemePreset.clean,
    this.themePreference = AppThemePreference.preset,
    this.cardStyle = TimetableCardStyle.solid,
    this.backgroundPath,
    this.backgroundOverlay = .28,
    this.timetableSurfaceOpacity = .22,
    this.backgroundScale = 1,
    this.backgroundX = 0,
    this.backgroundY = 0,
  });

  final AppThemePreset preset;
  final AppThemePreference themePreference;
  final TimetableCardStyle cardStyle;
  final String? backgroundPath;
  final double backgroundOverlay;
  final double timetableSurfaceOpacity;
  final double backgroundScale;
  final double backgroundX;
  final double backgroundY;

  bool get hasBackground => backgroundPath?.isNotEmpty == true;

  AppAppearance copyWith({
    AppThemePreset? preset,
    AppThemePreference? themePreference,
    TimetableCardStyle? cardStyle,
    String? backgroundPath,
    bool clearBackground = false,
    double? backgroundOverlay,
    double? timetableSurfaceOpacity,
    double? backgroundScale,
    double? backgroundX,
    double? backgroundY,
  }) => AppAppearance(
    preset: preset ?? this.preset,
    themePreference: themePreference ?? this.themePreference,
    cardStyle: cardStyle ?? this.cardStyle,
    backgroundPath: clearBackground
        ? null
        : backgroundPath ?? this.backgroundPath,
    backgroundOverlay: backgroundOverlay ?? this.backgroundOverlay,
    timetableSurfaceOpacity:
        timetableSurfaceOpacity ?? this.timetableSurfaceOpacity,
    backgroundScale: backgroundScale ?? this.backgroundScale,
    backgroundX: backgroundX ?? this.backgroundX,
    backgroundY: backgroundY ?? this.backgroundY,
  );

  Map<String, dynamic> toJson({bool includePath = true}) => {
    'preset': preset.name,
    'themePreference': themePreference.name,
    'cardStyle': cardStyle.name,
    if (includePath) 'backgroundPath': backgroundPath,
    'backgroundOverlay': backgroundOverlay,
    'timetableSurfaceOpacity': timetableSurfaceOpacity,
    'backgroundScale': backgroundScale,
    'backgroundX': backgroundX,
    'backgroundY': backgroundY,
  };

  factory AppAppearance.fromJson(Map<String, dynamic> json) {
    T named<T extends Enum>(List<T> values, Object? raw, T fallback) =>
        values.where((value) => value.name == raw).firstOrNull ?? fallback;
    double numberInRange(
      Object? value,
      double fallback,
      double minimum,
      double maximum,
    ) {
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse('$value');
      return parsed?.clamp(minimum, maximum) ?? fallback;
    }

    double number(Object? value, double fallback) =>
        numberInRange(value, fallback, -1, 1);

    return AppAppearance(
      preset: named(
        AppThemePreset.values,
        json['preset'],
        AppThemePreset.clean,
      ),
      themePreference: named(
        AppThemePreference.values,
        json['themePreference'],
        AppThemePreference.preset,
      ),
      cardStyle: named(
        TimetableCardStyle.values,
        json['cardStyle'],
        TimetableCardStyle.solid,
      ),
      backgroundPath: json['backgroundPath']?.toString(),
      backgroundOverlay: number(json['backgroundOverlay'], .28).clamp(0, .75),
      timetableSurfaceOpacity: numberInRange(
        json['timetableSurfaceOpacity'],
        .22,
        0,
        .8,
      ),
      backgroundScale: numberInRange(json['backgroundScale'], 1, 1, 2.5),
      backgroundX: number(json['backgroundX'], 0),
      backgroundY: number(json['backgroundY'], 0),
    );
  }
}

class TimetableVisuals extends ThemeExtension<TimetableVisuals> {
  const TimetableVisuals({
    required this.coursePalette,
    required this.gridColor,
    required this.headerSurface,
  });

  final List<Color> coursePalette;
  final Color gridColor;
  final Color headerSurface;

  @override
  TimetableVisuals copyWith({
    List<Color>? coursePalette,
    Color? gridColor,
    Color? headerSurface,
  }) => TimetableVisuals(
    coursePalette: coursePalette ?? this.coursePalette,
    gridColor: gridColor ?? this.gridColor,
    headerSurface: headerSurface ?? this.headerSurface,
  );

  @override
  TimetableVisuals lerp(covariant TimetableVisuals? other, double t) {
    if (other == null) return this;
    return TimetableVisuals(
      coursePalette: List.generate(
        coursePalette.length,
        (index) => Color.lerp(
          coursePalette[index],
          other.coursePalette[index % other.coursePalette.length],
          t,
        )!,
      ),
      gridColor: Color.lerp(gridColor, other.gridColor, t)!,
      headerSurface: Color.lerp(headerSurface, other.headerSurface, t)!,
    );
  }
}

ThemeMode themeModeFor(AppAppearance value) => switch (value.themePreference) {
  AppThemePreference.system => ThemeMode.system,
  AppThemePreference.light => ThemeMode.light,
  AppThemePreference.dark => ThemeMode.dark,
  AppThemePreference.preset =>
    value.preset == AppThemePreset.moon ? ThemeMode.dark : ThemeMode.light,
};

ThemeData buildAppTheme(AppThemePreset preset, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final seed = switch (preset) {
    AppThemePreset.clean => const Color(0xFF006D77),
    AppThemePreset.moon => const Color(0xFF8195FF),
    AppThemePreset.shanghaitech => const Color(0xFF9D2235),
  };
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final background = dark
      ? const Color(0xFF0E1320)
      : preset == AppThemePreset.shanghaitech
      ? const Color(0xFFFAF6F5)
      : const Color(0xFFF6F8F8);
  final palette = dark
      ? const [
          Color(0xFF315C66),
          Color(0xFF6C493F),
          Color(0xFF665B2F),
          Color(0xFF3D4D7A),
          Color(0xFF594873),
          Color(0xFF395E47),
          Color(0xFF70465A),
          Color(0xFF3D5A6D),
        ]
      : preset == AppThemePreset.shanghaitech
      ? const [
          Color(0xFFF1CACF),
          Color(0xFFD5E7ED),
          Color(0xFFF2DDAF),
          Color(0xFFD7DDF4),
          Color(0xFFE2D4E9),
          Color(0xFFCFE5D8),
          Color(0xFFECCFDB),
          Color(0xFFD1E1EB),
        ]
      : const [
          Color(0xFFB8E3E8),
          Color(0xFFFFD5C7),
          Color(0xFFFFE9A8),
          Color(0xFFC9D7FF),
          Color(0xFFDCC9F5),
          Color(0xFFBFE3CA),
          Color(0xFFF3C4DA),
          Color(0xFFC7DFEF),
        ];
  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: dark ? const Color(0xFF171E2D) : scheme.surface,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    extensions: [
      TimetableVisuals(
        coursePalette: palette,
        gridColor: dark
            ? Colors.white.withValues(alpha: .22)
            : Colors.black.withValues(alpha: .20),
        headerSurface: dark
            ? const Color(0xD90E1320)
            : Colors.white.withValues(alpha: .88),
      ),
    ],
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
