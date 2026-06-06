---
description: Repository Information Overview
alwaysApply: true
---

# Active Class - Flutter Classroom Management Application

## Summary
Active Class is a comprehensive Flutter classroom management application providing complete CRUD operations for student groups, attendance tracking, payment management, and QR code integration. Built with GetX state management, SQLite database, and Material Design 3 UI. All 10 pages and 7 controllers fully implemented and operational.

## Repository Structure
- **lib/**: Main Flutter application source code
  - **config/**: Constants, routes, and theme configuration
  - **controllers/**: 7 GetX controllers for state management
  - **models/**: Data models (Groups, Students, Attendance, Payments)
  - **services/**: DatabaseService with SQLite integration
  - **views/**: 10 pages implementing user interface
  - **widgets/**: Custom reusable components and dialogs
  - **utils/**: Helper utilities and formatters
- **assets/**: Cairo Arabic font files
- **android/**, **ios/**, **web/**, **linux/**, **macos/**, **windows/**: Platform-specific builds
- **test/**: Unit and widget tests

## Language & Runtime
**Language**: Dart 3.5.4
**Framework**: Flutter (Latest Stable)
**Build System**: Flutter CLI
**Package Manager**: Pub

## Key Dependencies
- **get** (4.6.0): State management and routing
- **sqflite** (2.3.0): SQLite database
- **qr_flutter** (4.1.0): QR code generation
- **mobile_scanner** (4.0.0): QR code scanning
- **pdf** (3.10.0): PDF export
- **printing** (5.11.0): Print support
- **intl** (0.19.0): Localization (Arabic/RTL)
- **dio** (5.3.0): HTTP client
- **flutter_spinkit** (5.2.0): Loading animations

## Build & Installation
\\\ash
flutter clean
flutter pub get
flutter run
flutter build apk --target-platform android-arm64
flutter build appbundle
flutter analyze
flutter test
\\\

## Architecture
**Pattern**: MVCS (Model-View-Controller-Service)
**State Management**: GetX for reactive state
**Database**: SQLite with sqflite
**Routing**: Named routes via GetX
**Localization**: Full Arabic (RTL) support

## Controllers (7/7)
1. **ThemeController**: Theme management
2. **GroupController**: Group CRUD operations
3. **StudentController**: Student management
4. **AttendanceController**: Attendance tracking
5. **PaymentController**: Payment processing
6. **ReportController**: Report generation
7. **QRController**: QR code scanning

## Database Schema
- **groups**: Student group management
- **students**: Student records with QR codes
- **attendance**: Daily attendance tracking
- **payments**: Payment records and history

## Main Features
✓ Complete CRUD operations for groups, students, attendance, payments
✓ Offline-first SQLite storage with transactions
✓ QR code generation and scanning
✓ PDF export functionality
✓ Dark/Light theme switching
✓ Responsive Material Design 3 UI
✓ Custom dialogs and reusable widgets
✓ Input validation and error handling
✓ Search and filtering capabilities
✓ Statistics dashboard and reporting
✓ Full Arabic language support with RTL layout

## Testing
**Framework**: Flutter Test framework
**Location**: /test/ directory
**Run Command**: \lutter test\

## Production Status
🟢 **STATUS: PRODUCTION READY v1.0.0**
- All 10 pages fully implemented
- 7 controllers with complete business logic
- Database schema with constraints
- Routing system operational
- String interpolation errors fixed
- Ready for APK/AppBundle builds