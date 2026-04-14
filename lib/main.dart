import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/app_theme.dart';
import 'core/utils/injection_container.dart';
import 'core/providers/theme_provider.dart';
import 'features/voice/presentation/controllers/voice_controller.dart';
import 'features/trip/presentation/controllers/trip_controller.dart';
import 'features/trip/data/datasources/trip_service.dart';
import 'core/pages/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Hive.initFlutter();
  await TripService.initialize();

  await init();

  await [
    Permission.camera,
    Permission.locationWhenInUse,
    Permission.microphone,
    Permission.photos,
    Permission.videos,
  ].request();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => VoiceController()),
        ChangeNotifierProvider(create: (_) => TripController()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'GNSS Vision Navigation',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
