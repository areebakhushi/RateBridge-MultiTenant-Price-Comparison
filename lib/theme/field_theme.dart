import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_navigation.dart';

/// Field User Panel design system — isolated from app-wide AppColors.
class FieldColors {
  FieldColors._();

  static const primaryNavy = Color(0xFF1E326E);
  static const primaryNavyDark = Color(0xFF15204A);
  static const accentAmber = Color(0xFFFBB03C);
  static const accentAmberSoft = Color(0xFFFFF7ED);
  static const screenBackground = Color(0xFFF4F5F9);
  static const surfaceWhite = Color(0xFFFFFFFF);
  static const borderSubtle = Color(0xFFE2E5F0);
  static const textPrimary = Color(0xFF1A1F36);
  static const textSecondary = Color(0xFF6B7396);
  static const textMuted = Color(0xFF9099B8);
  static const statusSuccess = Color(0xFF1A7A4C);
  static const statusWarning = Color(0xFF9A6612);
  static const statusDanger = Color(0xFFC0432A);
  static const statusInfo = Color(0xFF2563EB);
  static const statusPurple = Color(0xFF7C3AED);
  static const statusMuted = Color(0xFF6B7280);
  static const chatBackground = Color(0xFFFFFFFF);
  static const chatBubbleReceived = Color(0xFFF0F2F7);
  static const badgeUnread = Color(0xFFF59E0B);
}

class FieldSpacing {
  FieldSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class FieldRadius {
  FieldRadius._();

  static const double card = 16;
  static const double button = 12;
  static const double chip = 20;
  static const double input = 12;
}

class FieldTypography {
  FieldTypography._();

  static TextStyle get displayLarge => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: FieldColors.textPrimary,
        height: 1.2,
      );

  static TextStyle get headlineMedium => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: FieldColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get titleMedium => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: FieldColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get bodyLarge => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: FieldColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: FieldColors.textSecondary,
      );

  static TextStyle get labelSmall => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: FieldColors.textMuted,
      );
}

/// ThemeData + decoration helpers for the Field User Panel.
class FieldTheme {
  FieldTheme._();

