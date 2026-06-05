# Flutter Apps Production Rewrite — Implementation Plan

> **ARCHIVED. Do not execute.** This plan is superseded by the shipped UI redesign
> (commit `49cfac5`) and the current `smartride_core` + unified `patient_app`
> architecture. It also targets `apps/driver_app`, which has since been retired and
> removed. Kept for historical reference only.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fully rewrite `apps/patient_app` and `apps/driver_app` to production-grade Flutter apps with Dart null safety, Riverpod, Dio, flutter_secure_storage, Material3 UI, and zero runtime errors.

**Architecture:** Layered feature-first structure — `core/` holds singleton infrastructure (Dio, secure storage, router, theme), `features/` holds one StateNotifier + screens per feature, `widgets/` holds shared UI. JWT is only ever touched by `secure_storage.dart`.

**Tech Stack:** Flutter 3.x, Dart null safety, flutter_riverpod 2.5.1, dio 5.6.0, flutter_secure_storage 9.2.2, go_router 14.2.7, geolocator 12.0.0 (patient only), Material3.

---

## File Map

### Patient App (`apps/patient_app/lib/`)
| File | Responsibility |
|---|---|
| `main.dart` | ProviderScope, MaterialApp.router |
| `core/secure_storage.dart` | Only file that reads/writes JWT |
| `core/api_client.dart` | Dio singleton, auth interceptor, typed errors |
| `core/router.dart` | go_router with auth redirect guard |
| `core/theme.dart` | Material3 ColorScheme, text styles |
| `features/auth/auth_notifier.dart` | Login/logout state |
| `features/auth/login_screen.dart` | Login UI |
| `features/rides/rides_notifier.dart` | Rides list + active ride state |
| `features/rides/home_screen.dart` | Dashboard with emergency button |
| `features/rides/ride_detail_screen.dart` | Single ride view |
| `features/rides/scheduled_rides_screen.dart` | Ride list |
| `features/profile/profile_notifier.dart` | Profile fetch/update |
| `features/profile/profile_screen.dart` | View/edit profile |
| `features/profile/settings_screen.dart` | Logout, app info |
| `widgets/app_button.dart` | Branded button with loading state |
| `widgets/app_text_field.dart` | Input with validation and error display |
| `widgets/ride_card.dart` | Ride list item |
| `widgets/loading_overlay.dart` | Full-screen loading with skeleton |

### Driver App (`apps/driver_app/lib/`)
| File | Responsibility |
|---|---|
| `main.dart` | ProviderScope, MaterialApp.router |
| `core/secure_storage.dart` | JWT only |
| `core/api_client.dart` | Dio + auth interceptor |
| `core/router.dart` | go_router with guard |
| `core/theme.dart` | Material3 theme |
| `features/auth/auth_notifier.dart` | Login/logout |
| `features/auth/login_screen.dart` | Login UI |
| `features/dashboard/dashboard_notifier.dart` | Availability toggle + ride requests |
| `features/dashboard/dashboard_screen.dart` | Main driver view |
| `features/ride/ride_notifier.dart` | Active ride state + status updates |
| `features/ride/active_ride_screen.dart` | Patient info, status controls |
| `features/profile/profile_notifier.dart` | Profile fetch |
| `features/profile/profile_screen.dart` | Vehicle info, verification status |
| `widgets/app_button.dart` | Shared button widget |
| `widgets/app_text_field.dart` | Shared input widget |

---

## PHASE 1: Patient App

### Task 1: pubspec.yaml — Pinned Dependencies

**Files:**
- Rewrite: `apps/patient_app/pubspec.yaml`

- [ ] **Step 1: Replace pubspec.yaml with pinned dependencies**

```yaml
name: patient_app
description: SmartRide patient mobile application
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: 9.2.2
  dio: 5.6.0
  flutter_secure_storage: 9.2.2
  go_router: 14.2.7
  geolocator: 12.0.0
  permission_handler: 11.3.1
  intl: 0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: 4.0.0
  mocktail: 1.0.4

flutter:
  uses-material-design: true
```

- [ ] **Step 2: Remove old lock file and fetch fresh**

```bash
cd apps/patient_app
rm pubspec.lock
flutter pub get
```

Expected: Resolves all packages with no version conflicts. `pubspec.lock` is regenerated.

- [ ] **Step 3: Commit**

```bash
git add apps/patient_app/pubspec.yaml apps/patient_app/pubspec.lock
git commit -m "feat(patient): pin all dependencies to exact stable versions"
```

---

### Task 2: Core — Secure Storage + API Client

**Files:**
- Create: `apps/patient_app/lib/core/secure_storage.dart`
- Create: `apps/patient_app/lib/core/api_client.dart`
- Delete all content in existing `lib/core/api_client.dart`

- [ ] **Step 1: Write test for SecureStorage**

Create `apps/patient_app/test/core/secure_storage_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:patient_app/core/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('writeToken stores token and readToken retrieves it', () async {
    await SecureStorage.writeToken('test_jwt_123');
    final token = await SecureStorage.readToken();
    expect(token, 'test_jwt_123');
  });

  test('deleteToken removes token', () async {
    await SecureStorage.writeToken('test_jwt_123');
    await SecureStorage.deleteToken();
    final token = await SecureStorage.readToken();
    expect(token, isNull);
  });

  test('readToken returns null when no token stored', () async {
    final token = await SecureStorage.readToken();
    expect(token, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd apps/patient_app
flutter test test/core/secure_storage_test.dart
```

