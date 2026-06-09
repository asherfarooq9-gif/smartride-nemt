import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smartride_core/smartride_core.dart';

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  Future<void> _requestPermission(BuildContext context) async {
    await Geolocator.requestPermission();
    if (context.mounted) Navigator.of(context).pop();
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
            const Icon(
              Icons.location_on_outlined,
              size: 64,
              color: kTeal600,
            ),
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
            const Text(
              'SmartRide needs your location to find nearby drivers and hospitals.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: kFontBody,
                color: kText600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: kSpaceXXL),
            PrimaryButton(
              label: 'Allow Access',
              onPressed: () => _requestPermission(context),
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

class NoDriversScreen extends StatelessWidget {
  const NoDriversScreen({super.key});

  void _call1122(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calling 1122…')),
    );
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
            const Icon(
              Icons.car_crash_outlined,
              size: 64,
              color: kRed600,
            ),
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
            const Icon(
              Icons.wifi_off_outlined,
              size: 64,
              color: kText400,
            ),
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
