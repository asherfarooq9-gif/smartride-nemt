import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../core/providers.dart';

const _quickSymptoms = [
  'Chest pain',
  'Difficulty breathing',
  'Severe bleeding',
  'Unconscious / unresponsive',
  'Stroke symptoms',
  'Severe allergic reaction',
  'Broken bone / injury',
  'High fever',
];

class SymptomInputScreen extends ConsumerStatefulWidget {
  const SymptomInputScreen({super.key});

  @override
  ConsumerState<SymptomInputScreen> createState() => _SymptomInputScreenState();
}

class _SymptomInputScreenState extends ConsumerState<SymptomInputScreen> {
  final Set<String> _selected = {};
  final _freeTextCtrl = TextEditingController();
  Position? _position;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) setState(() => _position = pos);
    } catch (_) {}
  }

  @override
  void dispose() {
    _freeTextCtrl.dispose();
    super.dispose();
  }

  String get _symptomText {
    final parts = [..._selected];
    final free = _freeTextCtrl.text.trim();
    if (free.isNotEmpty) parts.add(free);
    return parts.join('; ');
  }

  Future<void> _submit() async {
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for GPS location…')),
      );
      return;
    }
    final text = _symptomText;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your symptoms')),
      );
      return;
    }

    final ride = await ref.read(ridesProvider.notifier).requestEmergency(
      lat: _position!.latitude,
      lng: _position!.longitude,
      symptomText: text,
    );

    if (!mounted) return;
    if (ride != null) {
      context.go('/tracking/${ride['id']}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(ridesProvider).error ?? 'Request failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rides = ref.watch(ridesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Describe Symptoms'),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick select (tap all that apply):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickSymptoms.map((s) {
                        final sel = _selected.contains(s);
                        return FilterChip(
                          label: Text(s),
                          selected: sel,
                          selectedColor: const Color(0xFFFFCDD2),
                          checkmarkColor: const Color(0xFFD32F2F),
                          onSelected: (v) => setState(() => v ? _selected.add(s) : _selected.remove(s)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Additional details (optional):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _freeTextCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Describe what happened or any other symptoms…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_position == null)
                      const Row(
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Getting your location…', style: TextStyle(color: Colors.grey)),
                        ],
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            'Location: ${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(color: Colors.green, fontSize: 12),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
                  icon: const Icon(Icons.emergency),
                  label: rides.loading
                    ? const Text('Requesting…')
                    : const Text('Request Emergency Ride', style: TextStyle(fontSize: 16)),
                  onPressed: rides.loading ? null : _submit,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
