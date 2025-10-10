import 'package:flutter/material.dart';

class AppTheme {
  // Основные цвета киберпанк-тематики (акцентные)
  static const Color neonPink = Color(0xFFFF2A6D);
  static const Color neonBlue = Color(0xFF00F9FF);
  static const Color neonPurple = Color(0xFF9A5AF2);
  static const Color neonGreen = Color(0xFF05FFA1);
  static const Color neonOrange = Color(0xFFFF6B35);

  // Нейтральные темные поверхности (менее насыщенные)
  static const Color darkBackground = Color(0xFF0D0F12);
  static const Color darkSurface = Color(0xFF141821);
  static const Color darkAccent = Color(0xFF1B2330);
  static const Color darkCard = Color(0xFF1E2836);

  // Доп. цвета
  static const Color surfaceContainer = Color(0xFF1A2130);
  static const Color surfaceContainerHigh = Color(0xFF202A3A);
  static const Color outline = Color(0xFF3E4A5C);
  static const Color outlineVariant = Color(0xFF2C3646);

  // Современные градиенты
  static const LinearGradient neonGradient = LinearGradient(
    colors: [neonBlue, neonPurple, neonPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient greenToBlueGradient = LinearGradient(
    colors: [neonGreen, neonBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleToPinkGradient = LinearGradient(
    colors: [neonPurple, neonPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient subtleGradient = LinearGradient(
    colors: [darkSurface, darkCard],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient pulsingGradient(Animation<double> animation) {
    return LinearGradient(
      colors: [
        Color.lerp(neonBlue, neonPurple, animation.value)!,
        Color.lerp(neonPurple, neonPink, animation.value)!,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // Мягкое неоновое свечение по умолчанию
  static List<BoxShadow> neonShadow(Color color, {double intensity = 0.5}) {
    return [
      BoxShadow(
        color: color.withAlpha((90 * intensity).round()),
        blurRadius: 6.0 * intensity,
        spreadRadius: 0.5 * intensity,
      ),
      BoxShadow(
        color: color.withAlpha((50 * intensity).round()),
        blurRadius: 12.0 * intensity,
        spreadRadius: 1.0 * intensity,
      ),
    ];
  }

  // Мягкие тени для карточек
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withAlpha(64),
          blurRadius: 14.0,
          offset: const Offset(0, 6),
        ),
      ];

  // Стиль неон-текста — точечно
  static TextStyle neonTextStyle({
    required Color color,
    double fontSize = 16.0,
    FontWeight fontWeight = FontWeight.w600,
    double intensity = 0.2,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 0.25,
      shadows: [
        Shadow(
          blurRadius: 6.0 * intensity,
          color: color.withAlpha((120 * intensity).round()),
          offset: const Offset(0, 0),
        ),
      ],
    );
  }

  // Основная тема приложения
  static ThemeData darkTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark().copyWith(
      primary: neonBlue,
      onPrimary: Colors.black,
      primaryContainer: Color(0x3300F9FF),
      onPrimaryContainer: neonBlue,
      secondary: neonPurple,
      onSecondary: Colors.white,
      secondaryContainer: Color(0x339A5AF2),
      onSecondaryContainer: neonPurple,
      tertiary: neonPink,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0x33FF2A6D),
      onTertiaryContainer: neonPink,
      surface: darkBackground,
      surfaceContainerHighest: darkSurface,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      onSurface: Colors.white,
      onSurfaceVariant: Colors.white70,
      outline: outline,
      outlineVariant: outlineVariant,
      error: neonOrange,
      onError: Colors.black,
      errorContainer: Color(0x33FF6B35),
      onErrorContainer: neonOrange,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: darkBackground,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: neonTextStyle(
        color: Colors.white,
        fontSize: 22.0,
        fontWeight: FontWeight.w600,
        intensity: 0.12,
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
      actionsIconTheme: IconThemeData(color: neonBlue.withAlpha(220)),
    ),

    cardTheme: CardThemeData(
      color: darkCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: outline.withAlpha(90), width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: darkAccent,
        disabledForegroundColor: Colors.white38,
        disabledBackgroundColor: Colors.white12,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
        minimumSize: const Size(64, 44),
        textStyle: const TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) {
            return neonBlue.withAlpha(40);
          }
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
            return Colors.white.withAlpha(20);
          }
          return null;
        }),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: neonBlue,
        disabledForegroundColor: Colors.white38,
        disabledBackgroundColor: Colors.white12,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
        minimumSize: const Size(64, 44),
        textStyle: const TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ).copyWith(
        overlayColor: WidgetStateProperty.all(neonPink.withAlpha(26)),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white38,
        backgroundColor: Colors.transparent,
        side: BorderSide(color: outline, width: 1.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
        minimumSize: const Size(64, 44),
        textStyle: const TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ).copyWith(
        side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: Colors.white24, width: 1.25);
          }
          if (states.contains(WidgetState.pressed) || states.contains(WidgetState.focused)) {
            return BorderSide(color: neonBlue, width: 1.5);
          }
          return BorderSide(color: outline, width: 1.25);
        }),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: neonGreen.withAlpha(230),
        disabledForegroundColor: Colors.white38,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        minimumSize: const Size(64, 40),
        textStyle: const TextStyle(
          fontSize: 14.0,
          letterSpacing: 0.1,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: outline, width: 1.0),
        borderRadius: BorderRadius.circular(14.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: outline, width: 1.0),
        borderRadius: BorderRadius.circular(14.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: neonBlue, width: 1.5),
        borderRadius: BorderRadius.circular(14.0),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: neonOrange, width: 1.0),
        borderRadius: BorderRadius.circular(14.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: BorderSide(color: neonOrange, width: 1.5),
      ),
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
      errorStyle: const TextStyle(color: Colors.white70, fontSize: 12),
      helperStyle: const TextStyle(color: Colors.white60, fontSize: 12),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: darkSurface,
      elevation: 16,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0), side: BorderSide(color: outlineVariant)),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: const TextStyle(
        color: Colors.white70,
        letterSpacing: 0.25,
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceContainerHigh,
      contentTextStyle: const TextStyle(color: Colors.white),
      actionTextColor: neonBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0), side: BorderSide(color: outlineVariant)),
      elevation: 6,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: darkSurface,
      modalBackgroundColor: darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
    ),

    dividerColor: outline.withAlpha(80),
    dividerTheme: DividerThemeData(
      color: outline.withAlpha(80),
      space: 1,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: surfaceContainer,
      disabledColor: surfaceContainer.withAlpha(127),
      selectedColor: neonBlue.withAlpha(50),
      secondarySelectedColor: neonBlue.withAlpha(80),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      labelStyle: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      brightness: Brightness.dark,
      side: BorderSide(color: outline.withAlpha(90)),
    ),

    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      selectedTileColor: neonBlue.withAlpha(24),
      iconColor: Colors.white70,
      textColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return neonBlue;
        }
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return neonBlue.withAlpha(110);
        }
        return Colors.white24;
      }),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return neonBlue;
        }
        return Colors.transparent;
      }),
      side: BorderSide(color: outline, width: 1.5),
    ),

    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return neonBlue;
        }
        return outline;
      }),
    ),
  );

  // Анимации
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);

  static const Curve defaultCurve = Curves.easeInOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve fastCurve = Curves.easeOutQuart;

  // Недостающие компоненты UI
  static Widget gradientText({
    required String text,
    required Gradient gradient,
    double fontSize = 16.0,
    FontWeight fontWeight = FontWeight.normal,
    TextAlign? textAlign,
  }) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
        textAlign: textAlign,
      ),
    );
  }

  // Неоновый контейнер
  static Widget neonContainer({
    required Widget child,
    required Color borderColor,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double borderWidth = 2.0,
    Color? backgroundColor,
  }) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: neonShadow(borderColor, intensity: 0.3),
      ),
      child: child,
    );
  }

  // Неоновый прогресс индикатор
  static Widget neonProgressIndicator({
    required Color color,
    double size = 40.0,
    double strokeWidth = 4.0,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: neonShadow(color, intensity: 0.5),
      ),
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color,
        backgroundColor: color.withAlpha(51),
      ),
    );
  }

  // Анимированная неоновая кнопка
  static Widget animatedNeonButton({
    required String text,
    required VoidCallback onPressed,
    required Color color,
    IconData? icon,
    double? width,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: neonShadow(color, intensity: 0.4),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: neonTextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                intensity: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Неоновый разделитель
  static Widget neonDivider({
    required Color color,
    double height = 1.0,
    double? indent,
    double? endIndent,
  }) {
    return Container(
      margin: EdgeInsets.only(left: indent ?? 0, right: endIndent ?? 0),
      height: height,
      decoration: BoxDecoration(
        color: color,
        boxShadow: neonShadow(color, intensity: 0.6),
      ),
    );
  }

  // Неоновая кнопка (простая версия)
  static Widget neonButton({
    required String text,
    required VoidCallback onPressed,
    Color? color,
    IconData? icon,
    double? width,
  }) {
    final buttonColor = color ?? neonPurple;
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: neonShadow(buttonColor, intensity: 0.3),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Неоновая карточка
  static Widget neonCard({
    required Widget child,
    String? title,
    Color? borderColor,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    VoidCallback? onTap,
  }) {
    final cardBorderColor = borderColor ?? neonBlue;
    return Container(
      margin: margin ?? const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor, width: 1),
        boxShadow: neonShadow(cardBorderColor, intensity: 0.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title,
                    style: neonTextStyle(
                      color: cardBorderColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      intensity: 0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
