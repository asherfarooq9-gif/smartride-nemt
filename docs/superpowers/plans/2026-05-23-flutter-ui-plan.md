# SmartRide Flutter UI Polish Plan (Stage 9)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add consistent loading/error/empty states, fix hardcoded colors, add a shared AsyncStateWidget, add a countdown timer to the driver pending-ride card, add double-tap protection on status buttons, and add semantic accessibility labels across both apps.

**Architecture:** Two separate Flutter apps (`apps/patient_app`, `apps/driver_app`), both using Riverpod for state management and go_router for navigation. Theme constants live in `lib/core/theme.dart` in each app. Shared widgets live in `lib/widgets/`. There is no shared package between apps — changes must be made independently in each.

**Tech Stack:** Flutter (Dart), Riverpod, go_router, geolocator, google_maps_flutter.

**Build verification command (run after each task):**
```bash
cd apps/patient_app && flutter build apk --debug --no-pub 2>&1 | tail -5
cd apps/driver_app && flutter build apk --debug --no-pub 2>&1 | tail -5
```

---

### Task 1: Add Theme Color Constants to Driver App

**Files:**
- Modify: `apps/driver_app/lib/core/theme.dart`

The driver app `dashboard_screen.dart` uses hardcoded `Color(0xFF00695C)`, `Colors.green`, `Colors.red`, `Colors.grey` directly in widgets. These must come from the theme.

- [ ] **Step 1: Export named color constants from driver theme.dart**

In `apps/driver_app/lib/core/theme.dart`, add these exports at the bottom of the file (after `appTheme`):

```dart
/// Primary teal — use for branded UI elements
const Color driverPrimary = Color(0xFF00695C);

/// Dark teal — use for section headers, emphasized text
const Color driverPrimaryDark = Color(0xFF004D40);

/// Online status green
const Color statusOnline = Color(0xFF2E7D32);

/// Offline / neutral grey
const Color statusOffline = Color(0xFF757575);

/// Error / danger red
const Color statusError = Color(0xFFD32F2F);
```

- [ ] **Step 2: Verify the file compiles**

```bash
cd apps/driver_app && flutter analyze lib/core/theme.dart
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add apps/driver_app/lib/core/theme.dart
git commit -m "feat(driver): export named color constants from theme"
```

---

### Task 2: Replace Hardcoded Colors in Driver DashboardScreen

**Files:**
- Modify: `apps/driver_app/lib/features/dashboard/dashboard_screen.dart`

- [ ] **Step 1: Add the theme import**

At the top of `apps/driver_app/lib/features/dashboard/dashboard_screen.dart`, add:

```dart
import '../../core/theme.dart';
```

- [ ] **Step 2: Replace all hardcoded color references**

Apply these replacements throughout the file:

| Find | Replace with |
|------|-------------|
| `Colors.green` (icon color for online dot) | `statusOnline` |
| `Colors.grey` (icon color for offline dot) | `statusOffline` |
| `Colors.green[700]` (online text color) | `statusOnline` |
| `Colors.grey` (offline text color) | `statusOffline` |
| `Colors.green[200]` (switch track color) | `statusOnline.withValues(alpha: 0.4)` |
| `Color(0xFF004D40)` | `driverPrimaryDark` |
| `Color(0xFF00695C)` | `driverPrimary` |
| `Colors.red` (error text) | `statusError` |
| `TextStyle(color: Colors.grey, fontSize: 12)` | `TextStyle(color: statusOffline, fontSize: 12)` |

- [ ] **Step 3: Analyze and build**

