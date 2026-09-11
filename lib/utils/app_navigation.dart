import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Central back-navigation for the whole app.
///
/// In-app movement must [push] so the previous screen stays on the stack.
/// [go] is only for genuine resets (login, logout, registration complete,
/// approval). Never send the user to a hardcoded panel home from Back.
class AppNavigation {
  AppNavigation._();

  static bool canPop(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) return true;
    return Navigator.maybeOf(context)?.canPop() ?? false;
  }

  /// Pops the immediately previous route. Returns `false` if nothing to pop.
  static bool pop(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
      return true;
    }
    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return true;
    }
    return false;
  }

  /// AppBar leading: a back button only when there is a previous route.
  static Widget? leading(BuildContext context, {Color? color}) {
    if (!canPop(context)) return null;
    return AppBackButton(color: color);
  }
}

/// Back control used by every panel AppBar and custom header.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.color, this.onPressed});

  final Color? color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      color: color,
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed ?? () => AppNavigation.pop(context),
    );
  }
}

/// Simple tab index management for IndexedStack shells.
/// Modified to support "Any non-home tab -> Back -> Home" flow.
class TabHistory {
  TabHistory({int initial = 0}) : _index = initial;

  int _index;

  int get index => _index;

  /// Can pop if not on the Home tab (index 0).
  bool get canPop => _index != 0;

  /// Records a tab change. Returns `false` if [index] is already selected.
  bool select(int index) {
    if (_index == index) return false;
    _index = index;
    return true;
  }

  /// Returns to Home tab (index 0).
  bool pop() {
    if (!canPop) return false;
    _index = 0;
    return true;
  }
}

/// Intercepts Android / browser back for IndexedStack shells.
class TabHistoryPopScope extends StatelessWidget {
  const TabHistoryPopScope({
    super.key,
    required this.history,
    required this.onChanged,
    required this.child,
  });

  final TabHistory history;
  final VoidCallback onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !history.canPop || AppNavigation.canPop(context),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (history.pop()) onChanged();
      },
      child: child,
    );
  }
}

/// Intercepts Android back button for top-level routes that act as tabs.
class RootTabPopScope extends StatelessWidget {
  const RootTabPopScope({
    super.key,
    required this.isHome,
    required this.homeRoute,
    required this.child,
  });

  final bool isHome;
  final String homeRoute;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: isHome || AppNavigation.canPop(context),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Use go() to switch back to home without adding to stack
        context.go(homeRoute);
      },
      child: child,
    );
  }
}
