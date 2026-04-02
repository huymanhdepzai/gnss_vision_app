import 'package:demo_app/screens/map_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/flow_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  // Xin quyền truy cập Camera trước khi chạy App
  await Permission.camera.request();

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MapHomeScreen(),
  ));
}