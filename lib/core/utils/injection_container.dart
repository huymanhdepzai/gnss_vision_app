import 'package:hive_flutter/hive_flutter.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> init() async {
  await _initExternalDependencies();
  initVisionFeature();
  initTripFeature();
  initSharedServices();
}

Future<void> _initExternalDependencies() async {
  final tripsBox = await Hive.openBox<Map>('trips');
  final mediaBox = await Hive.openBox<Map>('media_files');

  sl.registerLazySingleton<Box<Map>>(instanceName: 'tripsBox', () => tripsBox);
  sl.registerLazySingleton<Box<Map>>(instanceName: 'mediaBox', () => mediaBox);
}

void initVisionFeature() {
  // Vision feature will be initialized here when migrated from FlowController
  // For now, legacy FlowController is used via Provider in main.dart
}

void initTripFeature() {
  // Trip feature will be initialized here when fully migrated to BLoC
  // For now, legacy TripController is used via Provider in main.dart
}

void initSharedServices() {
  // Shared services registered here when migrated
}
