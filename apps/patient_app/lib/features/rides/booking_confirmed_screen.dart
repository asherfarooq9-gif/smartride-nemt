import 'package:patient_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;

class BookingConfirmedScreen extends StatelessWidget {
  const BookingConfirmedScreen({super.key, required this.rideId});
  final String rideId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: core.kBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(core.kSpaceXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              // Success icon
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                    border: Border.all(color: core.kDriverPrimary, width: 2),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: core.kDriverPrimary,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: core.kSpaceXL),
              Text(
                context.l10n.rideBooked,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: core.kSpaceXS),
              Text(
                context.l10n.bookingBody,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: core.kFontSM,
                  color: core.kTextSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: core.kSpaceXL),
              // Booking details card
              Container(
                padding: const EdgeInsets.all(core.kSpaceLG),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(core.kRadiusLG),
                  border: Border.all(color: core.kDivider),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                        label: context.l10n.bookingId,
                        value: '#SR-${rideId.substring(0, 6).toUpperCase()}'),
                    const Divider(height: core.kSpaceXL),
                    _DetailRow(
                        label: context.l10n.pickupTitle,
                        value: context.l10n.currentLocation),
                    const Divider(height: core.kSpaceXL),
                    _DetailRow(
                        label: context.l10n.rideTypeLabel,
                        value: context.l10n.standardLabel),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                height: core.kMinTapTarget,
                child: ElevatedButton(
                  onPressed: () => context.go('/rides'),
                  child: Text(
                    context.l10n.viewMyRides,
                    style: const TextStyle(
                      fontSize: core.kFontMD,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: core.kSpaceMD),
              TextButton(
                onPressed: () => context.go('/'),
                child: Text(
                  context.l10n.backToHome,
                  style: const TextStyle(fontSize: core.kFontMD),
                ),
              ),
              const SizedBox(height: core.kSpaceLG),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: core.kTextSecondary, fontSize: core.kFontSM)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: core.kFontSM)),
        ],
      );
}