```bash
cd apps/driver_app && flutter analyze lib/features/dashboard/dashboard_screen.dart
```
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add apps/driver_app/lib/features/dashboard/dashboard_screen.dart
git commit -m "fix(driver): replace hardcoded colors with theme constants in dashboard"
```

---

### Task 3: Create Shared AsyncStateWidget in Patient App

**Files:**
- Create: `apps/patient_app/lib/widgets/async_state_widget.dart`

Many screens repeat the same `ridesAsync.when(loading: ..., error: ..., data: ...)` boilerplate with a bare `CircularProgressIndicator` for loading and a plain red `Text` for errors. Extract this into a typed widget.

- [ ] **Step 1: Create the widget**

```dart
// apps/patient_app/lib/widgets/async_state_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncStateWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  const AsyncStateWidget({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
      data: data,
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
cd apps/patient_app && flutter analyze lib/widgets/async_state_widget.dart
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add apps/patient_app/lib/widgets/async_state_widget.dart
git commit -m "feat(patient): add AsyncStateWidget to reduce loading/error boilerplate"
```

---

### Task 4: Create Shared AsyncStateWidget in Driver App

**Files:**
- Create: `apps/driver_app/lib/widgets/async_state_widget.dart`

The driver app needs the same widget (copied, since there is no shared package).

- [ ] **Step 1: Create the widget**

```dart
// apps/driver_app/lib/widgets/async_state_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';

class AsyncStateWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  const AsyncStateWidget({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: statusError, size: 40),
              const SizedBox(height: 12),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(color: statusError),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
      data: data,
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
cd apps/driver_app && flutter analyze lib/widgets/async_state_widget.dart
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add apps/driver_app/lib/widgets/async_state_widget.dart
git commit -m "feat(driver): add AsyncStateWidget"
```

---

### Task 5: Add Empty State to Patient Scheduled Rides Screen

**Files:**
- Modify: `apps/patient_app/lib/features/rides/scheduled_rides_screen.dart`

When the rides list is empty (e.g. first-time user), nothing is shown. Add a friendly empty state.

- [ ] **Step 1: Find the rides list render**

In `apps/patient_app/lib/features/rides/scheduled_rides_screen.dart`, find where `ridesAsync.when(...)` renders the list. The `data:` branch uses a `ListView.builder` with `filteredRides`.

- [ ] **Step 2: Add an empty state inside the data branch**

Replace the `data:` branch content with:

```dart
data: (rides) {
  final filteredRides = _selectedStatus == 'all'
      ? rides
      : rides.where((r) => r['status'] == _selectedStatus).toList();

  if (filteredRides.isEmpty) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_car_outlined, size: 56, color: Color(0xFFBBD3F5)),
          const SizedBox(height: 16),
          Text(
            _selectedStatus == 'all' ? 'No rides yet' : 'No $_selectedStatus rides',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1565C0),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your ride history will appear here.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  return ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: filteredRides.length,
    itemBuilder: (_, i) => RideCard(ride: filteredRides[i]),
  );
},
```

- [ ] **Step 3: Analyze**

```bash
cd apps/patient_app && flutter analyze lib/features/rides/scheduled_rides_screen.dart
```
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add apps/patient_app/lib/features/rides/scheduled_rides_screen.dart
git commit -m "feat(patient): add empty state to ride history screen"
```

---

### Task 6: Add Empty State to Driver Dashboard (No Pending Rides)

**Files:**
- Modify: `apps/driver_app/lib/features/dashboard/dashboard_screen.dart`

When `state.pendingRides` is empty and the driver is online, the rides section is blank. Show a helpful message.

- [ ] **Step 1: Find the pending rides list in dashboard_screen.dart**

Locate where `state.pendingRides` is rendered (a `ListView.builder` or `Column` with `.map(...)`).

- [ ] **Step 2: Add the empty state**

Wrap or replace the existing list render:

```dart
if (state.pendingRides.isEmpty)
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Icon(Icons.inbox_outlined, size: 48, color: driverPrimary.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text(
          state.isOnline ? 'Waiting for ride requests…' : 'Go online to receive rides',
          style: TextStyle(color: statusOffline, fontSize: 14),
        ),
      ],
    ),
  )
else
  ...state.pendingRides.map((ride) => _RideCard(ride: ride)),
```

- [ ] **Step 3: Analyze and build**