Expected: FAIL — `secure_storage.dart` does not exist.

- [ ] **Step 3: Implement secure_storage.dart**

Create `apps/patient_app/lib/core/secure_storage.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Single access point for JWT token persistence.
/// All other files must use this class — never import flutter_secure_storage directly.
class SecureStorage {
  // Use encrypted shared prefs on Android, Keychain on iOS
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const _tokenKey = 'auth_token';

  static Future<void> writeToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<String?> readToken() =>
      _storage.read(key: _tokenKey);

  static Future<void> deleteToken() =>
      _storage.delete(key: _tokenKey);
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/core/secure_storage_test.dart
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Write test for ApiClient error mapping**

Create `apps/patient_app/test/core/api_client_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/core/api_client.dart';

void main() {
  test('ApiException toString includes status code and message', () {
    const e = ApiException('Not found', statusCode: 404);
    expect(e.toString(), contains('404'));
    expect(e.toString(), contains('Not found'));
  });

  test('ApiException with no status code still formats', () {
    const e = ApiException('Network error');
    expect(e.toString(), isA<String>());
    expect(e.message, 'Network error');
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

```bash
flutter test test/core/api_client_test.dart
```

Expected: FAIL — `api_client.dart` does not export `ApiException`.

- [ ] **Step 7: Implement api_client.dart**

Overwrite `apps/patient_app/lib/core/api_client.dart`:

```dart
import 'package:dio/dio.dart';
import 'secure_storage.dart';

/// Typed error thrown by all ApiClient methods.
/// Callers catch ApiException — never raw DioException.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  // Base URL injected via --dart-define=API_BASE_URL=https://...
  // Defaults to Android emulator localhost for debug builds.
  static const _baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');

  static final Dio _dio = _buildDio();

  static Dio _buildDio() {
    // Enforce HTTPS in release builds — crash fast rather than leak data
    assert(
      _baseUrl.startsWith('https://') || _baseUrl.startsWith('http://10.0.2.2'),
      'API_BASE_URL must use HTTPS in production. Got: $_baseUrl',
    );
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {'Content-Type': 'application/json'},
      ),
    );
    dio.interceptors.add(_AuthInterceptor());
    return dio;
  }

  static Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get(path, queryParameters: query);
      return res.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  static Future<dynamic> post(String path, {Object? body}) async {
    try {
      final res = await _dio.post(path, data: body);
      return res.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  static Future<dynamic> patch(String path, {Object? body}) async {
    try {
      final res = await _dio.patch(path, data: body);
      return res.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  static ApiException _mapError(DioException e) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    final detail = (data is Map) ? data['detail'] as String? : null;
    return ApiException(
      detail ?? e.message ?? 'Network error',
      statusCode: code,
    );
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Read token fresh from secure storage on every request — never cache in memory
    final token = await SecureStorage.readToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token rejected by server — wipe it so auth guard redirects to login
      SecureStorage.deleteToken();
    }
    return handler.next(err);
  }
}
```

- [ ] **Step 8: Run tests**

```bash
flutter test test/core/
```

Expected: 5 tests PASS.

- [ ] **Step 9: Commit**

```bash
git add apps/patient_app/lib/core/ apps/patient_app/test/core/
git commit -m "feat(patient): secure storage + Dio api client with typed errors"
```

---

### Task 3: Core — Theme

**Files:**
- Rewrite: `apps/patient_app/lib/core/theme.dart`

- [ ] **Step 1: Implement theme.dart**

```dart
import 'package:flutter/material.dart';

const _seed = Color(0xFF1565C0); // Healthcare blue
const _emergency = Color(0xFFE53935); // Emergency red

final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: const Color(0xFFF0F4FF),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1565C0),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFBBD3F5)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFBBD3F5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _emergency),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _seed,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFDDE8FA)),
    ),
  ),
);

/// Emergency red — use only for the emergency action button
Color get emergencyColor => _emergency;
```

- [ ] **Step 2: Commit**

```bash
git add apps/patient_app/lib/core/theme.dart
git commit -m "feat(patient): Material3 healthcare blue theme"
```

---

### Task 4: Core — Router with Auth Guard

**Files:**
- Rewrite: `apps/patient_app/lib/core/router.dart`

- [ ] **Step 1: Implement router.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_notifier.dart';
import '../features/auth/login_screen.dart';
import '../features/rides/home_screen.dart';
import '../features/rides/ride_detail_screen.dart';
import '../features/rides/scheduled_rides_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/',
        builder: (_, __) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'ride/:id',
            builder: (_, state) =>
                RideDetailScreen(rideId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'rides',
            builder: (_, __) => const ScheduledRidesScreen(),
          ),
          GoRoute(path: 'profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(path: 'settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
  );
});
```

- [ ] **Step 2: Commit**

```bash
git add apps/patient_app/lib/core/router.dart
git commit -m "feat(patient): go_router with auth redirect guard"
```

---

### Task 5: Shared Widgets

**Files:**
- Create: `apps/patient_app/lib/widgets/app_button.dart`
- Create: `apps/patient_app/lib/widgets/app_text_field.dart`
- Create: `apps/patient_app/lib/widgets/ride_card.dart`
- Create: `apps/patient_app/lib/widgets/loading_overlay.dart`

- [ ] **Step 1: Create app_button.dart**

```dart
import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? backgroundColor;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.backgroundColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? scheme.primary,
        disabledBackgroundColor: (backgroundColor ?? scheme.primary).withOpacity(0.6),
      ),
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(label),
              ],
            ),
    );
  }
}
```

- [ ] **Step 2: Create app_text_field.dart**

```dart
import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;

  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffix,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      // Sanitize: trim whitespace on validation, not on input (preserves UX)
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffix: suffix,
      ),
    );
  }
}
```

- [ ] **Step 3: Create ride_card.dart**

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RideCard extends StatelessWidget {
  final String rideId;
  final String status;
  final String rideType;
  final String pickupAddress;
  final String requestedAt;
  final double? estimatedFare;
  final VoidCallback? onTap;

  const RideCard({
    super.key,
    required this.rideId,
    required this.status,
    required this.rideType,
    required this.pickupAddress,
    required this.requestedAt,
    this.estimatedFare,
    this.onTap,
  });

  Color _statusColor(BuildContext context) => switch (status) {
    'completed' => Colors.green,
    'cancelled' => Colors.red,
    'active' || 'driver_assigned' => Theme.of(context).colorScheme.primary,
    _ => Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(requestedAt)?.toLocal();
    final formatted = dt != null
        ? DateFormat('dd MMM yyyy, h:mm a').format(dt)
        : requestedAt;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    rideType == 'emergency' ? Icons.emergency : Icons.directions_car,
                    size: 16,
                    color: rideType == 'emergency' ? Colors.red : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    rideType.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(context).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                pickupAddress,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    formatted,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (estimatedFare != null) ...[
                    const Spacer(),
                    Text(
                      'PKR ${estimatedFare!.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create loading_overlay.dart**

```dart
import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  final bool loading;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.loading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (loading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

/// Skeleton shimmer card for list loading states
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bar(context, width: 120, height: 12),
            const SizedBox(height: 10),
            _bar(context, width: double.infinity, height: 14),
            const SizedBox(height: 6),
            _bar(context, width: 180, height: 12),
          ],
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add apps/patient_app/lib/widgets/
git commit -m "feat(patient): shared widget library — AppButton, AppTextField, RideCard, skeleton"
```

---

### Task 6: Auth Feature — Notifier + Login Screen

**Files:**
- Create: `apps/patient_app/lib/features/auth/auth_notifier.dart`
- Create: `apps/patient_app/lib/features/auth/login_screen.dart`
- Create: `apps/patient_app/test/features/auth/auth_notifier_test.dart`

- [ ] **Step 1: Write failing test for AuthNotifier**

Create `apps/patient_app/test/features/auth/auth_notifier_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patient_app/features/auth/auth_notifier.dart';

