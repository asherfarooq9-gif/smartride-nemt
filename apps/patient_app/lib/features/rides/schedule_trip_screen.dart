import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/pending_ride_queue.dart';
import 'package:smartride_core/smartride_core.dart' as core;

const _specialties = [
  'General OPD', 'Cardiology', 'Gynecology / Maternity',
  'Orthopedics', 'Pediatrics', 'Dialysis',
  'Eye / ENT', 'Neurology', 'Oncology', 'Dental',
];

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

  final _hospitalsProvider = FutureProvider.autoDispose<List<core.HospitalResponse>>(
    (_) => core.getHospitals(),
  );

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
    if (_addressCtrl.text.trim().isEmpty && _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }
    final dt = _selectedDateTime ?? DateTime.now().add(const Duration(hours: 2));
    setState(() => _submitting = true);
    try {
      final ride = await core.createScheduledRide(core.ScheduledRideRequest(
        pickupAddress: _addressCtrl.text.trim().isEmpty
            ? 'Current location'
            : _addressCtrl.text.trim(),
        scheduledFor: dt,
        hospitalId: _selectedHospital?.id,
      ));
      if (!mounted) return;
      context.go('/booking-confirmed/${ride.id}');
    } on core.NetworkError {
      // Offline: don't just fail — queue it and resubmit automatically once
      // connectivity returns, so the patient doesn't lose the whole form.
      await PendingRideQueue.instance.enqueue(
        pickupAddress: _addressCtrl.text.trim().isEmpty
            ? 'Current location'
            : _addressCtrl.text.trim(),
        scheduledFor: dt,
        hospitalId: _selectedHospital?.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          "You're offline — this booking will be submitted automatically "
          'once you have a connection.',
        ),
      ));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is core.AppError ? e.message : 'Booking failed'),
        backgroundColor: core.kError,
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Row(
                      children: [
                        Icon(Icons.arrow_back_ios,
                            size: 16, color: core.kPatientPrimary),
                        Text('Back',
                            style: TextStyle(
                                color: core.kPatientPrimary,
                                fontSize: core.kFontSM)),
                      ],
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
                        return GestureDetector(
                          onTap: () => setState(() =>
                              _selectedSpecialty = selected ? null : s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: core.kSpaceLG,
                                vertical: core.kSpaceSM),
                            decoration: BoxDecoration(
                              color: selected
                                  ? core.kPatientPrimary
                                  : Colors.white,
                              borderRadius:
                                  BorderRadius.circular(core.kRadiusXXL),
                              border: Border.all(
                                color: selected
                                    ? core.kPatientPrimary
                                    : core.kDivider,
                              ),
                            ),
                            child: Text(
                              s,
                              style: TextStyle(
                                fontSize: core.kFontSM,
                                color: selected
                                    ? Colors.white
                                    : core.kOnSurface,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: core.kSpaceXL),

                    // When
                    const _SectionLabel('WHEN'),
                    const SizedBox(height: core.kSpaceSM),
                    GestureDetector(
                      onTap: _pickDateTime,
                      child: Container(
                        padding: const EdgeInsets.all(core.kSpaceLG),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(core.kRadiusMD),
                          border: Border.all(color: core.kDivider),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: core.kPatientPrimary, size: 20),
                            const SizedBox(width: core.kSpaceMD),
                            Text(
                              _selectedDateTime == null
                                  ? 'Select date & time'
                                  : _formatDateTime(_selectedDateTime!),
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

  String _formatDateTime(DateTime dt) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} · $h:$m $ampm';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
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
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(core.kSpaceMD),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(core.kRadiusMD),
            border: Border.all(color: core.kDivider),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: core.kSpaceMD),
              Text(title,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
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
