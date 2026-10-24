import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/date_format.dart';
import 'package:patient_app/core/location.dart';
import 'package:smartride_core/smartride_core.dart' as core;

const _specialties = [
  'General OPD', 'Cardiology', 'Gynecology / Maternity',
  'Orthopedics', 'Pediatrics', 'Dialysis',
  'Eye / ENT', 'Neurology', 'Oncology', 'Dental',
];

final _hospitalsProvider =
    FutureProvider.autoDispose<List<core.HospitalResponse>>(
  (_) => core.getHospitals(),
);

class ScheduleTripScreen extends ConsumerStatefulWidget {
  const ScheduleTripScreen({super.key});

  @override
  ConsumerState<ScheduleTripScreen> createState() => _ScheduleTripScreenState();
}

class _ScheduleTripScreenState extends ConsumerState<ScheduleTripScreen> {
  final _addressCtrl = TextEditingController();
  core.HospitalResponse? _selectedHospital;
  String? _selectedSpecialty;
  DateTime? _selectedDateTime;
  bool _submitting = false;

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null || !mounted) return;
    setState(() {
      _selectedDateTime = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    final dt = _selectedDateTime;
    if (dt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a date and time')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final position = await ref.read(locationReaderProvider)();
      if (position == null) {
        throw const core.AppError(
            'We need your location to book a pickup. Turn on location and try again.');
      }
      final ride = await core.createScheduledRide(core.ScheduledRideRequest(
        pickupLat: position.latitude,
        pickupLng: position.longitude,
        pickupAddress: _addressCtrl.text.trim().isEmpty
            ? 'Current location'
            : _addressCtrl.text.trim(),
        scheduledFor: dt,
        hospitalId: _selectedHospital?.id,
      ));
      if (!mounted) return;
      context.go('/booking-confirmed/${ride.id}');
    } on core.AppError catch (e) {
      _showError(e.message);
    } on Exception catch (e, st) {
      core.ErrorReporter.report('Booking a ride failed', e, st);
      _showError('Booking failed. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: core.kError,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hospitalsAsync = ref.watch(_hospitalsProvider);

    return Scaffold(
      backgroundColor: core.kBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  core.kSpaceLG, core.kSpaceMD, core.kSpaceLG, 0),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios,
                        size: 16, color: core.kPatientPrimary),
                    label: const Text('Back',
                        style: TextStyle(
                            color: core.kPatientPrimary,
                            fontSize: core.kFontSM)),
                    style: TextButton.styleFrom(
                      minimumSize:
                          const Size(core.kMinTapTarget, core.kMinTapTarget),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                  core.kSpaceXL, core.kSpaceMD, core.kSpaceXL, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Book a Ride',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: core.kSpaceXS),
                  Text('Schedule a medical trip in advance',
                      style: TextStyle(
                          fontSize: core.kFontSM,
                          color: core.kTextSecondary)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(core.kSpaceXL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location
                    const _SectionLabel('LOCATIONS'),
                    const SizedBox(height: core.kSpaceSM),
                    _LocationTile(
                      icon: Icons.my_location,
                      title: 'Use my current location',
                      color: core.kPatientPrimary,
                      onTap: () => setState(() => _addressCtrl.text = ''),
                    ),
                    const SizedBox(height: core.kSpaceSM),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Type your pickup address...',
                        prefixIcon: Icon(Icons.edit_location_alt_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: core.kSpaceXL),

                    // Hospital
                    const _SectionLabel('DESTINATION'),
                    const SizedBox(height: core.kSpaceSM),
                    hospitalsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Could not load hospitals'),
                      data: (hospitals) => _HospitalPicker(
                        hospitals: hospitals,
                        selected: _selectedHospital,
                        onChanged: (h) =>
                            setState(() => _selectedHospital = h),
                      ),
                    ),
                    const SizedBox(height: core.kSpaceXL),

                    // Specialty
                    const _SectionLabel('SPECIALTY / DEPARTMENT (OPTIONAL)'),
                    const SizedBox(height: core.kSpaceSM),
                    Wrap(
                      spacing: core.kSpaceSM,
                      runSpacing: core.kSpaceSM,
                      children: _specialties.map((s) {
                        final selected = _selectedSpecialty == s;
                        return FilterChip(
                          label: Text(s),
                          selected: selected,
                          onSelected: (_) => setState(() =>
                              _selectedSpecialty = selected ? null : s),
                          showCheckmark: false,
                          backgroundColor: Colors.white,
                          selectedColor: core.kPatientPrimary,
                          side: BorderSide(
                            color: selected
                                ? core.kPatientPrimary
                                : core.kDivider,
                          ),
                          labelStyle: TextStyle(
                            fontSize: core.kFontSM,
                            color: selected ? Colors.white : core.kOnSurface,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: core.kSpaceSM,
                              vertical: core.kSpaceSM),
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: core.kSpaceXL),

                    // When
                    const _SectionLabel('WHEN'),
                    const SizedBox(height: core.kSpaceSM),
                    _TapCard(
                      semanticLabel: _selectedDateTime == null
                          ? 'Select date and time'
                          : 'Date and time: ${formatDateTime(_selectedDateTime!)}. Change',
                      onTap: _pickDateTime,
                      padding: core.kSpaceLG,
                      child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: core.kPatientPrimary, size: 20),
                            const SizedBox(width: core.kSpaceMD),
                            Text(
                              _selectedDateTime == null
                                  ? 'Select date & time'
                                  : formatDateTime(_selectedDateTime!),
                              style: TextStyle(
                                color: _selectedDateTime == null
                                    ? core.kTextSecondary
                                    : core.kOnSurface,
                                fontSize: core.kFontMD,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_forward_ios,
                                size: 14, color: core.kTextSecondary),
                          ],
                      ),
                    ),
                    const SizedBox(height: core.kSpaceXXL),
                    SizedBox(
                      height: core.kMinTapTarget,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Confirm Booking',
                                style: TextStyle(
                                    fontSize: core.kFontMD,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: core.kFontSM,
          fontWeight: FontWeight.w600,
          color: core.kTextSecondary,
          letterSpacing: 1.1,
        ),
      );
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _TapCard(
        semanticLabel: title,
        onTap: onTap,
        padding: core.kSpaceMD,
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: core.kSpaceMD),
            Flexible(
              child: Text(title,
                  style:
                      TextStyle(color: color, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

/// Bordered, tappable white card with ripple and a screen reader label.
class _TapCard extends StatelessWidget {
  const _TapCard({
    required this.semanticLabel,
    required this.onTap,
    required this.padding,
    required this.child,
  });

  final String semanticLabel;
  final VoidCallback onTap;
  final double padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(core.kRadiusMD),
          side: const BorderSide(color: core.kDivider),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(core.kRadiusMD),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: core.kMinTapTarget),
            child: Padding(padding: EdgeInsets.all(padding), child: child),
          ),
        ),
      ),
    );
  }
}

class _HospitalPicker extends StatelessWidget {
  const _HospitalPicker({
    required this.hospitals,
    required this.selected,
    required this.onChanged,
  });
  final List<core.HospitalResponse> hospitals;
  final core.HospitalResponse? selected;
  final ValueChanged<core.HospitalResponse?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<core.HospitalResponse>(
      initialValue: selected,
      hint: const Text('Select destination hospital'),
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.local_hospital_outlined),
        border: OutlineInputBorder(),
      ),
      items: hospitals
          .map((h) => DropdownMenuItem(
                value: h,
                child: Text(h.name, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}