class MockSecureStorage extends Mock {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('initial state is AsyncData(null) when no token stored', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final state = await container.read(authNotifierProvider.future);
    expect(state, isNull);
  });

  test('logout clears token and state becomes AsyncData(null)', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'tok'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.notifier).logout();
    final state = await container.read(authNotifierProvider.future);
    expect(state, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/auth/auth_notifier_test.dart
```

Expected: FAIL — `auth_notifier.dart` does not exist.

- [ ] **Step 3: Implement auth_notifier.dart**

Create `apps/patient_app/lib/features/auth/auth_notifier.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/secure_storage.dart';

class AuthUser {
  final String token;
  final String role;
  const AuthUser({required this.token, required this.role});
}

class AuthNotifier extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    // Restore session from secure storage on app start
    final token = await SecureStorage.readToken();
    if (token == null) return null;
    return AuthUser(token: token, role: 'patient');
  }

  Future<void> login(String phone, String password) async {
    state = const AsyncLoading();
    try {
      // Clear any stale token before sending login request
      await SecureStorage.deleteToken();
      final data = await ApiClient.post('/api/v1/auth/login', body: {
        'phone': phone.trim(),
        'password': password,
      }) as Map<String, dynamic>;

      final token = data['access_token'] as String;
      final role = data['role'] as String? ?? 'patient';

      // Persist token in secure storage before updating state
      await SecureStorage.writeToken(token);
      state = AsyncData(AuthUser(token: token, role: role));
    } on ApiException catch (e) {
      state = AsyncError(e, StackTrace.current);
    } catch (e) {
      state = AsyncError(
        ApiException('An unexpected error occurred'),
        StackTrace.current,
      );
    }
  }

  Future<void> logout() async {
    await SecureStorage.deleteToken();
    state = const AsyncData(null);
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthUser?>(AuthNotifier.new);
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/auth/auth_notifier_test.dart
```

Expected: 2 tests PASS.

- [ ] **Step 5: Implement login_screen.dart**

Create `apps/patient_app/lib/features/auth/login_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import 'auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authNotifierProvider.notifier)
        .login(_phoneCtrl.text, _passCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    // Show snackbar on error
    ref.listen(authNotifierProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error.toString().replaceFirst('ApiException(', '').replaceAll(')', '')),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            // Logo area
            const Icon(Icons.local_taxi, size: 56, color: Colors.white),
            const SizedBox(height: 12),
            const Text(
              'SmartRide',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const Text(
              'Patient Portal',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 40),
            // Form card
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D1B3E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter your registered phone number',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 28),
                      AppTextField(
                        label: 'Phone Number',
                        hint: '+92300000000',
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          // Sanitize and validate phone: must be non-empty and start with + or digit
                          final trimmed = v?.trim() ?? '';
                          if (trimmed.isEmpty) return 'Phone number is required';
                          if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(trimmed)) {
                            return 'Enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Password',
                        controller: _passCtrl,
                        obscureText: _obscurePass,
                        prefixIcon: Icons.lock_outline,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        suffix: GestureDetector(
                          onTap: () => setState(() => _obscurePass = !_obscurePass),
                          child: Icon(
                            _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password is required';
                          if (v.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      AppButton(
                        label: 'Sign In',
                        onPressed: _submit,
                        loading: isLoading,
                        icon: Icons.login,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Commit**

```bash
git add apps/patient_app/lib/features/auth/ apps/patient_app/test/features/auth/
git commit -m "feat(patient): auth notifier + login screen with validation"
```

---

### Task 7: Rides Feature — Notifier + Home Screen

**Files:**
- Create: `apps/patient_app/lib/features/rides/rides_notifier.dart`
- Create: `apps/patient_app/lib/features/rides/home_screen.dart`

- [ ] **Step 1: Implement rides_notifier.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

class Ride {
  final String id;
  final String status;
  final String rideType;
  final String pickupAddress;
  final String requestedAt;
  final double? estimatedFarePkr;
  final String? driverId;

  const Ride({
    required this.id,
    required this.status,
    required this.rideType,
    required this.pickupAddress,
    required this.requestedAt,
    this.estimatedFarePkr,
    this.driverId,
  });

  factory Ride.fromJson(Map<String, dynamic> j) => Ride(
    id: j['id'] as String,
    status: j['status'] as String,
    rideType: j['ride_type'] as String,
    pickupAddress: (j['pickup_address'] as String?) ?? 'Unknown location',
    requestedAt: j['requested_at'] as String,
    estimatedFarePkr: (j['estimated_fare_pkr'] as num?)?.toDouble(),
    driverId: j['driver_id'] as String?,
  );
}

class RidesState {
  final List<Ride> rides;
  final Ride? activeRide;
  final int total;

  const RidesState({
    this.rides = const [],
    this.activeRide,
    this.total = 0,
  });
}

class RidesNotifier extends AsyncNotifier<RidesState> {
  @override
  Future<RidesState> build() => _fetch();

  Future<RidesState> _fetch() async {
    final data = await ApiClient.get('/api/v1/rides', query: {'page_size': 50}) 
        as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((e) => Ride.fromJson(e as Map<String, dynamic>))
        .toList();
    final active = items.where((r) =>
      r.status == 'active' || r.status == 'driver_assigned' || r.status == 'pending'
    ).firstOrNull;
    return RidesState(rides: items, activeRide: active, total: data['total'] as int);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final ridesNotifierProvider =
    AsyncNotifierProvider<RidesNotifier, RidesState>(RidesNotifier.new);
```

- [ ] **Step 2: Implement home_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../features/auth/auth_notifier.dart';
import '../../widgets/ride_card.dart';
import '../../widgets/loading_overlay.dart';
import 'rides_notifier.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  String? _locationLabel;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _fetchLocation();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _locationLabel = 'Location unavailable');
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    setState(() => _locationLabel = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}');
  }

  Future<void> _callEmergency() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emergency Ride'),
        content: const Text('This will request an emergency vehicle immediately. Continue?'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => ctx.pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Call Emergency'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    // TODO: implement emergency ride API call (POST /api/v1/rides with ride_type=emergency)
  }

  @override
  Widget build(BuildContext context) {
    final ridesAsync = ref.watch(ridesNotifierProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartRide'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(ridesNotifierProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location chip
              if (_locationLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFDDE8FA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Color(0xFF1565C0)),
                      const SizedBox(width: 4),
                      Text(
                        _locationLabel!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1565C0)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              // Emergency button
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, child) => Transform.scale(
                  scale: 1.0 + (_pulseCtrl.value * 0.03),
                  child: child,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton.icon(
                    onPressed: _callEmergency,
                    icon: const Icon(Icons.emergency, size: 24),
                    label: const Text(
                      'EMERGENCY RIDE',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Active ride banner
              ridesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (state) => state.activeRide != null
                    ? GestureDetector(
                        onTap: () => context.push('/ride/${state.activeRide!.id}'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.directions_car, color: Colors.white, size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Active Ride',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      state.activeRide!.status.replaceAll('_', ' ').toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.white),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              // Recent rides
              const Text(
                'Recent Rides',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0D1B3E)),
              ),
              const SizedBox(height: 12),
              ridesAsync.when(
                loading: () => Column(
                  children: List.generate(3, (_) => const SkeletonCard()),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
                ),
                data: (state) => state.rides.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No rides yet', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    : Column(
                        children: state.rides.take(10).map((r) => RideCard(
                          rideId: r.id,
                          status: r.status,
                          rideType: r.rideType,
                          pickupAddress: r.pickupAddress,
                          requestedAt: r.requestedAt,
                          estimatedFare: r.estimatedFarePkr,
                          onTap: () => context.push('/ride/${r.id}'),
                        )).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => context.push('/rides'),
                icon: const Icon(Icons.list),
                label: const Text('View all rides'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add apps/patient_app/lib/features/rides/
git commit -m "feat(patient): rides notifier + home screen with emergency button and GPS"
```

---

### Task 8: Ride Detail + Scheduled Rides Screens

**Files:**
- Create: `apps/patient_app/lib/features/rides/ride_detail_screen.dart`
- Create: `apps/patient_app/lib/features/rides/scheduled_rides_screen.dart`

- [ ] **Step 1: Implement ride_detail_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';

final _rideDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final data = await ApiClient.get('/api/v1/rides/$id/detail');
  return data as Map<String, dynamic>;
});

class RideDetailScreen extends ConsumerWidget {
  final String rideId;
  const RideDetailScreen({super.key, required this.rideId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideAsync = ref.watch(_rideDetailProvider(rideId));

    return Scaffold(
      appBar: AppBar(title: const Text('Ride Details')),
      body: rideAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (ride) {
          final patient = ride['patient'] as Map<String, dynamic>?;
          final driver = ride['driver'] as Map<String, dynamic>?;
          final hospital = ride['hospital'] as Map<String, dynamic>?;
          final triage = ride['triage'] as Map<String, dynamic>?;
          final status = ride['status'] as String;
          final requestedAt = ride['requested_at'] as String;
          final dt = DateTime.tryParse(requestedAt)?.toLocal();
          final formatted = dt != null
              ? DateFormat('dd MMM yyyy, h:mm a').format(dt)
              : requestedAt;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _StatusBadge(status: status),
                const SizedBox(height: 16),
                _Section(title: 'Trip Info', children: [
                  _Row('Type', ride['ride_type'] as String),
                  _Row('Requested', formatted),
                  _Row('Pickup', (ride['pickup_address'] as String?) ?? 'N/A'),
                  if (ride['estimated_fare_pkr'] != null)
                    _Row('Est. Fare', 'PKR ${ride['estimated_fare_pkr']}'),
                  if (ride['final_fare_pkr'] != null)
                    _Row('Final Fare', 'PKR ${ride['final_fare_pkr']}'),
                ]),
                if (driver != null) ...[
                  const SizedBox(height: 12),
                  _Section(title: 'Driver', children: [
                    _Row('Name', driver['full_name'] as String),
                    _Row('Phone', driver['phone'] as String),
                    _Row('Vehicle', '${driver['vehicle_type']} — ${driver['vehicle_plate']}'),
                  ]),
                ],
                if (hospital != null) ...[
                  const SizedBox(height: 12),
                  _Section(title: 'Hospital', children: [
                    _Row('Name', hospital['name'] as String),
                    _Row('Address', hospital['address'] as String),
                    _Row('City', hospital['city'] as String),
                  ]),
                ],
                if (triage != null) ...[
                  const SizedBox(height: 12),
                  _Section(title: 'Triage', children: [
                    _Row('Symptoms', triage['symptom_text'] as String),
                    _Row('Specialty', triage['predicted_specialty'] as String),
                    _Row('Severity', triage['severity_level'] as String),
                  ]),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'completed' => Colors.green,
      'cancelled' => Colors.red,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1565C0))),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Implement scheduled_rides_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/ride_card.dart';
import '../../widgets/loading_overlay.dart';
import 'rides_notifier.dart';

const _statuses = ['all', 'pending', 'active', 'completed', 'cancelled'];

class ScheduledRidesScreen extends ConsumerStatefulWidget {
  const ScheduledRidesScreen({super.key});

  @override
  ConsumerState<ScheduledRidesScreen> createState() => _ScheduledRidesScreenState();
}

class _ScheduledRidesScreenState extends ConsumerState<ScheduledRidesScreen> {
  String _selectedStatus = 'all';

  @override
  Widget build(BuildContext context) {
    final ridesAsync = ref.watch(ridesNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('All Rides')),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _statuses.length,
              itemBuilder: (_, i) {
                final s = _statuses[i];
                final selected = s == _selectedStatus;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s.capitalize()),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedStatus = s),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ridesAsync.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(16),
                children: List.generate(5, (_) => const SkeletonCard()),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (state) {
                final filtered = _selectedStatus == 'all'
                    ? state.rides
                    : state.rides.where((r) => r.status == _selectedStatus).toList();
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No rides', style: TextStyle(color: Colors.grey)),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(ridesNotifierProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => RideCard(
                      rideId: filtered[i].id,
                      status: filtered[i].status,
                      rideType: filtered[i].rideType,
                      pickupAddress: filtered[i].pickupAddress,
                      requestedAt: filtered[i].requestedAt,
                      estimatedFare: filtered[i].estimatedFarePkr,
                      onTap: () => context.push('/ride/${filtered[i].id}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
```

- [ ] **Step 3: Commit**

```bash
git add apps/patient_app/lib/features/rides/
git commit -m "feat(patient): ride detail and scheduled rides screens"
```

---

### Task 9: Profile, Settings + main.dart

**Files:**
- Create: `apps/patient_app/lib/features/profile/profile_notifier.dart`
- Create: `apps/patient_app/lib/features/profile/profile_screen.dart`
- Create: `apps/patient_app/lib/features/profile/settings_screen.dart`
- Rewrite: `apps/patient_app/lib/main.dart`

- [ ] **Step 1: Implement profile_notifier.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

class PatientProfile {
  final String id;
  final String fullName;
  final String phone;
  final String? dateOfBirth;
  final String? mobilityNeeds;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  const PatientProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    this.dateOfBirth,
    this.mobilityNeeds,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  factory PatientProfile.fromJson(Map<String, dynamic> j) => PatientProfile(
    id: j['id'] as String,
    fullName: j['full_name'] as String,
    phone: j['phone'] as String,
    dateOfBirth: j['date_of_birth'] as String?,
    mobilityNeeds: j['mobility_needs'] as String?,
    emergencyContactName: j['emergency_contact_name'] as String?,
    emergencyContactPhone: j['emergency_contact_phone'] as String?,
  );
}

class ProfileNotifier extends AsyncNotifier<PatientProfile?> {
  @override
  Future<PatientProfile?> build() => _fetch();

  Future<PatientProfile?> _fetch() async {
    try {
      final data = await ApiClient.get('/api/v1/patients/me') as Map<String, dynamic>;
      return PatientProfile.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final profileNotifierProvider =
    AsyncNotifierProvider<ProfileNotifier, PatientProfile?>(ProfileNotifier.new);
```

- [ ] **Step 2: Implement profile_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_notifier.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFF1565C0),
                  child: Text(
                    profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  profile.fullName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                Text(profile.phone, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Personal Info',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1565C0))),
                        const Divider(height: 16),
                        _InfoRow('Date of Birth', profile.dateOfBirth ?? 'Not set'),
                        _InfoRow('Mobility Needs', profile.mobilityNeeds ?? 'None'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Emergency Contact',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1565C0))),
                        const Divider(height: 16),
                        _InfoRow('Name', profile.emergencyContactName ?? 'Not set'),
                        _InfoRow('Phone', profile.emergencyContactPhone ?? 'Not set'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Implement settings_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../auth/auth_notifier.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => ctx.pop(true),
                      child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authNotifierProvider.notifier).logout();
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            trailing: FutureBuilder(
              future: PackageInfo.fromPlatform(),
              builder: (_, snap) => Text(
                snap.data?.version ?? '—',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

> Note: Add `package_info_plus: 8.1.2` to pubspec.yaml before this task.

- [ ] **Step 4: Implement main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SmartRidePatientApp()));
}

class SmartRidePatientApp extends ConsumerWidget {
  const SmartRidePatientApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SmartRide Patient',
      theme: appTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add apps/patient_app/lib/
git commit -m "feat(patient): profile, settings, main.dart — patient app complete"
```

---

## PHASE 2: Driver App

### Task 10: Driver App pubspec.yaml + Core

**Files:**
- Rewrite: `apps/driver_app/pubspec.yaml`
- Create: `apps/driver_app/lib/core/secure_storage.dart`
- Create: `apps/driver_app/lib/core/api_client.dart`
- Create: `apps/driver_app/lib/core/theme.dart`
- Create: `apps/driver_app/lib/core/router.dart`

- [ ] **Step 1: Write driver_app pubspec.yaml**

```yaml
name: driver_app
description: SmartRide driver mobile application
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: 2.5.1
  dio: 5.6.0
  flutter_secure_storage: 9.2.2
  go_router: 14.2.7
  intl: 0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: 4.0.0
  mocktail: 1.0.4

flutter:
  uses-material-design: true
```

- [ ] **Step 2: Copy and adapt core files**

`apps/driver_app/lib/core/secure_storage.dart` — identical to patient app:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Single access point for JWT token persistence.
class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _tokenKey = 'auth_token';

  static Future<void> writeToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<String?> readToken() => _storage.read(key: _tokenKey);

  static Future<void> deleteToken() => _storage.delete(key: _tokenKey);
}
```

`apps/driver_app/lib/core/api_client.dart` — identical to patient app (copy verbatim).

`apps/driver_app/lib/core/theme.dart`:

```dart
import 'package:flutter/material.dart';

// Driver app uses teal/green accent to distinguish from patient app
const _seed = Color(0xFF00695C);

final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: _seed),
  scaffoldBackgroundColor: const Color(0xFFF0FAF7),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF00695C),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFB2DFDB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF00695C), width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _seed,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFB2DFDB)),
    ),
  ),
);
```

- [ ] **Step 3: Install driver dependencies**

```bash
cd apps/driver_app
flutter pub get
```

- [ ] **Step 4: Commit**

```bash
git add apps/driver_app/pubspec.yaml apps/driver_app/pubspec.lock apps/driver_app/lib/core/
git commit -m "feat(driver): pinned deps + core infrastructure"
```

---

### Task 11: Driver Auth + Router

**Files:**
- Create: `apps/driver_app/lib/features/auth/auth_notifier.dart`
- Create: `apps/driver_app/lib/features/auth/login_screen.dart`
- Create: `apps/driver_app/lib/core/router.dart`

- [ ] **Step 1: Implement auth_notifier.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/secure_storage.dart';

class AuthDriver {
  final String token;
  const AuthDriver({required this.token});
}

class AuthNotifier extends AsyncNotifier<AuthDriver?> {
  @override
  Future<AuthDriver?> build() async {
    final token = await SecureStorage.readToken();
    if (token == null) return null;
    return AuthDriver(token: token);
  }

  Future<void> login(String phone, String password) async {
    state = const AsyncLoading();
    try {
      await SecureStorage.deleteToken(); // clear stale token before login
      final data = await ApiClient.post('/api/v1/auth/login', body: {
        'phone': phone.trim(),
        'password': password,
      }) as Map<String, dynamic>;

      final role = data['role'] as String? ?? '';
      if (role != 'driver') {
        throw const ApiException('This account is not a driver account');
      }

      final token = data['access_token'] as String;
      await SecureStorage.writeToken(token);
      state = AsyncData(AuthDriver(token: token));
    } on ApiException catch (e) {
      state = AsyncError(e, StackTrace.current);
    } catch (e) {
      state = AsyncError(const ApiException('Unexpected error'), StackTrace.current);
    }
  }

  Future<void> logout() async {
    await SecureStorage.deleteToken();
    state = const AsyncData(null);
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthDriver?>(AuthNotifier.new);
```

- [ ] **Step 2: Implement router.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_notifier.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/ride/active_ride_screen.dart';
import '../features/profile/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (_, state) {
      final loggedIn = authState.valueOrNull != null;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/',
        builder: (_, __) => const DashboardScreen(),
        routes: [
          GoRoute(
            path: 'ride/:id',
            builder: (_, s) => ActiveRideScreen(rideId: s.pathParameters['id']!),
          ),
          GoRoute(path: 'profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
    ],
  );
});
```

- [ ] **Step 3: Implement login_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import 'auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).login(_phoneCtrl.text, _passCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error.toString()),
          backgroundColor: Colors.red[700],
        ));
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF00695C),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            const Icon(Icons.drive_eta, size: 56, color: Colors.white),
            const SizedBox(height: 12),
            const Text('SmartRide Driver',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 40),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF0FAF7),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Driver Sign In',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF004D40))),
                      const SizedBox(height: 28),
                      AppTextField(
                        label: 'Phone Number',
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.isEmpty) return 'Phone is required';
                          if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(t)) return 'Invalid phone number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Password',
                        controller: _passCtrl,
                        obscureText: _obscure,
                        prefixIcon: Icons.lock_outline,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        suffix: GestureDetector(
                          onTap: () => setState(() => _obscure = !_obscure),
                          child: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20, color: Colors.grey),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password is required';
                          if (v.length < 6) return 'Minimum 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      AppButton(label: 'Sign In', onPressed: _submit, loading: auth.isLoading,
                        icon: Icons.login, backgroundColor: const Color(0xFF00695C)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create driver shared widgets**

Copy `app_button.dart` and `app_text_field.dart` from patient app to `apps/driver_app/lib/widgets/` (identical implementation).

- [ ] **Step 5: Commit**

```bash
git add apps/driver_app/lib/
git commit -m "feat(driver): auth notifier with role check + login screen + router"
```

---

### Task 12: Driver Dashboard + Active Ride

**Files:**
- Create: `apps/driver_app/lib/features/dashboard/dashboard_notifier.dart`
- Create: `apps/driver_app/lib/features/dashboard/dashboard_screen.dart`
- Create: `apps/driver_app/lib/features/ride/ride_notifier.dart`
- Create: `apps/driver_app/lib/features/ride/active_ride_screen.dart`

- [ ] **Step 1: Implement dashboard_notifier.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

class PendingRide {
  final String id;
  final String pickupAddress;
  final String rideType;
  final String requestedAt;

  const PendingRide({
    required this.id,
    required this.pickupAddress,
    required this.rideType,
    required this.requestedAt,
  });

  factory PendingRide.fromJson(Map<String, dynamic> j) => PendingRide(
    id: j['id'] as String,
    pickupAddress: (j['pickup_address'] as String?) ?? 'Unknown',
    rideType: j['ride_type'] as String,
    requestedAt: j['requested_at'] as String,
  );
}

class DashboardState {
  final bool isOnline;
  final List<PendingRide> pendingRides;
  final String? activeRideId;

  const DashboardState({
    this.isOnline = false,
    this.pendingRides = const [],
    this.activeRideId,
  });

  DashboardState copyWith({bool? isOnline, List<PendingRide>? pendingRides, String? activeRideId}) =>
    DashboardState(
      isOnline: isOnline ?? this.isOnline,
      pendingRides: pendingRides ?? this.pendingRides,
      activeRideId: activeRideId ?? this.activeRideId,
    );
}

class DashboardNotifier extends AsyncNotifier<DashboardState> {
  @override
  Future<DashboardState> build() => _fetch();

  Future<DashboardState> _fetch() async {
    final data = await ApiClient.get('/api/v1/rides',
      query: {'status': 'pending', 'page_size': 20}) as Map<String, dynamic>;
    final rides = (data['items'] as List)
        .map((e) => PendingRide.fromJson(e as Map<String, dynamic>))
        .toList();
    return DashboardState(pendingRides: rides);
  }

  Future<void> toggleOnline() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final newStatus = !current.isOnline;
    try {
      await ApiClient.patch('/api/v1/drivers/me/status',
        body: {'status': newStatus ? 'available' : 'offline'});
      state = AsyncData(current.copyWith(isOnline: newStatus));
    } on ApiException catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final dashboardNotifierProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardState>(DashboardNotifier.new);
```

- [ ] **Step 2: Implement dashboard_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dashboard_notifier.dart';
import '../auth/auth_notifier.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(dashboardNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (state) => RefreshIndicator(
          onRefresh: () => ref.read(dashboardNotifierProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Online toggle
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: state.isOnline ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          state.isOnline ? 'Online — accepting rides' : 'Offline',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: state.isOnline ? Colors.green[700] : Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: state.isOnline,
                          onChanged: (_) =>
                              ref.read(dashboardNotifierProvider.notifier).toggleOnline(),
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Pending Rides (${state.pendingRides.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF004D40)),
                ),
                const SizedBox(height: 12),
                if (state.pendingRides.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No pending rides', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ...state.pendingRides.map((r) => _RideRequestCard(
                    ride: r,
                    onAccept: () => context.push('/ride/${r.id}'),
                  )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RideRequestCard extends StatelessWidget {
  final PendingRide ride;
  final VoidCallback onAccept;
  const _RideRequestCard({required this.ride, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(ride.requestedAt)?.toLocal();
    final formatted = dt != null ? DateFormat('h:mm a').format(dt) : '';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              ride.rideType == 'emergency' ? Icons.emergency : Icons.directions_car,
              color: ride.rideType == 'emergency' ? Colors.red : const Color(0xFF00695C),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ride.pickupAddress,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(formatted, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00695C),
                minimumSize: const Size(70, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Accept', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Implement active_ride_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';

final _rideDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return await ApiClient.get('/api/v1/rides/$id/detail') as Map<String, dynamic>;
});

const _nextStatus = {
  'pending': 'driver_assigned',
  'driver_assigned': 'active',
  'active': 'completed',
};

const _nextLabel = {
  'pending': 'Accept Ride',
  'driver_assigned': 'Start Ride',
  'active': 'Complete Ride',
};

class ActiveRideScreen extends ConsumerWidget {
  final String rideId;
  const ActiveRideScreen({super.key, required this.rideId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideAsync = ref.watch(_rideDetailProvider(rideId));

    return Scaffold(
      appBar: AppBar(title: const Text('Active Ride')),
      body: rideAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (ride) {
          final status = ride['status'] as String;
          final patient = ride['patient'] as Map<String, dynamic>?;
          final nextS = _nextStatus[status];
          final nextL = _nextLabel[status];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00695C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF00695C)),
                  ),
                ),
                const SizedBox(height: 16),
                if (patient != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Patient',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF00695C))),
                          const Divider(height: 16),
                          _Row('Name', patient['full_name'] as String),
                          _Row('Phone', patient['phone'] as String),
                          if (patient['mobility_needs'] != null)
                            _Row('Mobility Needs', patient['mobility_needs'] as String),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _Row('Pickup', (ride['pickup_address'] as String?) ?? 'N/A'),
                const Spacer(),
                if (nextS != null)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        await ApiClient.patch('/api/v1/rides/$rideId/status',
                          body: {'status': nextS});
                        ref.invalidate(_rideDetailProvider(rideId));
                        if (nextS == 'completed' && context.mounted) {
                          context.pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00695C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(nextL ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                if (status == 'active') ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () async {
                      await ApiClient.patch('/api/v1/rides/$rideId/status',
                        body: {'status': 'cancelled'});
                      if (context.mounted) context.pop();
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel Ride', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(width: 100,
          child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
      ],
    ),
  );
}
```

- [ ] **Step 4: Commit**

```bash
git add apps/driver_app/lib/features/
git commit -m "feat(driver): dashboard with availability toggle + active ride screen"
```

---

### Task 13: Driver Profile + main.dart

**Files:**
- Create: `apps/driver_app/lib/features/profile/profile_screen.dart`
- Create: `apps/driver_app/lib/main.dart`

- [ ] **Step 1: Implement driver profile_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../auth/auth_notifier.dart';

final _driverProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return await ApiClient.get('/api/v1/drivers/me') as Map<String, dynamic>;
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_driverProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF00695C),
                child: Text(
                  ((profile['full_name'] as String?) ?? '?').isNotEmpty
                      ? (profile['full_name'] as String)[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Text(profile['full_name'] as String? ?? '',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text(profile['phone'] as String? ?? '', style: const TextStyle(color: Colors.grey)),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: (profile['is_verified'] as bool? ?? false)
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  (profile['is_verified'] as bool? ?? false) ? 'Verified Driver' : 'Pending Verification',
                  style: TextStyle(
                    color: (profile['is_verified'] as bool? ?? false) ? Colors.green[700] : Colors.orange[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Vehicle Info',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF00695C))),
                      const Divider(height: 16),
                      _Row('License', profile['license_no'] as String? ?? 'N/A'),
                      _Row('Plate', profile['vehicle_plate'] as String? ?? 'N/A'),
                      _Row('Vehicle', profile['vehicle_type'] as String? ?? 'N/A'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).logout();
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
      ],
    ),
  );
}
```

- [ ] **Step 2: Implement driver main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SmartRideDriverApp()));
}

class SmartRideDriverApp extends ConsumerWidget {
  const SmartRideDriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SmartRide Driver',
      theme: appTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Step 3: Run analysis on both apps**

```bash
cd apps/patient_app && flutter analyze --no-fatal-infos
cd ../driver_app && flutter analyze --no-fatal-infos
```

Expected: No errors. Warnings acceptable for unused parameters in stubs.

- [ ] **Step 4: Run all tests**

```bash
cd apps/patient_app && flutter test
```

Expected: All tests PASS.

- [ ] **Step 5: Final commit**

```bash
git add apps/driver_app/lib/ apps/patient_app/lib/
git commit -m "feat(driver): profile screen + main.dart — driver app complete"
```

---

## Post-Implementation Verification

- [ ] Both apps build without errors: `flutter build apk --debug` in each app directory
- [ ] Login works with `+92300000001` / `admin123` on patient app, driver credentials on driver app
- [ ] JWT stored in flutter_secure_storage (verify via Android Studio Device Explorer: no plain-text token in SharedPreferences)
- [ ] API requests include `Authorization: Bearer <token>` header (verify via Charles Proxy or Dio log interceptor)
- [ ] All form fields reject empty/invalid input with visible error messages
- [ ] Logout clears token and redirects to login
