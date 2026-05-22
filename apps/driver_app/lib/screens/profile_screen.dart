import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../core/theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editing = false;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _vehiclePlateCtrl;
  late final TextEditingController _vehicleTypeCtrl;
  late final TextEditingController _licenseCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _vehiclePlateCtrl = TextEditingController();
    _vehicleTypeCtrl = TextEditingController();
    _licenseCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(driverProfileProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _vehiclePlateCtrl.dispose();
    _vehicleTypeCtrl.dispose();
    _licenseCtrl.dispose();
    super.dispose();
  }

  void _startEdit(Map<String, dynamic> data) {
    _nameCtrl.text = data['full_name'] as String? ?? '';
    _vehiclePlateCtrl.text = data['vehicle_plate'] as String? ?? '';
    _vehicleTypeCtrl.text = data['vehicle_type'] as String? ?? '';
    _licenseCtrl.text = data['license_number'] as String? ?? '';
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(driverProfileProvider.notifier).update({
      'full_name': _nameCtrl.text.trim(),
      'vehicle_plate': _vehiclePlateCtrl.text.trim(),
      'vehicle_type': _vehicleTypeCtrl.text.trim(),
      'license_number': _licenseCtrl.text.trim(),
    });
    if (!mounted) return;
    if (ok) {
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated'), backgroundColor: kGreen),
      );
    } else {
      final err = ref.read(driverProfileProvider).error ?? 'Update failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: kRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(driverProfileProvider);
    final data = profile.data;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Profile'),
        actions: [
          if (!_editing && data != null)
            TextButton.icon(
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit'),
              onPressed: () => _startEdit(data),
            ),
          if (_editing)
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: const Text('Cancel'),
            ),
        ],
      ),
      body: profile.loading
          ? const Center(child: CircularProgressIndicator())
          : data == null
              ? _ErrorState(error: profile.error, onRetry: () => ref.read(driverProfileProvider.notifier).load())
              : _editing
                  ? _EditForm(
                      formKey: _formKey,
                      nameCtrl: _nameCtrl,
                      vehiclePlateCtrl: _vehiclePlateCtrl,
                      vehicleTypeCtrl: _vehicleTypeCtrl,
                      licenseCtrl: _licenseCtrl,
                      onSave: _save,
                    )
                  : _ProfileView(data: data),
    );
  }
}

class _ProfileView extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ProfileView({required this.data});

  @override
  Widget build(BuildContext context) {
    final isVerified = data['is_verified'] as bool? ?? false;
    final initial = (data['full_name'] as String? ?? 'D')[0].toUpperCase();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Avatar + verification
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: kGreen.withValues(alpha: 0.15),
                child: Text(initial, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: kGreen)),
              ),
              const SizedBox(height: 12),
              Text(
                data['full_name'] as String? ?? '—',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isVerified ? kGreen.withValues(alpha: 0.1) : kAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isVerified ? kGreen.withValues(alpha: 0.3) : kAmber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isVerified ? Icons.verified_rounded : Icons.pending_rounded,
                        size: 14, color: isVerified ? kGreen : kAmber),
                    const SizedBox(width: 6),
                    Text(
                      isVerified ? 'Verified Driver' : 'Pending Verification',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isVerified ? kGreen : kAmber),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _InfoCard(title: 'Personal Info', children: [
          _InfoRow(icon: Icons.phone_rounded, label: 'Phone', value: data['phone'] as String? ?? '—'),
          _InfoRow(icon: Icons.badge_rounded, label: 'License No.', value: data['license_number'] as String? ?? '—'),
        ]),
        const SizedBox(height: 12),

        _InfoCard(title: 'Vehicle Info', children: [
          _InfoRow(icon: Icons.directions_car_rounded, label: 'Type', value: (data['vehicle_type'] as String? ?? '—').replaceAll('_', ' ').toUpperCase()),
          _InfoRow(icon: Icons.confirmation_number_rounded, label: 'Plate', value: data['vehicle_plate'] as String? ?? '—'),
        ]),
        const SizedBox(height: 12),

        _InfoCard(title: 'Stats', children: [
          _InfoRow(icon: Icons.star_rounded, label: 'Rating', value: data['rating'] != null ? '${(data['rating'] as num).toStringAsFixed(1)} / 5.0' : 'No ratings yet'),
          _InfoRow(icon: Icons.calendar_today_rounded, label: 'Joined', value: _formatDate(data['created_at'] as String?)),
        ]),
      ],
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
          ),
          const SizedBox(height: 8),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController vehiclePlateCtrl;
  final TextEditingController vehicleTypeCtrl;
  final TextEditingController licenseCtrl;
  final VoidCallback onSave;

  const _EditForm({
    required this.formKey,
    required this.nameCtrl,
    required this.vehiclePlateCtrl,
    required this.vehicleTypeCtrl,
    required this.licenseCtrl,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            _field(nameCtrl, 'Full Name', Icons.person_rounded, required: true),
            const SizedBox(height: 12),
            _field(licenseCtrl, 'License Number', Icons.badge_rounded, required: true),
            const SizedBox(height: 12),
            _field(vehiclePlateCtrl, 'Vehicle Plate', Icons.confirmation_number_rounded, required: true),
            const SizedBox(height: 12),
            _field(vehicleTypeCtrl, 'Vehicle Type', Icons.directions_car_rounded),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save Changes'),
                onPressed: onSave,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {bool required = false}) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;
  const _ErrorState({this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(error ?? 'Failed to load profile', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
