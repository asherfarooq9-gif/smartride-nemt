import 'package:patient_app/l10n/l10n.dart';
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
        title: Text(context.l10n.enableLocation),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(kSpaceXXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.location_on_outlined,
                size: 64, color: kPatient600),
            const SizedBox(height: kSpaceXL),
            Text(
              context.l10n.enableLocation,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: kFontHeading,
                fontWeight: FontWeight.w700,
                color: kText900,
              ),
            ),
            const SizedBox(height: kSpaceMD),
            Text(
              _permanentlyDenied
                  ? context.l10n.locationDeniedBody
                  : context.l10n.locationWhyBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: kFontBody,
                color: kText600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: kSpaceXXL),
            PrimaryButton(
              label: _permanentlyDenied
                  ? context.l10n.openAppSettings
                  : context.l10n.allowAccess,
              onPressed: _requestOrOpenSettings,
              color: kPatient600,
              height: kButtonHeight,
            ),
            const SizedBox(height: kSpaceMD),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  context.l10n.notNow,
                  style: const TextStyle(color: kText400),
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
        SnackBar(content: Text(context.l10n.couldNotOpenDialler)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.noDriversTitle),
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
            Text(
              context.l10n.noDriversNearby,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: kFontHeading,
                fontWeight: FontWeight.w700,
                color: kText900,
              ),
            ),
            const SizedBox(height: kSpaceMD),
            Text(
              context.l10n.noDriversBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: kFontBody,
                color: kText600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: kSpaceXXL),
            PrimaryButton(
              label: context.l10n.keepSearching,
              onPressed: () => Navigator.of(context).pop(),
              color: kPatient600,
              height: kButtonHeight,
            ),
            const SizedBox(height: kSpaceMD),
            Center(
              child: TextButton(
                onPressed: () => _call1122(context),
                child: Text(
                  context.l10n.call1122,
                  style: const TextStyle(
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
        title: Text(context.l10n.noConnectionTitle),
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
            Text(
              context.l10n.noInternet,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: kFontHeading,
                fontWeight: FontWeight.w700,
                color: kText900,
              ),
            ),
            const SizedBox(height: kSpaceMD),
            Text(
              context.l10n.checkConnection,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: kFontBody,
                color: kText600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: kSpaceXXL),
            PrimaryButton(
              label: context.l10n.retry,
              onPressed: () => Navigator.of(context).pop(),
              color: kPatient600,
              height: kButtonHeight,
            ),
          ],
        ),
      ),
    );
  }
}
