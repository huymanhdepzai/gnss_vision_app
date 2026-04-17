import 'package:flutter/material.dart';
import '../../domain/entities/navigation_route.dart';
import '../../domain/entities/navigation_step.dart';
import '../../domain/entities/navigation_state.dart';
import '../../domain/repositories/navigation_repository.dart';

class NavigationController extends ChangeNotifier {
  final NavigationRepository _repository;

  NavigationState _state = const NavigationState();
  NavigationState get state => _state;

  bool get isNavigating => _state.isNavigating;
  NavigationRoute? get currentRoute => _state.route;

  int get currentStepIndex => _state.currentStepIndex;
  NavigationStep? get currentStep {
    if (_state.route == null) return null;
    final steps = _state.route!.steps;
    if (_state.currentStepIndex >= steps.length) return null;
    return steps[_state.currentStepIndex];
  }

  NavigationStep? get nextStep {
    if (_state.route == null) return null;
    final steps = _state.route!.steps;
    final nextIndex = _state.currentStepIndex + 1;
    if (nextIndex >= steps.length) return null;
    return steps[nextIndex];
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  NavigationController(this._repository);

  Future<void> startNavigation(NavigationRoute route) async {
    _state = _state.copyWith(
      status: NavigationStatus.navigating,
      route: route,
      currentStepIndex: 0,
    );
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchRouteAndStart({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    String destinationName = '',
    String vehicle = 'car',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.getRoute(
      originLat: originLat,
      originLng: originLng,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      vehicle: vehicle,
    );

    result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        notifyListeners();
      },
      (route) {
        final enrichedRoute = route.copyWith(
          destinationName: destinationName.isNotEmpty
              ? destinationName
              : route.destinationName,
        );
        _isLoading = false;
        _state = _state.copyWith(
          status: NavigationStatus.navigating,
          route: enrichedRoute,
          currentStepIndex: 0,
        );
        notifyListeners();
      },
    );
  }

  void advanceToNextStep() {
    if (_state.route == null) return;
    final steps = _state.route!.steps;
    if (_state.currentStepIndex < steps.length - 1) {
      _state = _state.copyWith(currentStepIndex: _state.currentStepIndex + 1);
      notifyListeners();
    }
  }

  void advanceToStep(int index) {
    if (_state.route == null) return;
    if (index >= 0 && index < _state.route!.steps.length) {
      _state = _state.copyWith(currentStepIndex: index);
      notifyListeners();
    }
  }

  void stopNavigation() {
    _state = const NavigationState();
    _errorMessage = null;
    notifyListeners();
  }

  void pauseNavigation() {
    _state = _state.copyWith(status: NavigationStatus.paused);
    notifyListeners();
  }

  void resumeNavigation() {
    _state = _state.copyWith(status: NavigationStatus.navigating);
    notifyListeners();
  }

  void toggleHeadingRotation() {
    _state = _state.copyWith(isHeadingRotated: !_state.isHeadingRotated);
    notifyListeners();
  }

  bool get isLastStep {
    if (_state.route == null) return true;
    return _state.currentStepIndex >= _state.route!.steps.length - 1;
  }

  double get progressPercentage {
    if (_state.route == null || _state.route!.steps.isEmpty) return 0.0;
    return (_state.currentStepIndex + 1) / _state.route!.steps.length;
  }
}
