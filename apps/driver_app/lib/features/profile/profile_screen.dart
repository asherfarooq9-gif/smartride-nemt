import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartride_core/smartride_core.dart' as core;

final _profileProvider = FutureProvider.autoDispose<core.DriverResponse>(
  (_) => core.getDriverMe(),
);

final _updateProvider =
    StateNotifierProvider.autoDispose<_UpdateNotifier, AsyncValue<void>>(
  (_) => _UpdateNotifier(),
);

class _UpdateNotifier extends StateNotifier<AsyncValue<void>> {
  _UpdateNotifier() : super(const AsyncValue.data(null));

  Future<bool> update(core.DriverUpdate upd) async {
    state = const AsyncValue.loading();
    try {
      await core.updateDriverMe(upd);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _vehicleModelCtrl = TextEditingController();
  final _vehiclePlateCtrl = TextEditingController();
  bool _editing = false;

  void _populate(core.DriverResponse d) {
    _nameCtrl.text = d.fullName ?? '';
    _licenseCtrl.text = d.licenseNumber ?? '';
    _vehicleModelCtrl.text = d.vehicleModel ?? '';
    _vehiclePlateCtrl.text = d.vehiclePlate ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _licenseCtrl.dispose();
    _vehicleModelCtrl.dispose();
    _vehiclePlateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(_profileProvider);
    final isUpdating = ref.watch(_updateProvider) is AsyncLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit profile',
              onPressed: () {
                final p = ref.read(_profileProvider).value;
                if (p != null) _populate(p);
                setState(() => _editing = true);
              },
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const core.LoadingState(),
        error: (e, _) => core.ErrorState(
          message: e is core.AppError ? e.message : 'Failed to load profile',
          onRetry: () => ref.refresh(_profileProvider),
        ),
        data: (driver) => SingleChildScrollView(
          padding: const EdgeInsets.all(core.kSpaceLG),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CircleAvatar(
                  radius: 40,
                  child: Icon(Icons.person, size: 48),
                ),
                const SizedBox(height: core.kSpaceSM),
                Text(driver.phone, textAlign: TextAlign.center),
                const SizedBox(height: core.kSpaceXL),
                _field(_nameCtrl, 'Full name', Icons.person),
                const SizedBox(height: core.kSpaceLG),
                _field(_licenseCtrl, 'License number', Icons.badge),
                const SizedBox(height: core.kSpaceLG),
                _field(_vehicleModelCtrl, 'Vehicle model', Icons.directions_car),
                const SizedBox(height: core.kSpaceLG),
                _field(_vehiclePlateCtrl, 'Vehicle plate', Icons.confirmation_number),
                if (_editing) ...[
                  const SizedBox(height: core.kSpaceXXL),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _editing = false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: core.kSpaceLG),
                      Expanded(
                        child: core.PrimaryButton(
                          label: 'Save',
                          onPressed: isUpdating ? null : _save,
                          isLoading: isUpdating,
                          height: core.kMinTapTarget,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon) =>
      TextFormField(
        controller: ctrl,
        enabled: _editing,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(_updateProvider.notifier).update(
          core.DriverUpdate(
            fullName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
            licenseNumber:
                _licenseCtrl.text.trim().isEmpty ? null : _licenseCtrl.text.trim(),
            vehicleModel: _vehicleModelCtrl.text.trim().isEmpty
                ? null
                : _vehicleModelCtrl.text.trim(),
            vehiclePlate: _vehiclePlateCtrl.text.trim().isEmpty
                ? null
                : _vehiclePlateCtrl.text.trim(),
          ),
        );
    if (!mounted) return;
    if (ok) {
      setState(() => _editing = false);
      ref.invalidate(_profileProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }
}
