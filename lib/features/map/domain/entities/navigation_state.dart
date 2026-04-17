import 'navigation_route.dart';

enum NavigationStatus { idle, navigating, paused }

class NavigationState {
  final NavigationStatus status;
  final NavigationRoute? route;
  final int currentStepIndex;
  final bool isHeadingRotated;

  const NavigationState({
    this.status = NavigationStatus.idle,
    this.route,
    this.currentStepIndex = 0,
    this.isHeadingRotated = false,
  });

  NavigationState copyWith({
    NavigationStatus? status,
    NavigationRoute? route,
    int? currentStepIndex,
    bool? isHeadingRotated,
  }) {
    return NavigationState(
      status: status ?? this.status,
      route: route ?? this.route,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      isHeadingRotated: isHeadingRotated ?? this.isHeadingRotated,
    );
  }

  bool get isNavigating => status == NavigationStatus.navigating;
  bool get isIdle => status == NavigationStatus.idle;
}
