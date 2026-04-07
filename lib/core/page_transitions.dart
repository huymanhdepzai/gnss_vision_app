import 'dart:math';
import 'package:flutter/material.dart';

enum PageTransitionType {
  fade,
  slideRight,
  slideLeft,
  slideUp,
  slideDown,
  scale,
  rotate,
  fadeSlide,
  flip,
  sharedAxis,
}

class PageTransition<T> extends PageRouteBuilder<T> {
  final Widget child;
  final PageTransitionType type;
  final Duration duration;
  final Alignment alignment;
  final Curve curve;

  PageTransition({
    required this.child,
    this.type = PageTransitionType.fadeSlide,
    this.duration = const Duration(milliseconds: 500),
    this.alignment = Alignment.center,
    this.curve = Curves.easeOutCubic,
    RouteSettings? settings,
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) => child,
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         settings: settings,
       );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);
    final curvedSecondaryAnimation = CurvedAnimation(
      parent: secondaryAnimation,
      curve: curve,
    );

    switch (type) {
      case PageTransitionType.fade:
        return FadeTransition(opacity: curvedAnimation, child: child);

      case PageTransitionType.slideRight:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );

      case PageTransitionType.slideLeft:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );

      case PageTransitionType.slideUp:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );

      case PageTransitionType.slideDown:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, -1.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );

      case PageTransitionType.scale:
        return ScaleTransition(
          scale: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
          alignment: alignment,
          child: child,
        );

      case PageTransitionType.rotate:
        return RotationTransition(
          turns: Tween<double>(begin: 0.5, end: 1.0).animate(curvedAnimation),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );

      case PageTransitionType.fadeSlide:
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.1),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );

      case PageTransitionType.flip:
        return AnimatedBuilder(
          animation: curvedAnimation,
          builder: (context, child) {
            final value = curvedAnimation.value;
            final matrix = Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(pi * (1 - value));

            return Transform(
              transform: matrix,
              alignment: Alignment.center,
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.5, 1.0),
                  ),
                ),
                child: child,
              ),
            );
          },
          child: child,
        );

      case PageTransitionType.sharedAxis:
        return SharedAxisTransition(
          animation: curvedAnimation,
          secondaryAnimation: curvedSecondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          child: child,
        );
    }
  }
}

class SharedAxisTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final SharedAxisTransitionType transitionType;
  final Widget child;

  const SharedAxisTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.transitionType,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    Offset beginOffset;
    Offset endOffset;

    switch (transitionType) {
      case SharedAxisTransitionType.horizontal:
        beginOffset = const Offset(1.0, 0.0);
        endOffset = const Offset(-1.0, 0.0);
        break;
      case SharedAxisTransitionType.vertical:
        beginOffset = const Offset(0.0, 1.0);
        endOffset = const Offset(0.0, -1.0);
        break;
      case SharedAxisTransitionType.scaled:
        beginOffset = Offset.zero;
        endOffset = Offset.zero;
        break;
    }

    return Stack(
      children: [
        SlideTransition(
          position: Tween<Offset>(begin: endOffset, end: Offset.zero).animate(
            CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: FadeTransition(
            opacity: Tween<double>(
              begin: 1.0,
              end: 0.0,
            ).animate(secondaryAnimation),
            child: child,
          ),
        ),
        SlideTransition(
          position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(animation),
            child: child,
          ),
        ),
      ],
    );
  }
}

enum SharedAxisTransitionType { horizontal, vertical, scaled }

class FadeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      );
}

class SlideUpRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideUpRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.0, 1.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      );
}

class ScaleRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  ScaleRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      );
}

extension NavigatorExtension on Navigator {
  static Future<T?> pushWithTransition<T>(
    BuildContext context,
    Widget page, {
    PageTransitionType type = PageTransitionType.fadeSlide,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    return Navigator.push<T>(
      context,
      PageTransition<T>(child: page, type: type, duration: duration),
    );
  }

  static Future<T?> pushReplacementWithTransition<T, TO>(
    BuildContext context,
    Widget page, {
    PageTransitionType type = PageTransitionType.fadeSlide,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    return Navigator.pushReplacement<T, TO>(
      context,
      PageTransition<T>(child: page, type: type, duration: duration),
    );
  }
}
