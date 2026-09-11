import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../viewmodels/notification_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/notification_badge_icon.dart';
import '../constants/route_names.dart';
import '../utils/app_navigation.dart';

/// RateBridge design system for the Admin panel.
class AdminColors {
  AdminColors._();

  static const navy = Color(0xFF1E326E);
  static const amber = Color(0xFFFBB03C);
  static const darkAmber = Color(0xFFB7791F);
  static const screenBg = Color(0xFFF5F6FA);
  static const border = Color(0xFFE2E5F0);
  static const textGrey = Color(0xFF888888);
  static const green = Color(0xFF1D9E75);
  static const red = Color(0xFFE25730);
  static const purple = Color(0xFF6B46C1);
}

class AdminTheme {
  AdminTheme._();

  static TextStyle get _base => GoogleFonts.plusJakartaSans();

  static BoxDecoration cardDecoration({Color? borderColor}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: borderColor != null ? Border.all(color: borderColor) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  static TextStyle sectionHeaderStyle() => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: AdminColors.textGrey,
      );

  static TextStyle titleStyle({double size = 18}) => _base.copyWith(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: AdminColors.navy,
      );

  static TextStyle bodyStyle({Color? color}) => _base.copyWith(
        fontSize: 14,
        color: color ?? AdminColors.navy,
      );

  static TextStyle mutedStyle({double size = 13}) => _base.copyWith(
        fontSize: size,
        color: AdminColors.textGrey,
      );

  static ({Color bg, Color fg}) statusColors(String status) {
    final s = status.toLowerCase().replaceAll('_', '');
    switch (s) {
      case 'pending':
        return (
          bg: AdminColors.amber.withValues(alpha: 0.15),
          fg: AdminColors.darkAmber,
        );
      case 'active':
      case 'confirmed':
        return (
          bg: AdminColors.green.withValues(alpha: 0.15),
          fg: AdminColors.green,
        );
      case 'settled':
        return (
          bg: AdminColors.purple.withValues(alpha: 0.15),
          fg: AdminColors.purple,
        );
      case 'rejected':
      case 'failed':
        return (
          bg: AdminColors.red.withValues(alpha: 0.15),
          fg: AdminColors.red,
        );
      case 'suspended':
        return (
          bg: AdminColors.textGrey.withValues(alpha: 0.15),
          fg: AdminColors.textGrey,
        );
      case 'approved':
        return (
          bg: AdminColors.navy.withValues(alpha: 0.15),
          fg: AdminColors.navy,
        );
      default:
        return (
          bg: AdminColors.textGrey.withValues(alpha: 0.15),
          fg: AdminColors.textGrey,
        );
    }
  }

  static InputDecorationThemeData get inputDecorationThemeData {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AdminColors.border, width: 1),
    );
    return InputDecorationThemeData(
      filled: true,
      fillColor: AdminColors.screenBg,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: _base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AdminColors.navy,
      ),
      hintStyle: _base.copyWith(fontSize: 14, color: AdminColors.textGrey),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminColors.amber, width: 2),
      ),
    );
  }

  static InputDecoration inputDecoration({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool isDense = false,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AdminColors.border, width: 1),
    );
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      isDense: isDense,
      filled: true,
      fillColor: AdminColors.screenBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: _base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AdminColors.navy,
      ),
      hintStyle: _base.copyWith(fontSize: 14, color: AdminColors.textGrey),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminColors.amber, width: 2),
      ),
    );
  }

  static ButtonStyle primaryButtonStyle({double height = 48}) =>
      ElevatedButton.styleFrom(
        backgroundColor: AdminColors.amber,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: Size(double.infinity, height),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: _base.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
      );

  static ButtonStyle secondaryButtonStyle({double height = 48}) =>
      OutlinedButton.styleFrom(
        foregroundColor: AdminColors.navy,
        side: const BorderSide(color: AdminColors.navy, width: 1.5),
        minimumSize: Size(double.infinity, height),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: _base.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      );

  static ButtonStyle destructiveButtonStyle({double height = 46}) =>
      OutlinedButton.styleFrom(
        foregroundColor: AdminColors.red,
        side: const BorderSide(color: AdminColors.red, width: 1.5),
        minimumSize: Size(double.infinity, height),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: _base.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      );

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
        scaffoldBackgroundColor: AdminColors.screenBg,
        splashColor: Colors.transparent,
        highlightColor: AdminColors.amber.withValues(alpha: 0.08),
        colorScheme: const ColorScheme.light(
          primary: AdminColors.navy,
          onPrimary: Colors.white,
          secondary: AdminColors.amber,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: AdminColors.navy,
          error: AdminColors.red,
          outline: AdminColors.border,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AdminColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AdminColors.border,
          thickness: 1,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: primaryButtonStyle(),
        ),
        filledButtonTheme: FilledButtonThemeData(style: primaryButtonStyle()),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: secondaryButtonStyle(),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AdminColors.amber,
            textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: inputDecorationThemeData,
        tabBarTheme: TabBarThemeData(
          labelColor: AdminColors.amber,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AdminColors.amber,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AdminColors.amber,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titleTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AdminColors.navy,
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: AdminColors.navy,
          unselectedItemColor: AdminColors.textGrey,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          selectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 11),
        ),
        textTheme: TextTheme(
          headlineMedium: titleStyle(size: 26),
          titleLarge: titleStyle(size: 18),
          titleMedium: titleStyle(size: 16),
          bodyLarge: bodyStyle(),
          bodyMedium: bodyStyle(color: AdminColors.textGrey),
          labelLarge: _base.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AdminColors.navy,
          ),
        ),
      );

  static Widget wrap(Widget child) => Theme(data: theme, child: child);
}

/// Navy AppBar — standard across admin screens. Includes notification icon by default.
class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;
  final bool showNotificationIcon;
  final Widget? leading;

  const AdminAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.bottom,
    this.automaticallyImplyLeading = true,
    this.showNotificationIcon = true,
    this.leading,
  }) : assert(title != null || titleWidget != null);

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final allActions = [...?actions];

    if (showNotificationIcon) {
      final notifVm = context.watch<NotificationViewModel>();
      final authVm = context.read<AuthViewModel>();
      final isAdmin = authVm.user?.role.toLowerCase().contains('admin') ?? false;

      allActions.add(
        NotificationBadgeIcon(
          unreadCount: notifVm.unreadCount,
          iconColor: Colors.white,
          onPressed: () => context.push(
            isAdmin ? RouteNames.adminNotifications : RouteNames.ceoNotifications,
          ),
        ),
      );
      allActions.add(const SizedBox(width: 8));
    }

    return AppBar(
      automaticallyImplyLeading: false,
      leading: leading ??
          (automaticallyImplyLeading
              ? AppNavigation.leading(context)
              : null),
      title: titleWidget ?? (title != null ? Text(title!) : null),
      actions: allActions,
      bottom: bottom,
    );
  }
}

class AdminSectionLabel extends StatelessWidget {
  final String text;

  const AdminSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: AdminTheme.sectionHeaderStyle());
  }
}
