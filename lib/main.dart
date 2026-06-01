import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/app_theme.dart';
import 'core/utils/injection_container.dart';
import 'core/providers/theme_provider.dart';
import 'features/voice/presentation/controllers/voice_controller.dart';
import 'features/trip/presentation/controllers/trip_controller.dart';
import 'features/trip/data/datasources/trip_service.dart';
import 'features/map/presentation/controllers/navigation_controller.dart';
import 'features/map/data/datasources/goong_directions_data_source.dart';
import 'features/map/data/repositories/navigation_repository_impl.dart';
import 'core/pages/splash_screen.dart';
import 'core/pages/onboarding_screen.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Future.wait([
    dotenv.load(fileName: ".env"),
    Hive.initFlutter(),
  ]);
  await init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await GoogleSignIn.instance.initialize();


  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<bool> _onboardingFuture;

  @override
  void initState() {
    super.initState();
    _onboardingFuture = OnboardingScreen.hasCompletedOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => VoiceController()),
        ChangeNotifierProvider(create: (_) => TripController()),
        ChangeNotifierProvider(
          create: (_) => NavigationController(
            NavigationRepositoryImpl(
              GoongDirectionsDataSourceImpl(),
            ),
          ),
        ),
        // Thêm AuthBloc vào MultiProvider bằng BlocProvider
        BlocProvider(
          create: (_) => sl<AuthBloc>()..add(const AuthEvent.authCheckRequested()),
        ),
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