  /// Single subtle shadow — reserved for floating action buttons only.
  static List<BoxShadow> get fabShadow => [
        BoxShadow(
          color: FieldColors.primaryNavy.withValues(alpha: 0.12),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static BoxDecoration cardDecoration({Color? borderColor}) => BoxDecoration(
        color: FieldColors.surfaceWhite,
        borderRadius: BorderRadius.circular(FieldRadius.card),
        border: Border.all(
          color: borderColor ?? FieldColors.borderSubtle,
          width: 1,
        ),
      );

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
        scaffoldBackgroundColor: FieldColors.screenBackground,
        splashColor: Colors.transparent,
        highlightColor: FieldColors.primaryNavy.withValues(alpha: 0.04),
        colorScheme: const ColorScheme.light(
          primary: FieldColors.primaryNavy,
          onPrimary: FieldColors.surfaceWhite,
          secondary: FieldColors.accentAmber,
          onSecondary: FieldColors.textPrimary,
          surface: FieldColors.surfaceWhite,
          onSurface: FieldColors.textPrimary,
          error: FieldColors.statusDanger,
          outline: FieldColors.borderSubtle,
        ),
        textTheme: TextTheme(
          displayLarge: FieldTypography.displayLarge,
          headlineMedium: FieldTypography.headlineMedium,
          titleMedium: FieldTypography.titleMedium,
          titleSmall: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: FieldColors.textPrimary,
            height: 1.4,
          ),
          bodyLarge: FieldTypography.bodyLarge,
          bodyMedium: FieldTypography.bodyMedium,
          labelMedium: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: FieldColors.textSecondary,
            height: 1.4,
          ),
          labelSmall: FieldTypography.labelSmall,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: FieldColors.primaryNavy,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: FieldColors.surfaceWhite,
            letterSpacing: -0.3,
          ),
          iconTheme: const IconThemeData(color: FieldColors.accentAmber),
          actionsIconTheme: const IconThemeData(color: FieldColors.accentAmber),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        cardTheme: CardThemeData(
          color: FieldColors.surfaceWhite,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FieldRadius.card),
            side: const BorderSide(color: FieldColors.borderSubtle, width: 1),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: FieldColors.borderSubtle,
          thickness: 1,
          space: 1,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: FieldColors.accentAmber,
            foregroundColor: FieldColors.primaryNavy,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FieldRadius.button),
            ),
            textStyle: FieldTypography.titleMedium,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: FieldColors.accentAmber,
            foregroundColor: FieldColors.primaryNavy,
            elevation: 0,
            shadowColor: Colors.transparent,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FieldRadius.button),
            ),
            textStyle: FieldTypography.titleMedium,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: FieldColors.primaryNavy,
            elevation: 0,
            side: const BorderSide(color: FieldColors.primaryNavy, width: 1),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FieldRadius.button),
            ),
            textStyle: FieldTypography.titleMedium,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: FieldColors.primaryNavy,
            textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: FieldColors.screenBackground,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: FieldSpacing.md,
            vertical: FieldSpacing.sm + 6,
          ),
          labelStyle: FieldTypography.bodyMedium.copyWith(
            color: FieldColors.textSecondary,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(FieldRadius.input),
            borderSide: const BorderSide(color: FieldColors.borderSubtle, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(FieldRadius.input),
            borderSide: const BorderSide(color: FieldColors.borderSubtle, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(FieldRadius.input),
            borderSide: const BorderSide(color: FieldColors.primaryNavy, width: 1.5),
          ),
          hintStyle: FieldTypography.bodyMedium.copyWith(color: FieldColors.textMuted),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: FieldColors.accentAmber,
          foregroundColor: FieldColors.primaryNavy,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FieldRadius.button),
          ),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: FieldColors.accentAmber,
          unselectedLabelColor: FieldColors.textMuted,
          indicatorColor: FieldColors.accentAmber,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  /// Wraps a field user screen with the panel theme.
  static Widget wrap(Widget child) => Theme(data: theme, child: child);

  static InputDecoration fieldDecoration({
    String? labelText,
    String? hintText,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      filled: true,
      fillColor: FieldColors.screenBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FieldRadius.input),
        borderSide: const BorderSide(color: FieldColors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FieldRadius.input),
        borderSide: const BorderSide(color: FieldColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FieldRadius.input),
        borderSide: const BorderSide(color: FieldColors.primaryNavy, width: 1.5),
      ),
      labelStyle: FieldTypography.bodyMedium.copyWith(color: FieldColors.textSecondary),
      hintStyle: FieldTypography.bodyMedium.copyWith(color: FieldColors.textMuted),
      helperStyle: FieldTypography.labelSmall,
    );
  }
}

/// Navy AppBar with amber icons — matches the supplier panel.
class FieldAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;
  final Widget? leading;

  const FieldAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.bottom,
    this.automaticallyImplyLeading = true,
    this.leading,
  }) : assert(title != null || titleWidget != null);

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: 52,
      titleSpacing: 4,
      leading: leading ??
          (automaticallyImplyLeading
              ? AppNavigation.leading(context)
              : null),
      title: titleWidget ?? Text(title!),
      actions: actions,
      bottom: bottom,
    );
  }
}

/// Status pill colors aligned with the supplier panel.
class FieldStatusColors {
  FieldStatusColors._();

  static ({Color bg, Color fg}) forStatus(String status) {
    final s = status.toLowerCase().replaceAll('_', '');
    if (s == 'pending' || s == 'pendingapproval') {
      return (
        bg: FieldColors.statusWarning.withValues(alpha: 0.15),
        fg: FieldColors.statusWarning,
      );
    }
    if (s == 'accepted' || s == 'inprogress') {
      return (bg: FieldColors.primaryNavy, fg: FieldColors.surfaceWhite);
    }
    if (s == 'delivered') {
      return (
        bg: FieldColors.statusPurple.withValues(alpha: 0.15),
        fg: FieldColors.statusPurple,
      );
    }
    if (s == 'confirmed') {
      return (
        bg: FieldColors.statusSuccess.withValues(alpha: 0.15),
        fg: FieldColors.statusSuccess,
      );
    }
    if (s == 'rejected') {
      return (
        bg: FieldColors.statusDanger.withValues(alpha: 0.15),
        fg: FieldColors.statusDanger,
      );
    }
    if (s == 'cancelled') {
      return (
        bg: FieldColors.statusMuted.withValues(alpha: 0.15),
        fg: FieldColors.statusMuted,
      );
    }
    return (bg: FieldColors.borderSubtle, fg: FieldColors.textSecondary);
  }
}
