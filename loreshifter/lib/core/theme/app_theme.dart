import 'package:flutter/material.dart';

class AppTheme {
  // Основные цвета киберпанк-тематики
  static const Color neonPink = Color(0xFFFF2A6D);
  static const Color neonBlue = Color(0xFF00F9FF);
  static const Color neonPurple = Color(0xFF9A5AF2);
  static const Color neonGreen = Color(0xFF05FFA1);
  static const Color darkBackground = Color(0xFF0D0221);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkAccent = Color(0xFF242447);

  // Градиенты
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

  // Тени для неонового эффекта
  static List<BoxShadow> neonShadow(Color color) {
    return [
      BoxShadow(
        color: color.withAlpha(127), // 50% прозрачность
        blurRadius: 8.0,
        spreadRadius: 1.0,
      ),
      BoxShadow(
        color: color.withAlpha(76), // 30% прозрачность
        blurRadius: 16.0,
        spreadRadius: 2.0,
      ),
    ];
  }

  // Стиль для текста с неоновым эффектом
  static TextStyle neonTextStyle({
    required Color color,
    double fontSize = 16.0,
    FontWeight fontWeight = FontWeight.bold,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      shadows: [
        Shadow(
          blurRadius: 10.0,
          color: color.withAlpha(178), // 70% прозрачность
          offset: const Offset(0, 0),
        ),
        Shadow(
          blurRadius: 5.0,
          color: color.withAlpha(127), // 50% прозрачность
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
      secondary: neonPink,
      tertiary: neonPurple,
      // background устарел, используем surface вместо него
      surface: darkBackground,
      surfaceVariant: darkSurface,
      error: neonPink,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: darkBackground,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: neonTextStyle(
        color: Colors.white,
        fontSize: 20.0,
      ),
    ),
    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: neonPurple,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
        textStyle: const TextStyle(
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: neonBlue,
        side: const BorderSide(color: neonBlue, width: 2.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
        textStyle: const TextStyle(
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: neonGreen,
        textStyle: const TextStyle(
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkAccent,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: neonBlue, width: 2.0),
      ),
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white30),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkAccent,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: neonBlue,
      unselectedLabelColor: Colors.white60,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        gradient: neonGradient,
        borderRadius: BorderRadius.circular(10.0),
      ),
    ),
    dividerColor: neonPurple.withAlpha(51), // 20% прозрачность
    chipTheme: ChipThemeData(
      backgroundColor: darkAccent,
      disabledColor: darkAccent.withAlpha(127), // 50% прозрачность
      selectedColor: neonPurple,
      secondarySelectedColor: neonBlue,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      labelStyle: const TextStyle(color: Colors.white),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
    ),
    iconTheme: const IconThemeData(
      color: neonBlue,
      size: 24.0,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: neonPink,
      foregroundColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
    ),
  );

  // Стилизованный контейнер с неоновой рамкой
  static Widget neonContainer({
    required Widget child,
    Color borderColor = neonBlue,
    double width = double.infinity,
    double? height,
    EdgeInsets padding = const EdgeInsets.all(16.0),
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: borderRadius ?? BorderRadius.circular(16.0),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
        boxShadow: neonShadow(borderColor),
      ),
      child: child,
    );
  }

