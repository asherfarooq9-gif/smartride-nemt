import 'package:patient_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;

final _profileProvider = FutureProvider.autoDispose<core.PatientResponse>(
  (_) => core.getPatientMe(),
);

final _updateProvider =
    StateNotifierProvider.autoDispose<_UpdateNotifier, AsyncValue<void>>(
  (_) => _UpdateNotifier(),
);

class _UpdateNotifier extends StateNotifier<AsyncValue<void>> {
  _UpdateNotifier() : super(const AsyncValue.data(null));

  Future<bool> update(core.PatientUpdate upd) async {
    state = const AsyncValue.loading();
    try {
      await core.updatePatientMe(upd);
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
  final _dobCtrl = TextEditingController();
  final _mobilityCtrl = TextEditingController();
  final _ecNameCtrl = TextEditingController();
  final _ecPhoneCtrl = TextEditingController();
  bool _editing = false;
  DateTime? _dobDate;

  void _populate(core.PatientResponse p) {
    _nameCtrl.text = p.fullName ?? '';
    _mobilityCtrl.text = p.mobilityNeeds ?? '';
    _ecNameCtrl.text = p.emergencyContactName ?? '';
    _ecPhoneCtrl.text = p.emergencyContactPhone ?? '';
    final dob = p.dateOfBirth;
    if (dob != null && dob.isNotEmpty) {
      _dobDate = DateTime.tryParse(dob);
      _dobCtrl.text = _dobDate != null ? _formatDob(_dobDate!) : dob;
    } else {
      _dobDate = null;
      _dobCtrl.text = '';
    }
  }

  String _formatDob(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dobDate ?? DateTime(now.year - 30),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: context.l10n.dateOfBirth,
    );
    if (picked != null) {
      setState(() {
        _dobDate = picked;
        _dobCtrl.text = _formatDob(picked);
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dobCtrl.dispose();
    _mobilityCtrl.dispose();
    _ecNameCtrl.dispose();
    _ecPhoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(_profileProvider);
    final isUpdating = ref.watch(_updateProvider) is AsyncLoading;

    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: 2,
        onDestinationSelected: (i) {
          if (i == 0) context.go('/');
          if (i == 1) context.go('/rides');
        },
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: context.l10n.navHome),
          NavigationDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: const Icon(Icons.history),
              label: context.l10n.navMyRides),
          NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: context.l10n.navProfile),
        ],
      ),
      appBar: AppBar(
        title: Text(context.l10n.myProfile),
        actions: [
          if (!_editing)
            TextButton(
              onPressed: () {
                final p = ref.read(_profileProvider).value;
                if (p != null) _populate(p);
                setState(() => _editing = true);
              },
              // White: the default blue text vanished on the blue app bar.
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(context.l10n.edit),
            )
          else
            TextButton(
              onPressed: () => setState(() => _editing = false),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(context.l10n.cancel),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const core.LoadingState(),
        error: (e, _) => core.ErrorState(
          message:
              e is core.AppError ? e.message : context.l10n.failedLoadProfile,
          onRetry: () => ref.refresh(_profileProvider),
        ),
        data: (profile) => SingleChildScrollView(
          padding: const EdgeInsets.all(core.kSpaceLG),
          child: _editing
              ? _EditForm(
                  formKey: _formKey,
                  nameCtrl: _nameCtrl,
                  dobCtrl: _dobCtrl,
                  mobilityCtrl: _mobilityCtrl,
                  ecNameCtrl: _ecNameCtrl,
                  ecPhoneCtrl: _ecPhoneCtrl,
                  isUpdating: isUpdating,
                  onPickDate: _pickDate,
                  onSave: () => _save(),
                  onCancel: () => setState(() => _editing = false),
                )
              : _ViewMode(profile: profile),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(_updateProvider.notifier).update(
          core.PatientUpdate(
            fullName:
                _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
            dateOfBirth: _dobDate != null
                ? '${_dobDate!.year}-${_dobDate!.month.toString().padLeft(2, '0')}-${_dobDate!.day.toString().padLeft(2, '0')}'
                : null,
            mobilityNeeds: _mobilityCtrl.text.trim().isEmpty
                ? null
                : _mobilityCtrl.text.trim(),
            emergencyContactName: _ecNameCtrl.text.trim().isEmpty
                ? null
                : _ecNameCtrl.text.trim(),
            emergencyContactPhone: _ecPhoneCtrl.text.trim().isEmpty
                ? null
                : _ecPhoneCtrl.text.trim(),
          ),
        );
    if (!mounted) return;
    if (ok) {
      setState(() => _editing = false);
      ref.invalidate(_profileProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.profileUpdated)));
    } else {
      final err = ref.read(_updateProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            err is core.AppError ? err.message : context.l10n.updateFailed),
        backgroundColor: core.kError,
      ));
    }
  }
}

