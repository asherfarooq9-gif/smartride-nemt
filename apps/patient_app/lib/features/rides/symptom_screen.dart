import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;

const _quickSymptoms = [
  'Chest pain',
  'Difficulty breathing',
  'Severe abdominal pain',
  'Head injury',
  'Loss of consciousness',
  'Stroke symptoms',
  'Allergic reaction',
  'Severe bleeding',
];

final _submitProvider =
    StateNotifierProvider.autoDispose<_SubmitNotifier, AsyncValue<void>>(
  (_) => _SubmitNotifier(),
);

class _SubmitNotifier extends StateNotifier<AsyncValue<void>> {
  _SubmitNotifier() : super(const AsyncValue.data(null));

  Future<String?> submit({
    required String address,
    required String symptoms,
    double? lat,
    double? lng,
  }) async {
    state = const AsyncValue.loading();
    try {
      final ride = await core.createEmergencyRide(
        core.EmergencyRideRequest(
          pickupAddress: address,
          symptomText: symptoms,
          pickupLat: lat,
          pickupLng: lng,
        ),
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
  final _symptomCtrl = TextEditingController();
  final Set<String> _selected = {};

  @override
  void dispose() {
    _addressCtrl.dispose();
    _symptomCtrl.dispose();
    super.dispose();
  }

  void _toggleChip(String s) {
    setState(() {
      if (_selected.contains(s)) {
        _selected.remove(s);
      } else {
        _selected.add(s);
      }
      _symptomCtrl.text = _selected.join(', ');
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final rideId = await ref.read(_submitProvider.notifier).submit(
          address: _addressCtrl.text.trim(),
          symptoms: _symptomCtrl.text.trim(),
        );
    if (!mounted) return;
    if (rideId != null) {
      context.go('/tracking/$rideId');
    } else {
      final err = ref.read(_submitProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              err is core.AppError ? err.message : 'Failed to request ride'),
          backgroundColor: core.kError,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(_submitProvider) is AsyncLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Ride')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(core.kSpaceLG),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select symptoms',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: core.kSpaceSM),
              Wrap(
                spacing: core.kSpaceSM,
                runSpacing: core.kSpaceXS,
                children: _quickSymptoms
                    .map(
                      (s) => FilterChip(
                        label: Text(s),
                        selected: _selected.contains(s),
                        onSelected: (_) => _toggleChip(s),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: core.kSpaceLG),
              TextFormField(
                controller: _symptomCtrl,
                maxLines: 3,
                maxLength: 2000,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Describe symptoms',
                  alignLabelWithHint: true,
                  hintText: 'Additional details...',
                ),
                validator: core.Validators.symptomText,
              ),
              const SizedBox(height: core.kSpaceLG),
              TextFormField(
                controller: _addressCtrl,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Pickup address',
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (v) =>
                    core.Validators.required(v, field: 'Pickup address'),
              ),
              const SizedBox(height: core.kSpaceXXL),
              core.PrimaryButton(
                label: 'Request Emergency Ride',
                onPressed: isLoading ? null : _submit,
                isLoading: isLoading,
                color: core.kEmergencyRed,
                height: core.kEmergencyButtonHeight,
                semanticLabel: 'Request emergency ride with entered symptoms',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
