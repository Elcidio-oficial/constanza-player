import 'package:flutter/material.dart';

/// Professional page transition: subtle slide-up + fade.
/// Replaces MaterialPageRoute across the app for consistent motion.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({required this.page})
    : super(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );

  final Widget page;
}
