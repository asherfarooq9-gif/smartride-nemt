import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../core/providers.dart';
import '../core/theme.dart';

class ScheduledRideScreen extends ConsumerStatefulWidget {
  const ScheduledRideScreen({super.key});

  @override
  ConsumerState<ScheduledRideScreen> createState() => _ScheduledRideScreenState();
}

class _ScheduledRideScreenState extends ConsumerState<ScheduledRideScreen> {
  final _addressCtrl = TextEditingController();
  DateTime? _scheduledFor;
  Map<String, dynamic>? _selectedHospital;
  double? _lat, _lng;
  bool _locating = false;

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(
        colorScheme: const ColorScheme.light(primary: kBlue),
      ), child: child!),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))));
    if (time == null || !mounted) return;
    setState(() {
      _scheduledFor = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) { if (mounted) setState(() => _locating = false); return; }
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _addressCtrl.text = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
          _locating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (_scheduledFor == null) {
      _showSnack('Please select date and time'); return;
    }
    if (_lat == null || _lng == null) {
      _showSnack('Please set pickup location'); return;
    }
    if (_scheduledFor!.isBefore(DateTime.now())) {
      _showSnack('Please select a future date and time'); return;
    }

    final ride = await ref.read(ridesProvider.notifier).bookScheduled(
      lat: _lat!,
      lng: _lng!,
      address: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
      scheduledFor: _scheduledFor!,
    );
    if (!mounted) return;
    if (ride != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride booked successfully!'), backgroundColor: kGreen),
      );
      context.go('/');
    } else {
      final error = ref.read(ridesProvider).error;
      _showSnack(error ?? 'Booking failed');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: kRed));
  }

  @override
  Widget build(BuildContext context) {
    final rides = ref.watch(ridesProvider);
    final hospitals = ref.watch(hospitalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled Ride')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Date & time
          const _SectionLabel('Pickup Date & Time'),
          GestureDetector(
            onTap: _pickDateTime,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _scheduledFor != null ? kBlue : const Color(0xFFD1D5DB)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: _scheduledFor != null ? kBlue : Colors.grey, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _scheduledFor != null
                        ? '${_scheduledFor!.day}/${_scheduledFor!.month}/${_scheduledFor!.year}  ${_scheduledFor!.hour.toString().padLeft(2, '0')}:${_scheduledFor!.minute.toString().padLeft(2, '0')}'
                        : 'Select date and time',
                    style: TextStyle(color: _scheduledFor != null ? const Color(0xFF111827) : Colors.grey, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Pickup location
          const _SectionLabel('Pickup Location'),
          TextFormField(
            controller: _addressCtrl,
            onChanged: (_) { _lat = null; _lng = null; },
            decoration: InputDecoration(
              hintText: 'Enter address or use GPS',
              suffixIcon: _locating
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(
                      icon: const Icon(Icons.my_location_rounded, color: kBlue),
                      onPressed: _useCurrentLocation,
                      tooltip: 'Use current location',
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Hospital
          const _SectionLabel('Destination Hospital (Optional)'),
          if (hospitals.isEmpty)
            const Padding(padding: EdgeInsets.all(8), child: Text('Loading hospitals…', style: TextStyle(color: Colors.grey)))
          else
            DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: _selectedHospital,
              hint: const Text('Select hospital (optional)'),
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: hospitals.map((h) => DropdownMenuItem<Map<String, dynamic>>(
                value: h,
                child: Text(h['name'] as String? ?? '', overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (h) => setState(() => _selectedHospital = h),
            ),
          const SizedBox(height: 32),

          // Summary card
          if (_scheduledFor != null && _lat != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: kBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBlue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Booking Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kBlue)),
                  const SizedBox(height: 8),
                  Text('📅  $_scheduledFor', style: const TextStyle(fontSize: 13)),
                  Text('📍  ${_addressCtrl.text}', style: const TextStyle(fontSize: 13)),
                  if (_selectedHospital != null)
                    Text('🏥  ${_selectedHospital!['name']}', style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),

          ElevatedButton(
            onPressed: rides.loading ? null : _submit,
            child: rides.loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Book Scheduled Ride'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF374151))),
  );
}
