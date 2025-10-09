import 'package:flutter/material.dart';

class AppTheme {
  // Основные цвета киберпанк-тематики
  static const Color neonPink = Color(0xFFFF2A6D);
  static const Color neonBlue = Color(0xFF00F9FF);
  static const Color neonPurple = Color(0xFF9A5AF2);
  static const Color neonGreen = Color(0xFF05FFA1);
  static const Color neonOrange = Color(0xFFFF6B35);
  static const Color darkBackground = Color(0xFF0D0221);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkAccent = Color(0xFF242447);
  static const Color darkCard = Color(0xFF2D2D5F);

  // Дополнительные цвета для улучшенной палитры
  static const Color surfaceContainer = Color(0xFF1E1E3F);
  static const Color surfaceContainerHigh = Color(0xFF252560);
  static const Color outline = Color(0xFF4A4A7C);
  static const Color outlineVariant = Color(0xFF3A3A6C);

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

  // Новый пульсирующий градиент для анимаций
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

  // Улучшенные тени для неонового эффекта
  static List<BoxShadow> neonShadow(Color color, {double intensity = 1.0}) {
    return [
      BoxShadow(
        color: color.withAlpha((127 * intensity).round()),
        blurRadius: 8.0 * intensity,
        spreadRadius: 1.0 * intensity,
      ),
      BoxShadow(
        color: color.withAlpha((76 * intensity).round()),
        blurRadius: 16.0 * intensity,
        spreadRadius: 2.0 * intensity,
      ),
      BoxShadow(
        color: color.withAlpha((51 * intensity).round()),
        blurRadius: 24.0 * intensity,
        spreadRadius: 3.0 * intensity,
      ),
    ];
  }

