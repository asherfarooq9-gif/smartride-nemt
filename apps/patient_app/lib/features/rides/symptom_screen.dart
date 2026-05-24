import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import 'rides_notifier.dart';

const _quickSymptoms = [
  'Chest Pain',
  'Difficulty Breathing',
  'Stroke Symptoms',
  'Severe Bleeding',
  'Fall / Injury',
  'Unconscious / Unresponsive',
  'Severe Allergic Reaction',
  'Seizure',
  'High Fever',
  'Severe Abdominal Pain',
];

class SymptomScreen extends ConsumerStatefulWidget {
  final double pickupLat;
  final double pickupLng;
  final String? pickupAddress;

  const SymptomScreen({
    super.key,
    required this.pickupLat,
    required this.pickupLng,
    this.pickupAddress,
  });

  @override
  ConsumerState<SymptomScreen> createState() => _SymptomScreenState();
}

class _SymptomScreenState extends ConsumerState<SymptomScreen> {
  final Set<String> _selected = {};
  final TextEditingController _extraCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _extraCtrl.dispose();
    super.dispose();
  }

  String _buildSymptomText() {
    final parts = <String>[..._selected];
    final extra = _extraCtrl.text.trim();
    if (extra.isNotEmpty) parts.add(extra);
    return parts.isEmpty ? 'Emergency ride requested via app' : parts.join(', ');
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final result = await ApiClient.post('/api/v1/rides/emergency', body: {
        'pickup_lat': widget.pickupLat,
        'pickup_lng': widget.pickupLng,
        if (widget.pickupAddress != null) 'pickup_address': widget.pickupAddress,
        'symptom_text': _buildSymptomText(),
      }) as Map<String, dynamic>;

      if (!mounted) return;
      ref.read(ridesNotifierProvider.notifier).refresh();

      final rideId = result['id'] as String?;
      if (rideId != null) {
        context.go('/ride/$rideId');
      } else {
        context.go('/');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request failed: $e'),
          backgroundColor: Colors.red[700],
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _submit,
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('What\'s happening?'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select all that apply',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D1B3E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickSymptoms.map((symptom) {
                      final selected = _selected.contains(symptom);
                      return Semantics(
                        label: selected
                            ? '$symptom selected'
                            : '$symptom, tap to select',
                        button: true,
                        child: FilterChip(
                          label: Text(symptom),
                          selected: selected,
                          onSelected: (on) => setState(() {
                            if (on) {
                              _selected.add(symptom);
                            } else {
                              _selected.remove(symptom);
                            }
                          }),
                          selectedColor: Colors.red[100],
                          checkmarkColor: Colors.red[700],
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.red[800]
                                : const Color(0xFF0D1B3E),
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Additional details (optional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D1B3E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _extraCtrl,
                    maxLines: 3,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Describe any other symptoms or relevant info…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.orange[800]),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'This information helps dispatch the most appropriate vehicle and hospital.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Semantics(
              label: 'Request emergency ride',
              button: true,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.emergency, size: 22),
                  label: Text(
                    _submitting ? 'Requesting…' : 'Request Emergency Ride',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.red[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