  // Стилизованная кнопка с неоновым эффектом
  static Widget neonButton({
    required String text,
    required VoidCallback onPressed,
    Color color = neonBlue,
    double width = double.infinity,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: neonShadow(color),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withAlpha(178)], // 70% прозрачность
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Container(
            alignment: Alignment.center,
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Градиентный текст
  static Widget gradientText({
    required String text,
    required Gradient gradient,
    double fontSize = 16.0,
    FontWeight fontWeight = FontWeight.bold,
    TextAlign textAlign = TextAlign.center,
  }) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: Colors.white,
        ),
        textAlign: textAlign,
      ),
    );
  }

  // Анимированная неоновая кнопка
  static Widget animatedNeonButton({
    required String text,
    required VoidCallback onPressed,
    Color color = neonBlue,
    double width = double.infinity,
    Duration pulseDuration = const Duration(seconds: 2),
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        // Используем AnimationController для создания пульсации
        final AnimationController controller = AnimationController(
          duration: pulseDuration,
          vsync: Scaffold.of(context),
        )..repeat(reverse: true);

        // Анимация для изменения интенсивности свечения
        final Animation<double> glowAnimation = Tween<double>(
          begin: 1.0,
          end: 2.0,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ));

        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Container(
              width: width,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha(((0.3 + (0.2 * glowAnimation.value)) * 255).toInt()),
                    blurRadius: 8.0 * glowAnimation.value,
                    spreadRadius: 1.0 * glowAnimation.value,
                  ),
                  BoxShadow(
                    color: color.withAlpha(((0.2 + (0.1 * glowAnimation.value)) * 255).toInt()),
                    blurRadius: 16.0 * glowAnimation.value,
                    spreadRadius: 2.0 * glowAnimation.value,
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        Color.lerp(color, Colors.white, 0.2 * glowAnimation.value)!,
                        color,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        shadows: [
                          Shadow(
                            blurRadius: 5.0 * glowAnimation.value,
                            color: Colors.white.withAlpha(127), // 50% прозрачность
                            offset: Offset.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Неоновая карточка с контентом
  static Widget neonCard({
    required Widget child,
    required String title,
    Color borderColor = neonBlue,
    Color titleColor = neonGreen,
    double width = double.infinity,
    EdgeInsets padding = const EdgeInsets.all(16.0),
    EdgeInsets contentPadding = const EdgeInsets.all(16.0),
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
        boxShadow: neonShadow(borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок карточки с градиентом
          Container(
            padding: padding.copyWith(bottom: 0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: borderColor,
                  width: 1.5,
                ),
              ),
            ),
            width: double.infinity,
            child: Text(
              title,
              style: neonTextStyle(
                color: titleColor,
                fontSize: 18.0,
              ),
            ),
          ),
          // Основной контент
          Padding(
            padding: contentPadding,
            child: child,
          ),
        ],
      ),
    );
  }

  // Неоновый индикатор загрузки
  static Widget neonProgressIndicator({
    double size = 40.0,
    Color color = neonBlue,
    double strokeWidth = 3.0,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Тень для неонового эффекта
          Center(
            child: Container(
              width: size * 0.9,
              height: size * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: neonShadow(color),
              ),
            ),
          ),
          // Сам индикатор
          CircularProgressIndicator(
            strokeWidth: strokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  // Стилизованный разделитель с неоновым эффектом
  static Widget neonDivider({
    Color color = neonPurple,
    double height = 1.0,
    double indent = 0.0,
    double endIndent = 0.0,
  }) {
    return Container(
      height: height,
      margin: EdgeInsetsDirectional.only(
        start: indent,
        end: endIndent,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            color,
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: neonShadow(color),
      ),
    );
  }

  // Таблица в киберпанк-стиле
  static Widget neonDataTable({
    required List<String> columns,
    required List<List<Widget>> rows,
    Color headerColor = neonGreen,
    Color borderColor = neonPurple,
    double columnSpacing = 24,
    double headingRowHeight = 56,
    double dataRowHeight = 52,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: 1.0,
        ),
        boxShadow: neonShadow(borderColor.withAlpha(127)), // 50% прозрачность
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Заголовок таблицы
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [darkAccent, Color.lerp(darkAccent, headerColor, 0.1)!],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            height: headingRowHeight,
            child: Row(
              children: columns.map((column) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      column,
                      style: neonTextStyle(
                        color: headerColor,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Строки таблицы
          ...rows.map((row) {
            return Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: borderColor.withAlpha(76), // 30% прозрачность
                    width: 1.0,
                  ),
                ),
              ),
              height: dataRowHeight,
              child: Row(
                children: row.map((cell) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: cell,
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
