# Project: GNSS Vision Navigation App

## Commands

### Build & Run
```bash
flutter pub get          # Install dependencies
flutter run              # Run the app
flutter build apk        # Build Android APK
flutter build ios        # Build iOS
```

### Analysis
```bash
flutter analyze --no-pub  # Run static analysis
dart format .             # Format code
```

### Testing
```bash
flutter test              # Run all tests
flutter test --coverage   # Run tests with coverage
```

## Architecture

This project follows **Clean Architecture** with feature-based folder organization:

```
lib/
├── core/                    # Shared infrastructure
│   ├── errors/             # Failures and exceptions
│   ├── constants/          # App constants
│   ├── providers/          # App-level providers (ThemeProvider)
│   ├── widgets/            # Shared widgets (ModernUI)
│   ├── utils/              # Injection container, helpers
│   ├── app_theme.dart      # Theme configuration
│   └── page_transitions.dart
│
├── features/               # Feature modules (NEW Clean Architecture)
│   ├── vision/             # Vision/CV feature
│   │   ├── domain/         # Entities, repositories, use cases
│   │   ├── data/           # Data sources, models, repository impl
│   │   └── presentation/   # BLoC, pages, widgets
│   │
│   ├── trip/               # Trip management feature
│   │   ├── domain/         # Entities, repositories
│   │   ├── data/           # Data sources, models
│   │   └── presentation/   # BLoC, pages
│   │
│   ├── map/                # Map/navigation feature
│   │   └── domain/         # Entities, repositories
│   │
│   └── voice/              # Voice commands feature
│       └── domain/         # Entities, repositories
│
├── shared/                  # Shared services
│   ├── data/services/      # Location, Sensor, TTS, Media services
│   └── widgets/            # Shared UI widgets
│
├── controllers/             # Legacy controllers (to be migrated)
├── screens/                 # Legacy screens (to be migrated)
├── services/                # Legacy services (to be migrated)
├── widgets/                 # Legacy widgets (to be migrated)
├── models/                  # Legacy models (to be migrated)
├── vision/                  # Legacy vision utils (migrated to features/vision)
├── fusion/                  # Legacy sensor fusion (migrated to features/vision)
└── main.dart               # Entry point
```

## State Management
- **Current**: Uses Provider with ChangeNotifier (legacy)
- **Target**: flutter_bloc with GetIt dependency injection
- Migration is gradual - both patterns coexist during transition

## Key Dependencies
- flutter_bloc: State management
- equatable: Value equality
- dartz: Functional programming (Either)
- get_it: Dependency injection
- hive_flutter: Local storage
- opencv_dart: Computer vision
- provider: Legacy state management (being migrated)

## Migration Strategy

### Completed
1. ✅ Clean Architecture folder structure created
2. ✅ Vision feature: domain, data, presentation layers
3. ✅ Trip feature: domain, data layers
4. ✅ Map feature: domain layer
5. ✅ Voice feature: domain layer
6. ✅ Shared services: interfaces + implementations
7. ✅ Core layer: errors, constants, utils

### Pending (Gradual Migration)
1. 🔄 Migrate FlowController → VisionBloc
2. 🔄 Migrate TripController → TripBloc
3. 🔄 Migrate screens → feature/presentation/pages
4. 🔄 Migrate widgets → shared/widgets
5. 🔄 Remove legacy folders after migration

### Migration Guidelines
- Keep legacy files working during transition
- New code uses Clean Architecture
- Gradually refactor one feature at a time
- Use dependency injection (GetIt) for new services