import 'package:hive_flutter/hive_flutter.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Tránh đăng ký lại nếu đã được khởi tạo (hữu ích khi Activity restart)
  if (sl.isRegistered<Box<Map>>(instanceName: 'tripsBox')) {
    return;
  }
  
  // Đăng ký các dịch vụ ngoại vi một cách lười biếng (Lazy)
  _initExternalDependencies();
  
  initVisionFeature();
  initTripFeature();
  initSharedServices();
}

void _initExternalDependencies() {
  // Sử dụng registerSingletonAsync nếu cần khởi tạo bất đồng bộ nhưng vẫn muốn đảm bảo duy nhất
  sl.registerSingletonAsync<Box<Map>>(
    () => Hive.openBox<Map>('trips'),
    instanceName: 'tripsBox',
  );
  sl.registerSingletonAsync<Box<Map>>(
    () => Hive.openBox<Map>('media_files'),
    instanceName: 'mediaBox',
  );
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