  // Мягкие тени для карточек
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withAlpha(51),
      blurRadius: 16.0,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: neonPurple.withAlpha(25),
      blurRadius: 8.0,
      offset: const Offset(0, 2),
    ),
  ];

  // Стиль для текста с неоновым эффектом
  static TextStyle neonTextStyle({
    required Color color,
    double fontSize = 16.0,
    FontWeight fontWeight = FontWeight.bold,
    double intensity = 1.0,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 0.5,
      shadows: [
        Shadow(
          blurRadius: 10.0 * intensity,
          color: color.withAlpha((178 * intensity).round()),
          offset: const Offset(0, 0),
        ),
        Shadow(
          blurRadius: 5.0 * intensity,
          color: color.withAlpha((127 * intensity).round()),
          offset: const Offset(0, 0),
        ),
      ],
    );
  }

  // Основная тема приложения с Material Design 3
  static ThemeData darkTheme = ThemeData.dark().copyWith(
    useMaterial3: true,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark().copyWith(
      primary: neonBlue,
      onPrimary: Colors.black,
      primaryContainer: neonBlue.withAlpha(51),
      onPrimaryContainer: neonBlue,
      secondary: neonPink,
      onSecondary: Colors.white,
      secondaryContainer: neonPink.withAlpha(51),
      onSecondaryContainer: neonPink,
      tertiary: neonPurple,
      onTertiary: Colors.white,
      tertiaryContainer: neonPurple.withAlpha(51),
      onTertiaryContainer: neonPurple,
      surface: darkBackground,
      surfaceVariant: darkSurface,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      onSurface: Colors.white,
      onSurfaceVariant: Colors.white70,
      outline: outline,
      outlineVariant: outlineVariant,
      error: neonPink,
      onError: Colors.white,
      errorContainer: neonPink.withAlpha(51),
      onErrorContainer: neonPink,
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
        fontWeight: FontWeight.w500,
        intensity: 0.3,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: neonBlue),
    ),

    cardTheme: CardThemeData(
      color: darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(color: outline.withAlpha(76), width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: neonPurple,
        disabledForegroundColor: Colors.white38,
        disabledBackgroundColor: Colors.white12,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) {
            return neonPink.withAlpha(51);
          }
          if (states.contains(WidgetState.hovered)) {
            return neonBlue.withAlpha(25);
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
          borderRadius: BorderRadius.circular(16.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: neonBlue,
        disabledForegroundColor: Colors.white38,
        backgroundColor: Colors.transparent,
        side: BorderSide(color: neonBlue, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ).copyWith(
        side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: Colors.white38, width: 1.5);
          }
          if (states.contains(WidgetState.pressed)) {
            return BorderSide(color: neonPink, width: 1.5);
          }
          return BorderSide(color: neonBlue, width: 1.5);
        }),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: neonGreen,
        disabledForegroundColor: Colors.white38,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        minimumSize: const Size(64, 40),
        textStyle: const TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceContainer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide(color: outline, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide(color: outline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide(color: neonBlue, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide(color: neonPink, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide(color: neonPink, width: 2.0),
      ),
      labelStyle: TextStyle(color: Colors.white70, fontSize: 16),
      hintStyle: TextStyle(color: Colors.white38, fontSize: 16),
      errorStyle: TextStyle(color: neonPink, fontSize: 12),
      helperStyle: TextStyle(color: Colors.white60, fontSize: 12),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
      titleTextStyle: neonTextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.w500,
        intensity: 0.3,
      ),
      contentTextStyle: const TextStyle(
        color: Colors.white70,
        fontSize: 16,
        letterSpacing: 0.25,
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceContainerHigh,
      contentTextStyle: const TextStyle(color: Colors.white),
      actionTextColor: neonBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      elevation: 8,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: darkSurface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: darkSurface,
      elevation: 16,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
    ),

    dividerColor: outline.withAlpha(76),
    dividerTheme: DividerThemeData(
      color: outline.withAlpha(76),
      thickness: 1,
      space: 1,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: surfaceContainer,
      disabledColor: surfaceContainer.withAlpha(127),
      selectedColor: neonPurple.withAlpha(127),
      secondarySelectedColor: neonBlue.withAlpha(127),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: const TextStyle(color: Colors.white, fontSize: 14),
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 14),
      brightness: Brightness.dark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: outline.withAlpha(76)),
      ),
    ),

    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      selectedTileColor: neonPurple.withAlpha(25),
      iconColor: Colors.white70,
      textColor: Colors.white,
      selectedColor: neonBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          return neonBlue.withAlpha(127);
        }
        return Colors.white38;
      }),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return neonBlue;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.black),
      side: BorderSide(color: outline, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),

    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return neonBlue;
        }
        return outline;
      }),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: neonBlue,
      inactiveTrackColor: outline,
      thumbColor: neonBlue,
      overlayColor: neonBlue.withAlpha(51),
      valueIndicatorColor: neonPurple,
      valueIndicatorTextStyle: const TextStyle(color: Colors.white),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: neonBlue,
      linearTrackColor: outline.withAlpha(76),
      circularTrackColor: outline.withAlpha(76),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: neonPurple,
      foregroundColor: Colors.white,
      elevation: 6,
      highlightElevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      height: 80,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            color: neonBlue,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }
        return const TextStyle(
          color: Colors.white60,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: neonBlue, size: 24);
        }
        return const IconThemeData(color: Colors.white60, size: 24);
      }),
      indicatorColor: neonBlue.withAlpha(51),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: neonBlue,
      unselectedItemColor: Colors.white60,
      selectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
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

  // Градиентный текст
  static Widget gradientText({
    required String text,
    required Gradient gradient,
    double fontSize = 16.0,
    FontWeight fontWeight = FontWeight.normal,
    TextAlign? textAlign,
  }) {
    return ShaderMask(
      shaderCallback:
          (bounds) => gradient.createShader(
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
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon:
            icon != null
                ? Icon(icon, color: Colors.white)
                : const SizedBox.shrink(),
        label: Text(
          text,
          style: neonTextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            intensity: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
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