// ── View mode ─────────────────────────────────────────────────────────────────

class _ViewMode extends StatelessWidget {
  final core.PatientResponse profile;
  const _ViewMode({required this.profile});

  @override
  Widget build(BuildContext context) {
    final initial =
        (profile.fullName?.isNotEmpty == true ? profile.fullName! : 'U')[0]
            .toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: core.kPatientPrimary.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: const TextStyle(
                color: core.kPatientPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: core.kSpaceXS),
        Text(
          profile.phone,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: core.kTextSecondary),
        ),
        const SizedBox(height: core.kSpaceXL),
        _InfoCard(title: context.l10n.personalInfo, rows: [
          _InfoRow(
              label: context.l10n.fullNameTitle,
              value: profile.fullName ?? '—'),
          _InfoRow(label: context.l10n.phoneTitle, value: profile.phone),
          if (profile.dateOfBirth != null)
            _InfoRow(
                label: context.l10n.dateOfBirth, value: profile.dateOfBirth!),
          if (profile.mobilityNeeds != null)
            _InfoRow(
                label: context.l10n.mobilityNeeds,
                value: profile.mobilityNeeds!),
        ]),
        const SizedBox(height: core.kSpaceLG),
        _InfoCard(title: context.l10n.emergencyContact, rows: [
          _InfoRow(
              label: context.l10n.nameTitle,
              value: profile.emergencyContactName ?? '—'),
          _InfoRow(
              label: context.l10n.phoneTitle,
              value: profile.emergencyContactPhone ?? '—'),
        ]),
        const SizedBox(height: core.kSpaceLG),
        const _QuickLinksCard(),
      ],
    );
  }
}

class _QuickLinksCard extends StatelessWidget {
  const _QuickLinksCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              context.l10n.quickLinks,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: core.kTextSecondary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const Divider(height: 1),
          _NavRow(
            icon: Icons.notifications_outlined,
            label: context.l10n.notificationsTitle,
            onTap: () => context.push('/notifications'),
          ),
          const Divider(height: 1),
          _NavRow(
            icon: Icons.place_outlined,
            label: context.l10n.savedPlaces,
            onTap: () => context.push('/saved-places'),
          ),
          const Divider(height: 1),
          _NavRow(
            icon: Icons.settings_outlined,
            label: context.l10n.settingsTitle,
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: core.kMinTapTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: core.kSpaceMD,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: core.kTextSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: core.kTextSecondary),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: core.kTextSecondary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const Divider(height: 1),
          ...rows,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: core.kTextSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Edit form ─────────────────────────────────────────────────────────────────

class _EditForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl,
      dobCtrl,
      mobilityCtrl,
      ecNameCtrl,
      ecPhoneCtrl;
  final bool isUpdating;
  final VoidCallback onPickDate;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _EditForm({
    required this.formKey,
    required this.nameCtrl,
    required this.dobCtrl,
    required this.mobilityCtrl,
    required this.ecNameCtrl,
    required this.ecPhoneCtrl,
    required this.isUpdating,
    required this.onPickDate,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: nameCtrl,
            decoration: InputDecoration(
                labelText: context.l10n.fullNameTitle,
                prefixIcon: const Icon(Icons.person)),
            validator: (v) => core.Validators.required(v, field: 'Full name'),
          ),
          const SizedBox(height: core.kSpaceLG),
          TextFormField(
            controller: dobCtrl,
            readOnly: true,
            onTap: onPickDate,
            decoration: InputDecoration(
              labelText: context.l10n.dateOfBirth,
              prefixIcon: const Icon(Icons.cake),
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            ),
          ),
          const SizedBox(height: core.kSpaceLG),
          TextFormField(
            controller: mobilityCtrl,
            maxLines: 2,
            decoration: InputDecoration(
                labelText: context.l10n.mobilityNeedsOptional,
                prefixIcon: const Icon(Icons.accessible),
                alignLabelWithHint: true),
          ),
          const SizedBox(height: core.kSpaceXL),
          Text(context.l10n.emergencyContact,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: core.kTextSecondary)),
          const SizedBox(height: core.kSpaceSM),
          TextFormField(
            controller: ecNameCtrl,
            decoration: const InputDecoration(
                labelText: 'Contact Name', prefixIcon: Icon(Icons.contacts)),
          ),
          const SizedBox(height: core.kSpaceLG),
          TextFormField(
            controller: ecPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Contact Phone', prefixIcon: Icon(Icons.phone)),
          ),
          const SizedBox(height: core.kSpaceXXL),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: onCancel, child: Text(context.l10n.cancel)),
              ),
              const SizedBox(width: core.kSpaceLG),
              Expanded(
                child: core.PrimaryButton(
                  label: context.l10n.saveChanges,
                  onPressed: isUpdating ? null : onSave,
                  isLoading: isUpdating,
                  height: core.kMinTapTarget,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
