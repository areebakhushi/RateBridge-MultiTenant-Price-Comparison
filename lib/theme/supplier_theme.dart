import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_navigation.dart';
import 'field_theme.dart';

export 'field_theme.dart' show FieldColors, FieldRadius, FieldSpacing, FieldTypography;

/// Design system for the Supplier Panel — aligned with the Field User panel.
class SupplierTheme {
  SupplierTheme._();

  static BoxDecoration cardDecoration({Color? borderColor}) =>
      FieldTheme.cardDecoration(borderColor: borderColor);

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
        textTheme: FieldTheme.theme.textTheme,
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
            textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: FieldColors.accentAmber,
            foregroundColor: FieldColors.primaryNavy,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FieldRadius.button),
            ),
            textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
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
            textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
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

  /// Wraps a supplier screen with the panel theme.
  static Widget wrap(Widget child) => Theme(data: theme, child: child);

  static InputDecoration fieldDecoration({String? labelText, String? hintText, String? helperText}) {
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

/// Navy AppBar with amber icons — standard across supplier screens.
class SupplierAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;
  final Widget? leading;

  const SupplierAppBar({
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

/// Status pill colors for supplier order badges.
class SupplierStatusColors {
  SupplierStatusColors._();

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
