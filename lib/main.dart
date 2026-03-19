import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/flow_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Xin quyền truy cập Camera trước khi chạy App
  await Permission.camera.request();

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: FlowScreen(),
  ));
}