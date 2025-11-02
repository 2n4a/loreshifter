import 'package:flutter/material.dart';

class AppTheme {
  // Material You палитра: коричнево-песочно-зеленая (Google Pixel)
  static const Color primaryGreen = Color(0xFF6B8E23); // Оливково-зеленый
  static const Color primarySand = Color(0xFFD4A574); // Песочный
  static const Color primaryBrown = Color(0xFF8B7355); // Коричневый

  // Светлые оттенки
  static const Color lightGreen = Color(0xFF9CAF88);
  static const Color lightSand = Color(0xFFE8D4B8);
  static const Color lightBrown = Color(0xFFC4A384);

  // Темные оттенки
  static const Color darkGreen = Color(0xFF556B2F);
  static const Color darkSand = Color(0xFFB8956A);
  static const Color darkBrown = Color(0xFF6B5D4F);

  // Нейтральные цвета (мягкие)
  static const Color background = Color(0xFFFAF8F5); // Теплый белый
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F3F0);
  static const Color outline = Color(0xFFCAC4BF);
  static const Color outlineVariant = Color(0xFFE5E1DC);

  // Темная тема
  static const Color darkBackground = Color(0xFF1C1B1A);
  static const Color darkSurface = Color(0xFF28261F);
  static const Color darkSurfaceVariant = Color(0xFF3A3831);
  static const Color darkOutline = Color(0xFF534F47);
  static const Color darkOutlineVariant = Color(0xFF3E3B35);

  // Текстовые цвета
  static const Color onBackground = Color(0xFF1F1E1C);
  static const Color onSurface = Color(0xFF1F1E1C);
  static const Color onSurfaceVariant = Color(0xFF4D4A45);

  static const Color onDarkBackground = Color(0xFFE8E2DB);
  static const Color onDarkSurface = Color(0xFFE8E2DB);
  static const Color onDarkSurfaceVariant = Color(0xFFCFC9C1);

  // Акцентные цвета
  static const Color error = Color(0xFFB3261E);
  static const Color success = Color(0xFF6B8E23);
  static const Color warning = Color(0xFFD4A574);

  // Мягкие тени для карточек
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 16.0,
      offset: const Offset(0, 4),
    ),
  ];

  // Мягкие тени для поднятых элементов
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 20.0,
      offset: const Offset(0, 6),
    ),
  ];

  // Светлая тема
  static ThemeData lightTheme = ThemeData.light().copyWith(
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.light(
      primary: primaryGreen,
      onPrimary: Colors.white,
      primaryContainer: lightGreen,
      onPrimaryContainer: darkGreen,
      secondary: primarySand,
      onSecondary: onBackground,
      secondaryContainer: lightSand,
      onSecondaryContainer: darkSand,
      tertiary: primaryBrown,
      onTertiary: Colors.white,
      tertiaryContainer: lightBrown,
      onTertiaryContainer: darkBrown,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceVariant,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      error: error,
      onError: Colors.white,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: onSurface,
        fontSize: 22.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      iconTheme: IconThemeData(color: onSurfaceVariant),
      actionsIconTheme: IconThemeData(color: primaryGreen),
    ),

    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: outlineVariant, width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: primaryGreen,
        disabledForegroundColor: onSurfaceVariant.withValues(alpha: 0.38),
        disabledBackgroundColor: onSurface.withValues(alpha: 0.12),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: primaryGreen,
        disabledForegroundColor: onSurfaceVariant.withValues(alpha: 0.38),
        disabledBackgroundColor: onSurface.withValues(alpha: 0.12),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryGreen,
        disabledForegroundColor: onSurface.withValues(alpha: 0.38),
        backgroundColor: Colors.transparent,
        side: BorderSide(color: outline, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryGreen,
        disabledForegroundColor: onSurface.withValues(alpha: 0.38),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
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
      fillColor: surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(12.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(12.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: primaryGreen, width: 2),
        borderRadius: BorderRadius.circular(12.0),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: error, width: 1),
        borderRadius: BorderRadius.circular(12.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: error, width: 2),
      ),
      labelStyle: TextStyle(color: onSurfaceVariant, fontSize: 14),
      hintStyle: TextStyle(color: onSurfaceVariant.withValues(alpha: 0.6), fontSize: 14),
      errorStyle: TextStyle(color: error, fontSize: 12),
      helperStyle: TextStyle(color: onSurfaceVariant, fontSize: 12),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      elevation: 24,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28.0),
      ),
      titleTextStyle: TextStyle(
        color: onSurface,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      contentTextStyle: TextStyle(
        color: onSurfaceVariant,
        fontSize: 14,
        letterSpacing: 0.25,
      ),
    ),

    dividerTheme: DividerThemeData(
      color: outlineVariant,
      thickness: 1,
      space: 1,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryGreen;
        }
        return surfaceVariant;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.transparent;
        }
        return outline;
      }),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryGreen;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: BorderSide(color: outline, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primarySand,
      foregroundColor: onBackground,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primaryGreen,
      unselectedItemColor: onSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );

  // Темная тема
  static ThemeData darkTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: darkBackground,
    colorScheme: ColorScheme.dark(
      primary: lightGreen,
      onPrimary: darkGreen,
      primaryContainer: darkGreen,
      onPrimaryContainer: lightGreen,
      secondary: lightSand,
      onSecondary: darkSand,
      secondaryContainer: darkSand,
      onSecondaryContainer: lightSand,
      tertiary: lightBrown,
      onTertiary: darkBrown,
      tertiaryContainer: darkBrown,
      onTertiaryContainer: lightBrown,
      surface: darkSurface,
      onSurface: onDarkSurface,
      surfaceContainerHighest: darkSurfaceVariant,
      onSurfaceVariant: onDarkSurfaceVariant,
      outline: darkOutline,
      outlineVariant: darkOutlineVariant,
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: darkSurface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: onDarkSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: onDarkSurface,
        fontSize: 22.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      iconTheme: IconThemeData(color: onDarkSurfaceVariant),
      actionsIconTheme: IconThemeData(color: lightGreen),
    ),

    cardTheme: CardThemeData(
      color: darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: darkOutlineVariant, width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: darkGreen,
        backgroundColor: lightGreen,
        disabledForegroundColor: onDarkSurfaceVariant.withValues(alpha: 0.38),
        disabledBackgroundColor: onDarkSurface.withValues(alpha: 0.12),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: darkGreen,
        backgroundColor: lightGreen,
        disabledForegroundColor: onDarkSurfaceVariant.withValues(alpha: 0.38),
        disabledBackgroundColor: onDarkSurface.withValues(alpha: 0.12),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: lightGreen,
        disabledForegroundColor: onDarkSurface.withValues(alpha: 0.38),
        backgroundColor: Colors.transparent,
        side: BorderSide(color: darkOutline, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: lightGreen,
        disabledForegroundColor: onDarkSurface.withValues(alpha: 0.38),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
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
      fillColor: darkSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(12.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(12.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: lightGreen, width: 2),
        borderRadius: BorderRadius.circular(12.0),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFFFB4AB), width: 1),
        borderRadius: BorderRadius.circular(12.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: Color(0xFFFFB4AB), width: 2),
      ),
      labelStyle: TextStyle(color: onDarkSurfaceVariant, fontSize: 14),
      hintStyle: TextStyle(color: onDarkSurfaceVariant.withValues(alpha: 0.6), fontSize: 14),
      errorStyle: TextStyle(color: Color(0xFFFFB4AB), fontSize: 12),
      helperStyle: TextStyle(color: onDarkSurfaceVariant, fontSize: 12),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: darkSurface,
      elevation: 24,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28.0),
      ),
      titleTextStyle: TextStyle(
        color: onDarkSurface,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      contentTextStyle: TextStyle(
        color: onDarkSurfaceVariant,
        fontSize: 14,
        letterSpacing: 0.25,
      ),
    ),

    dividerTheme: DividerThemeData(
      color: darkOutlineVariant,
      thickness: 1,
      space: 1,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return darkGreen;
        }
        return darkOutline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return lightGreen;
        }
        return darkSurfaceVariant;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.transparent;
        }
        return darkOutline;
      }),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return lightGreen;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(darkGreen),
      side: BorderSide(color: darkOutline, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: lightSand,
      foregroundColor: darkSand,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: lightGreen,
      unselectedItemColor: onDarkSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );

  // =============================================================================
  // ОБРАТНАЯ СОВМЕСТИМОСТЬ: Устаревшие киберпанк-компоненты
  // =============================================================================

  // Старые неоновые цвета (маппим на новые)
  static const Color neonPink = error;
  static const Color neonBlue = primaryGreen;
  static const Color neonPurple = primaryBrown;
  static const Color neonGreen = success;
  static const Color neonOrange = warning;

  // Старые цвета поверхностей (маппим на новые)
  static const Color darkAccent = darkSurfaceVariant;
  static const Color darkCard = darkSurface;
  static const Color surfaceContainer = darkSurfaceVariant;
  static const Color surfaceContainerHigh = darkSurface;

  // Старые градиенты (заменяем на простые цвета)
  static const LinearGradient neonGradient = LinearGradient(
    colors: [primaryGreen, primarySand],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient greenToBlueGradient = LinearGradient(
    colors: [primaryGreen, primarySand],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleToPinkGradient = LinearGradient(
    colors: [primaryBrown, primarySand],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient subtleGradient = LinearGradient(
    colors: [darkSurface, darkSurfaceVariant],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Старые константы анимации
  static const Duration slowAnimation = Duration(milliseconds: 800);
  static const Duration normalAnimation = Duration(milliseconds: 400);
  static const Duration fastAnimation = Duration(milliseconds: 200);

  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve fastCurve = Curves.easeOut;
  static const Curve bounceCurve = Curves.elasticOut;

  // Старые тени (используем новые)
  static List<BoxShadow> neonShadow(Color color, {double intensity = 0.5}) {
    return cardShadow;
  }

  // Старые стили текста
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
    );
  }

  // Градиентный текст (теперь просто обычный текст)
  static Widget gradientText({
    required String text,
    required Gradient gradient,
    double fontSize = 16.0,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: primaryGreen,
      ),
    );
  }

  // Неоновый контейнер
  static Widget neonContainer({
    required Widget child,
    required Color borderColor,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: darkSurfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withAlpha(100), width: 1),
      ),
      child: child,
    );
  }

  // Неоновый прогресс-индикатор
  static Widget neonProgressIndicator({
    required Color color,
    double size = 40.0,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        color: color,
        strokeWidth: 3,
      ),
    );
  }

  // Анимированная неоновая кнопка
  static Widget animatedNeonButton({
    required String text,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        minimumSize: Size(double.infinity, 56),
      ),
      child: Text(text),
    );
  }

  // Неоновый разделитель
  static Widget neonDivider({
    required Color color,
    double indent = 0,
    double endIndent = 0,
  }) {
    return Divider(
      color: color.withAlpha(100),
      indent: indent,
      endIndent: endIndent,
    );
  }

  // Неоновая кнопка (простая версия)
  static Widget neonButton({
    required String text,
    required VoidCallback onPressed,
    required Color color,
    IconData? icon,
    double? width,
  }) {
    final buttonStyle = FilledButton.styleFrom(
      backgroundColor: color,
      minimumSize: Size(width ?? 120, 48),
    );

    if (icon != null) {
      return SizedBox(
        width: width,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(text),
          style: buttonStyle,
        ),
      );
    }
    return SizedBox(
      width: width,
      child: FilledButton(
        onPressed: onPressed,
        style: buttonStyle,
        child: Text(text),
      ),
    );
  }

  // Неоновая карточка
  static Widget neonCard({
    required Widget child,
    Color? borderColor,
    EdgeInsets? padding,
    VoidCallback? onTap,
    String? title,
  }) {
    Widget content = child;

    // Если есть заголовок, добавляем его
    if (title != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: borderColor ?? primaryGreen,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          child,
        ],
      );
    }

    final card = Container(
      padding: padding ?? EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (borderColor ?? primaryGreen).withAlpha(100),
          width: 1,
        ),
      ),
      child: content,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      );
    }

    return card;
  }
}