```bash
cd apps/driver_app && flutter analyze lib/features/dashboard/dashboard_screen.dart
```
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add apps/driver_app/lib/features/dashboard/dashboard_screen.dart
git commit -m "feat(driver): show empty state when no pending rides"
```

---

### Task 7: Add Countdown Timer to Driver Pending Ride Card

**Files:**
- Modify: `apps/driver_app/lib/features/dashboard/dashboard_screen.dart`

The spec requires a visual 30-second countdown on the pending ride card so the driver knows how long they have to accept.

- [ ] **Step 1: Add a stateful ride card widget at the bottom of dashboard_screen.dart**

Add this class before the closing of the file (after the main `DashboardScreen` widget):

```dart
class _RideCard extends StatefulWidget {
  final PendingRide ride;
  const _RideCard({required this.ride});

  @override
  State<_RideCard> createState() => _RideCardState();
}

class _RideCardState extends State<_RideCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  static const _duration = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _duration)..forward();
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        // Timer expired — ride card can be dismissed or auto-declined
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secondsLeft = ((_duration.inSeconds) * (1 - _ctrl.value)).ceil();
    final isUrgent = secondsLeft <= 10;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.ride.pickupAddress,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                // Countdown ring
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _ctrl,
                        builder: (_, __) => CircularProgressIndicator(
                          value: 1 - _ctrl.value,
                          strokeWidth: 3,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(
                            isUrgent ? statusError : driverPrimary,
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _ctrl,
                        builder: (_, __) => Text(
                          '$secondsLeft',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isUrgent ? statusError : driverPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.ride.rideType.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                color: widget.ride.rideType == 'emergency'
                    ? statusError
                    : statusOffline,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (secondsLeft > 0)
              SizedBox(
                width: double.infinity,
                child: Semantics(
                  label: 'Accept ride request',
                  button: true,
                  child: ElevatedButton(
                    onPressed: () => context.push('/ride/${widget.ride.id}'),
                    child: const Text('Accept Ride'),
                  ),
                ),
              )
            else
              const Center(
                child: Text('Request expired', style: TextStyle(color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update the empty state section to use `_RideCard`**

In Task 6 you already added `...state.pendingRides.map((ride) => _RideCard(ride: ride))`. Confirm that reference matches the class name `_RideCard` just created.

- [ ] **Step 3: Add go_router import if missing**

```dart
import 'package:go_router/go_router.dart';
```

- [ ] **Step 4: Analyze**

```bash
cd apps/driver_app && flutter analyze lib/features/dashboard/dashboard_screen.dart
```
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add apps/driver_app/lib/features/dashboard/dashboard_screen.dart
git commit -m "feat(driver): add 30-second animated countdown to pending ride card"
```

---

### Task 8: Add Double-Tap Protection to Status Buttons in Active Ride Screen

**Files:**
- Modify: `apps/driver_app/lib/features/ride/active_ride_screen.dart`

The status-update button (Accept/Start Driving/Arrived/Complete) fires a PATCH request on tap. If the driver taps twice, two requests fire and the status can advance past the intended state.

- [ ] **Step 1: Add a `_submitting` state variable**

In `active_ride_screen.dart`, `ActiveRideScreen` is a `ConsumerWidget`. Convert it to a `ConsumerStatefulWidget` to hold the submitting flag:

```dart
class ActiveRideScreen extends ConsumerStatefulWidget {
  final String rideId;
  const ActiveRideScreen({super.key, required this.rideId});

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen> {
  bool _submitting = false;

  Future<void> _advanceStatus(String rideId, String nextStatus) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ApiClient.patch(
        '/api/v1/rides/$rideId/status',
        body: {'status': nextStatus},
      );
      ref.invalidate(_rideDetailProvider(rideId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: statusError),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideAsync = ref.watch(_rideDetailProvider(widget.rideId));
    // ... rest of build
  }
}
```

- [ ] **Step 2: Update the status button to use `_submitting`**

Find where the `ElevatedButton` for advancing status is rendered and update:

```dart
if (nextS != null && nextL != null)
  Semantics(
    label: nextL,
    button: true,
    child: ElevatedButton(
      onPressed: _submitting
          ? null
          : () => _advanceStatus(widget.rideId, nextS),
      child: _submitting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(nextL),
    ),
  ),
```

- [ ] **Step 3: Check ApiClient has a patch method**

Open `apps/driver_app/lib/core/api_client.dart`. If `ApiClient.patch` doesn't exist, add it:

```dart
static Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
  final token = await _getToken();
  final uri = Uri.parse('$_base$path');
  final res = await http.patch(
    uri,
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
    body: body != null ? jsonEncode(body) : null,
  );
  if (res.statusCode == 401) throw Exception('Session expired');
  if (res.statusCode >= 400) {
    final err = jsonDecode(res.body);
    throw Exception(err['detail'] ?? 'Request failed');
  }
  return jsonDecode(res.body);
}
```

- [ ] **Step 4: Analyze**

```bash
cd apps/driver_app && flutter analyze lib/features/ride/active_ride_screen.dart
```
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add apps/driver_app/lib/features/ride/active_ride_screen.dart apps/driver_app/lib/core/api_client.dart
git commit -m "fix(driver): disable status button while PATCH is in-flight to prevent double-tap"
```

---

### Task 9: Add Semantic Accessibility Labels to Patient Emergency Button

**Files:**
- Modify: `apps/patient_app/lib/features/rides/home_screen.dart`

The large emergency button and Book Ride button need `Semantics` wrappers so screen readers can announce them correctly.

- [ ] **Step 1: Locate the emergency button in home_screen.dart**

Find the `GestureDetector` or `ElevatedButton` that calls `_callEmergency()`.

- [ ] **Step 2: Wrap it with Semantics**

```dart
Semantics(
  label: 'Emergency — tap to request immediate medical transport',
  button: true,
  child: /* the existing emergency button widget */,
),
```

- [ ] **Step 3: Find the Book Ride button and add label**

```dart
Semantics(
  label: 'Book a scheduled ride',
  button: true,
  child: /* the existing book ride button */,
),
```

- [ ] **Step 4: Add Semantics to location label**

The location text showing current coordinates should announce it as status info:

```dart
Semantics(
  label: 'Current location: ${_locationLabel ?? "unavailable"}',
  child: Text(_locationLabel ?? 'Fetching location…', ...),
),
```

- [ ] **Step 5: Analyze**

```bash
cd apps/patient_app && flutter analyze lib/features/rides/home_screen.dart
```
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add apps/patient_app/lib/features/rides/home_screen.dart
git commit -m "feat(patient): add semantic accessibility labels to emergency and book-ride buttons"
```

---

### Task 10: Add Error Snackbar with Retry to Patient Emergency Flow

**Files:**
- Modify: `apps/patient_app/lib/features/rides/home_screen.dart`

The `_callEmergency()` method currently catches errors silently (sets `_locationLabel` to an error string at best). Show a `SnackBar` with a retry action on API failure.

- [ ] **Step 1: Find the `_callEmergency` method**

It currently does `await ApiClient.post('/api/v1/rides/emergency', ...)` inside a try/catch. The catch block likely does nothing visible to the user.

- [ ] **Step 2: Update the catch block**

```dart
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Emergency request failed: $e'),
        backgroundColor: Colors.red[700],
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _callEmergency,
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }
}
```

- [ ] **Step 3: Analyze**

```bash
cd apps/patient_app && flutter analyze lib/features/rides/home_screen.dart
```
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add apps/patient_app/lib/features/rides/home_screen.dart
git commit -m "feat(patient): show retry snackbar when emergency API call fails"
```

---

## Final Verification

- [ ] Patient app builds: `cd apps/patient_app && flutter build apk --debug --no-pub`
- [ ] Driver app builds: `cd apps/driver_app && flutter build apk --debug --no-pub`
- [ ] Flutter analyze clean on both apps:
  ```bash
  cd apps/patient_app && flutter analyze
  cd apps/driver_app && flutter analyze
  ```
- [ ] No `Color(0xFF...)` or `Colors.*` literals outside `theme.dart` in driver app
- [ ] Pending ride card shows countdown timer (visual check on emulator/device)
- [ ] Status button shows spinner and ignores second tap while submitting
- [ ] Ride history shows empty state for new user with no rides
