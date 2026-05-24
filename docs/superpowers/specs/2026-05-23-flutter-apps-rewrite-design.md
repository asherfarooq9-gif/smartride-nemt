# Flutter Apps Production Rewrite — Design Spec
Date: 2026-05-23

## Overview
Full rewrite of `apps/patient_app` and `apps/driver_app` to production-grade Flutter apps with Dart null safety, Riverpod, Dio, flutter_secure_storage, Material3 UI, and zero runtime errors.

## Architecture

### Folder Structure (both apps)
```
lib/
  core/
    api_client.dart       # Dio singleton + auth interceptor (HTTPS enforced)
    secure_storage.dart   # flutter_secure_storage wrapper (only JWT access point)
    router.dart           # go_router with auth redirect guard
    theme.dart            # Material3 ColorScheme + typography tokens
  features/
    auth/
      auth_notifier.dart
      login_screen.dart
    rides/
      rides_notifier.dart
      home_screen.dart
      ride_detail_screen.dart
    profile/
      profile_notifier.dart
      profile_screen.dart
    # driver_app only:
    tracking/
      tracking_notifier.dart
      tracking_screen.dart
  widgets/
    app_button.dart
    app_text_field.dart
    ride_card.dart
    loading_overlay.dart
  main.dart
```

### State Management
- Riverpod `StateNotifier<AsyncValue<T>>` per feature
- `AsyncValue` handles loading/error/data uniformly — no manual bool flags
- `ref.watch` in screens, `ref.read` in callbacks only

### Security
- JWT stored exclusively in `flutter_secure_storage` — never SharedPreferences
- Dio interceptor reads token from secure storage per-request
- All base URLs must be `https://` — enforced in `api_client.dart` with assertion
- Input validation via `FormField` validators before any network call
- Typed `ApiException` wraps all Dio errors — raw exceptions never surface to UI

### Dependencies (pinned, no ^)
```yaml
flutter_secure_storage: 9.2.2
dio: 5.7.0
flutter_riverpod: 2.6.1
go_router: 14.6.2
geolocator: 13.0.2  # patient app only
```

## Patient App Screens
1. Login — phone + password, validation, error feedback
2. Home — active ride banner, emergency button, GPS location
3. Ride Detail — status timeline, driver info, fare
4. Scheduled Rides — list with status chips
5. Profile — view/edit personal info
6. Settings — logout, app version

## Driver App Screens
1. Login — phone + password
2. Dashboard — availability toggle, pending ride requests
3. Active Ride — patient info, navigation CTA, status controls
4. Earnings — daily summary card
5. Profile — vehicle info, verification status

## UI Design
- Material3, seed color `Color(0xFF1565C0)` (healthcare blue)
- Custom AppTextField with border animation and error states
- Custom AppButton with loading spinner
- Skeleton loading on all list screens
- No emojis as icons — Lucide/Material icons only
