import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Location permission screen ─────────────────────────────────────────────────

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _permanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final status = await Geolocator.checkPermission();
    if (!mounted) return;
    setState(() {
      _permanentlyDenied = status == LocationPermission.deniedForever;
    });
  }

  Future<void> _requestOrOpenSettings() async {
    if (_permanentlyDenied) {
      await Geolocator.openAppSettings();
      return;
    }
    final result = await Geolocator.requestPermission();
    if (!mounted) return;
    if (result == LocationPermission.always ||
        result == LocationPermission.whileInUse) {
      Navigator.of(context).pop();
    } else if (result == LocationPermission.deniedForever) {
      setState(() => _permanentlyDenied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enable Location'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(kSpaceXXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.location_on_outlined, size: 64, color: kTeal600),
            const SizedBox(height: kSpaceXL),
            const Text(
              'Enable Location',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: kFontHeading,
                fontWeight: FontWeight.w700,
                color: kText900,
              ),
            ),
            const SizedBox(height: kSpaceMD),
            Text(
              _permanentlyDenied
                  ? 'Location access was denied. Open app settings to enable it.'
                  : 'SmartRide needs your location to find nearby drivers and hospitals.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: kFontBody,
                color: kText600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: kSpaceXXL),
            PrimaryButton(
              label:
                  _permanentlyDenied ? 'Open App Settings' : 'Allow Access',
              onPressed: _requestOrOpenSettings,
              color: kTeal600,
              height: kButtonHeight,
            ),
            const SizedBox(height: kSpaceMD),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Not Now',
                  style: TextStyle(color: kText400),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── No drivers screen ──────────────────────────────────────────────────────────

class NoDriversScreen extends StatelessWidget {
  const NoDriversScreen({super.key});

  Future<void> _call1122(BuildContext context) async {
    final uri = Uri.parse('tel:1122');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open dialler — call 1122 manually')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kRed600,
        foregroundColor: Colors.white,
        title: const Text('No Drivers Available'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(kSpaceXXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.car_crash_outlined, size: 64, color: kRed600),
            const SizedBox(height: kSpaceXL),
            const Text(
              'No drivers nearby',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: kFontHeading,
                fontWeight: FontWeight.w700,
                color: kText900,
              ),
            ),
            const SizedBox(height: kSpaceMD),
            const Text(
              'There are no available drivers in your area right now.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: kFontBody,
                color: kText600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: kSpaceXXL),
            PrimaryButton(
              label: 'Keep Searching',
              onPressed: () => Navigator.of(context).pop(),
              color: kTeal600,
              height: kButtonHeight,
            ),
            const SizedBox(height: kSpaceMD),
            Center(
              child: TextButton(
                onPressed: () => _call1122(context),
                child: const Text(
                  'Call 1122',
                  style: TextStyle(
                    color: kRed600,
                    fontWeight: FontWeight.w600,
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

// ── No internet screen ─────────────────────────────────────────────────────────

class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('No Connection'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(kSpaceXXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 64, color: kText400),
            const SizedBox(height: kSpaceXL),
            const Text(
              'No internet connection',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: kFontHeading,
                fontWeight: FontWeight.w700,
                color: kText900,
              ),
            ),
            const SizedBox(height: kSpaceMD),
            const Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: kFontBody,
                color: kText600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: kSpaceXXL),
            PrimaryButton(
              label: 'Retry',
              onPressed: () => Navigator.of(context).pop(),
              color: kTeal600,
              height: kButtonHeight,
            ),
          ],
        ),
      ),
    );
  }
}
