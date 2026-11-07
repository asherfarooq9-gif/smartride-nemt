import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/l10n/l10n.dart';
import 'package:patient_app/core/payment_methods.dart';

final driverProfileProvider = FutureProvider.autoDispose<core.DriverResponse>(
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

class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  ConsumerState<DriverProfileScreen> createState() =>
      _DriverProfileScreenState();
}

class _DriverProfileScreenState extends ConsumerState<DriverProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _vehicleModelCtrl = TextEditingController();
  final _vehiclePlateCtrl = TextEditingController();
  bool _editing = false;
  List<String> _methods = [];

  void _populate(core.DriverResponse d) {
    _methods = [...d.paymentMethods];
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
    final profileAsync = ref.watch(driverProfileProvider);
    final isUpdating = ref.watch(_updateProvider) is AsyncLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.navProfile),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: context.l10n.editProfile,
              onPressed: () {
                final p = ref.read(driverProfileProvider).value;
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
          onRetry: () => ref.invalidate(driverProfileProvider),
        ),
        data: (driver) {
          // Show the saved values while reading; editing keeps the user's typing.
          if (!_editing) _populate(driver);
          return _buildBody(driver, isUpdating);
        },
      ),
    );
  }

  Widget _buildBody(core.DriverResponse driver, bool isUpdating) {
    return SingleChildScrollView(
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
            _field(
                _vehiclePlateCtrl, 'Vehicle plate', Icons.confirmation_number),
            const SizedBox(height: core.kSpaceXL),
            _paymentMethods(driver),
            if (!_editing) ...[
              const SizedBox(height: core.kSpaceXL),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(context.l10n.tripHistory),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/driver/history'),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(context.l10n.walletTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/driver/wallet'),
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart_outlined),
                title: Text(context.l10n.earnings),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/driver/earnings'),
              ),
              const Divider(),
            ],
            if (_editing) ...[
              const SizedBox(height: core.kSpaceXXL),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _editing = false),
                      child: Text(context.l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: core.kSpaceLG),
                  Expanded(
                    child: core.PrimaryButton(
                      label: context.l10n.save,
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
    );
  }

  /// How this driver says they take payment. Editable only in edit mode.
  Widget _paymentMethods(core.DriverResponse driver) {
    final l = context.l10n;
    final chosen = driver.paymentMethods;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.paymentSectionTitle,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: core.kSpaceXS),
        Text(
          l.paymentSectionHint,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: core.kTextSecondary),
        ),
        const SizedBox(height: core.kSpaceSM),
        if (!_editing)
          // Reading: show only what the driver accepts, as plain labels.
          chosen.isEmpty
              ? Text(l.paymentNotSet,
                  style: const TextStyle(color: core.kTextSecondary))
              : Wrap(
                  spacing: core.kSpaceSM,
                  runSpacing: core.kSpaceSM,
                  children: [
                    for (final id in chosen)
                      Chip(label: Text(paymentMethodLabel(l, id))),
                  ],
                )
        else
          Wrap(
            spacing: core.kSpaceSM,
            runSpacing: core.kSpaceSM,
            children: [
              for (final id in paymentMethodIds)
                FilterChip(
                  label: Text(paymentMethodLabel(l, id)),
                  selected: _methods.contains(id),
                  onSelected: (on) => setState(() {
                    _methods = [
                      for (final other in paymentMethodIds)
                        if (other == id ? on : _methods.contains(other)) other,
                    ];
                  }),
                ),
            ],
          ),
      ],
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
            fullName:
                _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
            licenseNumber: _licenseCtrl.text.trim().isEmpty
                ? null
                : _licenseCtrl.text.trim(),
            vehicleModel: _vehicleModelCtrl.text.trim().isEmpty
                ? null
                : _vehicleModelCtrl.text.trim(),
            vehiclePlate: _vehiclePlateCtrl.text.trim().isEmpty
                ? null
                : _vehiclePlateCtrl.text.trim(),
            paymentMethods: _methods,
          ),
        );
    if (!mounted) return;
    if (ok) {
      setState(() => _editing = false);
      ref.invalidate(driverProfileProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.profileUpdated)));
    }
  }
}
