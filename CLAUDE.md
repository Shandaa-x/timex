# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Timex is a Flutter-based mobile application featuring time tracking, meal planning, and payment integration via QPay (Mongolian payment system). The app uses Firebase for authentication and data storage, with Google Sign-In for user authentication.

## Common Development Commands

### Flutter Commands
```bash
# Clean and get dependencies
flutter clean
flutter pub get

# Build and run
flutter run --debug           # Run debug build
flutter run --release         # Run release build
flutter build apk            # Build Android APK
flutter build ios            # Build iOS app

# Code analysis and testing
flutter analyze              # Static analysis
flutter test                # Run unit tests
flutter doctor              # Check Flutter setup
```

### Firebase SHA-1 Configuration
When Google Sign-In fails, get SHA-1 fingerprint:
```bash
# Using keytool (if Java is available)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Using Gradle in Android Studio
./gradlew signingReport     # Run in android/ directory
```
Add the SHA-1 fingerprint to Firebase Console → Project Settings → Your apps → Add fingerprint.

## Architecture Overview

### Core Structure
- **Authentication Flow**: `AuthWrapper` → Google Sign-In → `MainScreen`
- **Main Navigation**: Bottom tab navigation with 5 screens using `PageController`
- **State Management**: Traditional StatefulWidget approach with Firebase Auth streams
- **Routing**: Custom route management via `Routes` class with `RouteObserver`

### Key Components

#### Authentication (`lib/screens/auth/`)
- `AuthWrapper`: StreamBuilder listening to Firebase Auth state changes
- `GoogleLoginScreen`: Handles Google Sign-In with Firebase integration
- `LoginSelectionScreen`: Login method selection (if used)

#### Main Application (`lib/screens/main/`)
- `MainScreen`: TabBar container with PageView for 5 main sections:
  1. Time Tracking (`TimeTrackScreen`)
  2. Monthly Statistics (`MonthlyStatisticsScreen`)
  3. Meal Planning (`MealPlanCalendar`)
  4. Food Reports (`FoodReportScreen`)
  5. QPay QR Code (`QRCodeScreen`)

#### QPay Payment Integration (`lib/services/qpay_*`)
- **Complete payment solution** for Mongolian market
- `QPayHelper`: Core API interaction class with token management
- `QPayConfig`: Environment-based configuration management
- `QPayModels`: Data models for invoices, payments, and products
- Features: Invoice creation, QR generation, payment monitoring, status checking

### Firebase Integration
- **Authentication**: Google Sign-In with Firebase Auth
- **Firestore**: User profile storage with automatic document creation
- **Configuration**: Multi-platform setup (iOS, Android, Web, macOS, Windows)
- **Project**: `timex-9ce03` with proper platform configurations

### Environment Configuration
The app uses `.env` files for configuration:
- QPay credentials and API settings
- Firebase project configuration
- Server ports and callback URLs
- Feature flags (production/sandbox modes)

## Development Guidelines

### QPay Integration
- Always use `QPayHelper.ensureAuthenticated()` before API calls
- Environment variables are loaded in `main.dart` with proper error handling
- Test in sandbox mode before production deployment
- Monitor payment status using built-in checking mechanisms

### Firebase & Authentication
- `AuthWrapper` automatically handles login/logout navigation
- Google Sign-In requires proper SHA-1 configuration in Firebase Console
- User profiles are automatically created/updated in Firestore
- Sign-out process clears both Firebase and Google Sign-In sessions

### Code Patterns
- **Error Handling**: Comprehensive try-catch with user-friendly messages in Mongolian
- **Logging**: Centralized logging via `AppLogger` for different operation types
- **Navigation**: Uses GetX for routing with custom route observer
- **State Management**: StatefulWidget pattern with proper lifecycle management

### Common Issues & Solutions

#### Google Sign-In Failures
1. Verify SHA-1 fingerprint is added to Firebase Console
2. Check `google-services.json` is up-to-date
3. Ensure Firebase project ID matches across all configuration files
4. Test on different devices/emulators

#### QPay Integration Issues
1. Verify environment variables are loaded correctly
2. Check network connectivity for API calls
3. Validate product data before invoice creation
4. Monitor token expiration and refresh cycles

### File Organization
```
lib/
├── config/          # Configuration files (QPay, app settings)
├── models/          # Data models (QPay, app models)
├── screens/         # UI screens organized by feature
│   ├── auth/        # Authentication screens
│   ├── main/        # Main application container
│   ├── qpay/        # Payment-related screens
│   └── ...
├── services/        # Business logic and API services
├── utils/           # Utility functions and helpers
├── widgets/         # Reusable UI components
└── theme/           # App styling and assets
```

## Testing & Deployment

### Pre-deployment Checklist
1. Run `flutter analyze` to check for code issues
2. Test Google Sign-In with proper SHA-1 configuration
3. Verify QPay integration in sandbox mode
4. Test on both iOS and Android platforms
5. Check Firebase Console for proper app configuration

### Environment Setup
1. Copy `.env.example` to `.env` and configure QPay credentials
2. Ensure Firebase configuration files are present:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
3. Run `flutter pub get` after environment setup