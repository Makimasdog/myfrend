import 'package:flutter/material.dart';

/// myfrends 品牌设计系统
class AppTheme {
  AppTheme._();

  // ========== 品牌色 ==========
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFFA29BFE);
  static const Color primaryDark = Color(0xFF4834D4);
  static const Color accent = Color(0xFF00CEC9);
  static const Color error = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF51CF66);

  // ========== 圆角 ==========
  static const double radiusXs = 6;
  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double radiusFull = 999;

  // ========== 间距 ==========
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  // ========== 阴影 ==========
  static List<BoxShadow> shadowSm(ColorScheme cs) => [
        BoxShadow(color: cs.shadow.withAlpha(15), blurRadius: 4, offset: const Offset(0, 2)),
      ];
  static List<BoxShadow> shadowMd(ColorScheme cs) => [
        BoxShadow(color: cs.shadow.withAlpha(20), blurRadius: 8, offset: const Offset(0, 4)),
      ];
  static List<BoxShadow> shadowLg(ColorScheme cs) => [
        BoxShadow(color: cs.shadow.withAlpha(25), blurRadius: 16, offset: const Offset(0, 8)),
      ];

  // ========== Light Theme ==========
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          primary: primary,
          secondary: accent,
          error: error,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FC),

        // AppBar
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF1A1A2E),
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
        ),

        // 卡片
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: spaceMd, vertical: spaceSm),
        ),

        // 输入框
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1F3F8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusLg),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusLg),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusLg),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusLg),
            borderSide: const BorderSide(color: error),
          ),
        ),

        // 按钮
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),

        // 导航栏
        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          height: 64,
          backgroundColor: Colors.white,
          indicatorColor: primary.withAlpha(30),
          labelTextStyle: WidgetStatePropertyAll(TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: primary,
          )),
          iconTheme: WidgetStateProperty.resolveWith((s) =>
            IconThemeData(color: s.contains(WidgetState.selected) ? primary : Colors.grey.shade500, size: 24),
          ),
        ),

        // 导航栏(桌面)
        navigationRailTheme: NavigationRailThemeData(
          elevation: 0,
          backgroundColor: Colors.white,
          indicatorColor: primary.withAlpha(25),
          selectedIconTheme: const IconThemeData(color: primary, size: 22),
          unselectedIconTheme: IconThemeData(color: Colors.grey.shade500, size: 22),
          selectedLabelTextStyle: const TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w600),
        ),

        // Chips
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusFull)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          labelStyle: const TextStyle(fontSize: 13),
        ),

        // Divider
        dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 0.5, space: 0),

        // Tab Bar
        tabBarTheme: TabBarThemeData(
          labelColor: primary,
          unselectedLabelColor: Colors.grey.shade500,
          indicatorColor: primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      );

  // ========== Dark Theme ==========
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
          primary: primaryLight,
          secondary: accent,
          error: error,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),

        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),

        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          color: const Color(0xFF1A1A2E),
          margin: const EdgeInsets.symmetric(horizontal: spaceMd, vertical: spaceSm),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E32),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusLg),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusLg),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusLg),
            borderSide: const BorderSide(color: primaryLight, width: 1.5),
          ),
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),

        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          height: 64,
          backgroundColor: const Color(0xFF1A1A2E),
          indicatorColor: primaryLight.withAlpha(30),
          labelTextStyle: WidgetStatePropertyAll(TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: primaryLight,
          )),
          iconTheme: WidgetStateProperty.resolveWith((s) =>
            IconThemeData(color: s.contains(WidgetState.selected) ? primaryLight : Colors.grey.shade600, size: 24),
          ),
        ),

        navigationRailTheme: NavigationRailThemeData(
          elevation: 0,
          backgroundColor: const Color(0xFF1A1A2E),
          indicatorColor: primaryLight.withAlpha(25),
          selectedIconTheme: const IconThemeData(color: primaryLight, size: 22),
          unselectedIconTheme: IconThemeData(color: Colors.grey.shade600, size: 22),
          selectedLabelTextStyle: const TextStyle(color: primaryLight, fontSize: 11, fontWeight: FontWeight.w600),
        ),

        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusFull)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          labelStyle: const TextStyle(fontSize: 13),
        ),

        dividerTheme: const DividerThemeData(color: Color(0xFF2A2A40), thickness: 0.5, space: 0),

        tabBarTheme: TabBarThemeData(
          labelColor: primaryLight,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: primaryLight,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      );
}
