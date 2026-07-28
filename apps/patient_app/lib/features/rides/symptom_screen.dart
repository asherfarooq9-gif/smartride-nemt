import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/location.dart';
import 'package:smartride_core/smartride_core.dart' as core;

const _symptoms = [
  'Chest Pain',
  'Breathing Trouble',
  'Pregnancy',
  'Injury / Accident',
  'Child Sick',
  'Other / Not Sure',
];

final symptomSubmitProvider =
    StateNotifierProvider.autoDispose<SymptomSubmitNotifier, AsyncValue<void>>(
  (_) => SymptomSubmitNotifier(),
);

class SymptomSubmitNotifier extends StateNotifier<AsyncValue<void>> {
  SymptomSubmitNotifier() : super(const AsyncValue.data(null));

  Future<String?> submit({
    required String address,
    required String symptoms,
  }) async {
    state = const AsyncValue.loading();

    final position = await getCurrentPositionSafe();
    if (position == null) {
      state = AsyncValue.error(
        const core.AppError(
          'Location access is required to request emergency help. Please '
          'enable location permission and try again, or call 1122 directly.',
        ),
        StackTrace.current,
      );
      return null;
    }

    try {
      final ride = await core.createEmergencyRide(
        core.EmergencyRideRequest(
          pickupAddress: address,
          symptomText: symptoms,
          pickupLat: position.latitude,
          pickupLng: position.longitude,
        ),
        idempotencyKey: core.generateIdempotencyKey(),
      );
      state = const AsyncValue.data(null);
      return ride.id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

class SymptomScreen extends ConsumerStatefulWidget {
  const SymptomScreen({super.key});

  @override
  ConsumerState<SymptomScreen> createState() => _SymptomScreenState();
}

class _SymptomScreenState extends ConsumerState<SymptomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final Set<String> _selected = {};

  @override
  void dispose() {
    _addressCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  void _toggle(String s) =>
      setState(() => _selected.contains(s) ? _selected.remove(s) : _selected.add(s));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final symptomText = _selected.isEmpty
        ? _detailsCtrl.text.trim()
        : [_selected.join(', '), if (_detailsCtrl.text.trim().isNotEmpty) _detailsCtrl.text.trim()].join('. ');

    final rideId = await ref.read(symptomSubmitProvider.notifier).submit(
          address: _addressCtrl.text.trim().isEmpty ? 'Current location' : _addressCtrl.text.trim(),
          symptoms: symptomText,
        );
    if (!mounted) return;
    if (rideId != null) {
      context.go('/dispatching/$rideId');
    } else {
      final err = ref.read(symptomSubmitProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err is core.AppError ? err.message : 'Failed to request ride'),
        backgroundColor: core.kError,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(symptomSubmitProvider) is AsyncLoading;

    return Scaffold(
      backgroundColor: core.kEmergencyDarkBg,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    core.kSpaceLG, core.kSpaceMD, core.kSpaceLG, 0),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.close,
                          size: 18, color: Colors.white54),
                      label: const Text('Cancel',
                          style: TextStyle(color: Colors.white54)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(core.kSpaceLG),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Get Help Now',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: core.kSpaceXS),
                      const Text(
                        'Help is being arranged. Tell us what\'s happening so we can send the right support.',
                        style: TextStyle(
                            fontSize: core.kFontSM,
                            color: Colors.white54,
                            height: 1.4),
                      ),
                      const SizedBox(height: core.kSpaceXL),
                      const Text(
                        "WHAT'S HAPPENING?",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white38,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: core.kSpaceMD),
                      Wrap(
                        spacing: core.kSpaceSM,
                        runSpacing: core.kSpaceSM,
                        children: _symptoms
                            .map((s) => _SymptomChip(
                                  label: s,
                                  selected: _selected.contains(s),
                                  onTap: () => _toggle(s),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: core.kSpaceXL),
                      const Text(
                        'ANY OTHER DETAILS? (OPTIONAL)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white38,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: core.kSpaceMD),
                      TextFormField(
                        controller: _detailsCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText:
                              'e.g. patient is conscious, address details...',
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: const Color(0xFF2D1010),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(core.kRadiusMD),
                            borderSide: const BorderSide(
                                color: Color(0xFF5A2020)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(core.kRadiusMD),
                            borderSide: const BorderSide(
                                color: Color(0xFF5A2020)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(core.kRadiusMD),
                            borderSide: const BorderSide(
                                color: core.kEmergencyRed, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: core.kSpaceLG),
                      // Pickup address (hidden field — auto-uses current location)
                      TextFormField(
                        controller: _addressCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Pickup address (leave blank for current location)',
                          hintStyle: const TextStyle(color: Colors.white24),
                          prefixIcon: const Icon(Icons.location_on, color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF2D1010),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(core.kRadiusMD),
                            borderSide: const BorderSide(color: Color(0xFF5A2020)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(core.kRadiusMD),
                            borderSide: const BorderSide(color: Color(0xFF5A2020)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(core.kRadiusMD),
                            borderSide: const BorderSide(color: core.kEmergencyRed, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    core.kSpaceLG, 0, core.kSpaceLG, core.kSpaceLG),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: core.kMinTapTarget + 8,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: core.kEmergencyRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(core.kRadiusLG),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Send for Help',
                                style: TextStyle(
                                  fontSize: core.kFontMD,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: core.kSpaceMD),
                    const Text(
                      'Or call directly: 1122',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white54, fontSize: core.kFontSM),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SymptomChip extends StatelessWidget {
  const _SymptomChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: core.kSpaceLG, vertical: core.kSpaceMD),
        decoration: BoxDecoration(
          color: selected ? core.kEmergencyRed : const Color(0xFF2D1010),
          borderRadius: BorderRadius.circular(core.kRadiusLG),
          border: Border.all(
            color: selected ? core.kEmergencyRed : const Color(0xFF5A2020),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: core.kFontSM,
          ),
        ),
      ),
    );
  }
}
