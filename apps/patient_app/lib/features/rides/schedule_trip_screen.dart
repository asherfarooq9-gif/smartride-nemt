import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/l10n/l10n.dart';
import 'package:patient_app/core/date_format.dart';
import 'package:patient_app/core/location.dart';
import 'package:patient_app/core/request_id.dart';
import 'package:smartride_core/smartride_core.dart' as core;

const _specialties = [
  'General OPD',
  'Cardiology',
  'Gynecology / Maternity',
  'Orthopedics',
  'Pediatrics',
  'Dialysis',
  'Eye / ENT',
  'Neurology',
  'Oncology',
  'Dental',
];

final scheduleHospitalsProvider =
    FutureProvider.autoDispose<List<core.HospitalResponse>>(
  (_) => core.getHospitals(),
);

typedef ScheduledSeriesCreator = Future<List<core.RideResponse>> Function(
  core.ScheduledRideRequest request, {
  required String repeat,
  required int occurrences,
  String? idempotencyKey,
});

final scheduledSeriesCreatorProvider =
    Provider<ScheduledSeriesCreator>((ref) => core.createScheduledSeries);

typedef ScheduledRideCreator = Future<core.RideResponse> Function(
  core.ScheduledRideRequest request, {
  String? idempotencyKey,
});

/// Indirection so tests can count bookings without a server.
final scheduledRideCreatorProvider =
    Provider<ScheduledRideCreator>((ref) => core.createScheduledRide);

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
  // null = a single trip; otherwise "daily" or "weekly", [_occurrences] times.
  String? _repeat;
  int _occurrences = 4;
  ({String form, core.ScheduledRideRequest request, String key})? _attempt;

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
      _selectedDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  /// The request for the current form, with the key and pickup point of this
  /// booking attempt. A retry of the same form reuses both, so a timeout
  /// followed by another tap books one ride, and the server never sees the same
  /// key with a slightly different pickup point.
  Future<(core.ScheduledRideRequest, String)> _attemptFor(DateTime dt) async {
    final address = _addressCtrl.text.trim();
    final form = '$address|$dt|${_selectedHospital?.id}|$_repeat|$_occurrences';
    final cached = _attempt;
    if (cached != null && cached.form == form) {
      return (cached.request, cached.key);
    }
    final position = await ref.read(locationReaderProvider)();
    if (position == null) {
      throw const core.AppError(
          'We need your location to book a pickup. Turn on location and try again.');
    }
    final request = core.ScheduledRideRequest(
      pickupLat: position.latitude,
      pickupLng: position.longitude,
      pickupAddress: address.isEmpty ? 'Current location' : address,
      scheduledFor: dt,
      hospitalId: _selectedHospital?.id,
    );
    final attempt = (form: form, request: request, key: newRequestId());
    _attempt = attempt;
    return (attempt.request, attempt.key);
  }

  Future<void> _submit() async {
    final dt = _selectedDateTime;
    if (dt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.chooseDateTime)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final l10n = context.l10n; // read before the awaits
      final (request, key) = await _attemptFor(dt);
      final repeat = _repeat;
      final String firstRideId;
      String? bookedMessage;
      if (repeat == null) {
        final ride = await ref.read(scheduledRideCreatorProvider)(request,
            idempotencyKey: key);
        firstRideId = ride.id;
      } else {
        final rides = await ref.read(scheduledSeriesCreatorProvider)(request,
            repeat: repeat, occurrences: _occurrences, idempotencyKey: key);
        firstRideId = rides.first.id;
        bookedMessage = l10n.tripsBooked(rides.length);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.go('/booking-confirmed/$firstRideId');
      if (bookedMessage != null) {
        messenger.showSnackBar(SnackBar(content: Text(bookedMessage)));
      }
    } on core.AppError catch (e) {
      _showError(e.message);
    } on Exception catch (e, st) {
      core.ErrorReporter.report('Booking a ride failed', e, st);
      _showError('Booking failed. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _repeatChoices() {
    final l = context.l10n;
    final options = <(String?, String)>[
      (null, l.noRepeat),
      ('daily', l.repeatDaily),
      ('weekly', l.repeatWeekly),
    ];
    final dt = _selectedDateTime;
    final step = _repeat == 'daily' ? 1 : 7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: core.kSpaceSM,
          children: [
            for (final (value, label) in options)
              ChoiceChip(
                label: Text(label),
                selected: _repeat == value,
                onSelected: (_) => setState(() => _repeat = value),
              ),
          ],
        ),
        if (_repeat != null) ...[
          const SizedBox(height: core.kSpaceMD),
          Row(
            children: [
              Expanded(child: Text(l.numberOfTrips)),
              IconButton(
                tooltip: context.l10n.fewerRides,
                onPressed: _occurrences > 2
                    ? () => setState(() => _occurrences--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_occurrences',
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                tooltip: context.l10n.moreRides,
                onPressed: _occurrences < 12
                    ? () => setState(() => _occurrences++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          if (dt != null)
            Text(
              l.lastTripOn(
                formatWhen(dt.add(Duration(days: step * (_occurrences - 1))),
                    lang: Localizations.localeOf(context).languageCode),
              ),
              style: const TextStyle(color: core.kTextSecondary),
            ),
        ],
      ],
    );
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
    final hospitalsAsync = ref.watch(scheduleHospitalsProvider);

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
                    label: Text(context.l10n.back,
                        style: const TextStyle(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  core.kSpaceXL, core.kSpaceMD, core.kSpaceXL, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.bookARide,
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: core.kSpaceXS),
                  Text(context.l10n.scheduleInAdvance,
                      style: const TextStyle(
                          fontSize: core.kFontSM, color: core.kTextSecondary)),
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
                    _SectionLabel(context.l10n.locationsLabel),
                    const SizedBox(height: core.kSpaceSM),
                    _LocationTile(
                      icon: Icons.my_location,
                      title: context.l10n.useCurrentLocation,
                      color: core.kPatientPrimary,
                      onTap: () => setState(() => _addressCtrl.text = ''),
                    ),
                    const SizedBox(height: core.kSpaceSM),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: InputDecoration(
                        hintText: context.l10n.typePickupAddress,
                        prefixIcon:
                            const Icon(Icons.edit_location_alt_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: core.kSpaceXL),

                    // Hospital
                    _SectionLabel(context.l10n.destinationLabel),
                    const SizedBox(height: core.kSpaceSM),
                    hospitalsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) =>
                          Text(context.l10n.couldNotLoadHospitals),
                      data: (hospitals) => _HospitalPicker(
                        hospitals: hospitals,
                        selected: _selectedHospital,
                        onChanged: (h) => setState(() => _selectedHospital = h),
                      ),
                    ),
                    const SizedBox(height: core.kSpaceXL),

                    // Specialty
                    _SectionLabel(context.l10n.specialtyLabel),
                    const SizedBox(height: core.kSpaceSM),
                    Wrap(
                      spacing: core.kSpaceSM,
                      runSpacing: core.kSpaceSM,
                      children: _specialties.map((s) {
                        final selected = _selectedSpecialty == s;
                        return FilterChip(
                          label: Text(s),
                          selected: selected,
                          onSelected: (_) => setState(
                              () => _selectedSpecialty = selected ? null : s),
                          showCheckmark: false,
                          backgroundColor: Colors.white,
                          selectedColor: core.kPatientPrimary,
                          side: BorderSide(
                            color:
                                selected ? core.kPatientPrimary : core.kDivider,
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
                    _SectionLabel(context.l10n.whenLabel),
                    const SizedBox(height: core.kSpaceSM),
                    _TapCard(
                      semanticLabel: _selectedDateTime == null
                          ? 'Select date and time'
                          : 'Date and time: ${formatDateTime(_selectedDateTime!, lang: Localizations.localeOf(context).languageCode)}. Change',
                      onTap: _pickDateTime,
                      padding: core.kSpaceLG,
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              color: core.kPatientPrimary, size: 20),
                          const SizedBox(width: core.kSpaceMD),
                          Expanded(
                            child: Text(
                              _selectedDateTime == null
                                  ? context.l10n.selectDateTime
                                  : formatDateTime(_selectedDateTime!,
                                      lang: Localizations.localeOf(context)
                                          .languageCode),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _selectedDateTime == null
                                    ? core.kTextSecondary
                                    : core.kOnSurface,
                                fontSize: core.kFontMD,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              size: 14, color: core.kTextSecondary),
                        ],
                      ),
                    ),
                    const SizedBox(height: core.kSpaceXL),
                    _SectionLabel(context.l10n.repeatLabel),
                    const SizedBox(height: core.kSpaceSM),
                    _repeatChoices(),
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
                            : Text(context.l10n.confirmBooking,
                                style: const TextStyle(
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
                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
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
      // Fill the row so a long hospital name ellipsizes instead of overflowing.
      isExpanded: true,
      hint: Text(
        context.l10n.selectHospital,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: core.kFontBody,
          fontWeight: FontWeight.w400,
          color: core.kTextSecondary,
        ),
      ),
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
