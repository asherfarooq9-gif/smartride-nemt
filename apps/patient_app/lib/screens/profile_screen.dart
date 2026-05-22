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
  final _nameCtrl = TextEditingController();
  final _mobCtrl = TextEditingController();
  final _ecNameCtrl = TextEditingController();
  final _ecPhoneCtrl = TextEditingController();
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(profileProvider.notifier).load();
      _populateFields();
    });
  }

  void _populateFields() {
    final data = ref.read(profileProvider).data;
    if (data == null) return;
    _nameCtrl.text = data['full_name'] ?? '';
    _mobCtrl.text = data['mobility_needs'] ?? '';
    _ecNameCtrl.text = data['emergency_contact_name'] ?? '';
    _ecPhoneCtrl.text = data['emergency_contact_phone'] ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _mobCtrl.dispose(); _ecNameCtrl.dispose(); _ecPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    setState(() => _saving = true);
    final ok = await ref.read(profileProvider.notifier).update({
      'full_name': _nameCtrl.text.trim(),
      if (_mobCtrl.text.trim().isNotEmpty) 'mobility_needs': _mobCtrl.text.trim(),
      if (_ecNameCtrl.text.trim().isNotEmpty) 'emergency_contact_name': _ecNameCtrl.text.trim(),
      if (_ecPhoneCtrl.text.trim().isNotEmpty) 'emergency_contact_phone': _ecPhoneCtrl.text.trim(),
    });
    if (!mounted) return;
    setState(() { _saving = false; _editing = false; });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Profile updated' : 'Update failed'), backgroundColor: ok ? kGreen : kRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final data = profile.data;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_editing)
            TextButton(onPressed: () { setState(() => _editing = true); _populateFields(); }, child: const Text('Edit')),
          if (_editing)
            TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel')),
        ],
      ),
      body: profile.loading
          ? const Center(child: CircularProgressIndicator())
          : data == null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Failed to load profile'),
                  TextButton(onPressed: () => ref.read(profileProvider.notifier).load(), child: const Text('Retry')),
                ]))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Avatar
                    Center(
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: kBlue.withValues(alpha: 0.12),
                        child: Text(
                          (data['full_name'] as String? ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: kBlue, fontWeight: FontWeight.bold, fontSize: 32),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(child: Text(data['phone'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 14))),
                    const SizedBox(height: 24),

                    if (!_editing) ...[
                      _InfoCard(title: 'Personal Information', items: [
                        _InfoRow(label: 'Full Name', value: data['full_name'] ?? '—'),
                        _InfoRow(label: 'Phone', value: data['phone'] ?? '—'),
                        if (data['mobility_needs'] != null)
                          _InfoRow(label: 'Mobility Needs', value: data['mobility_needs']),
                      ]),
                      const SizedBox(height: 16),
                      _InfoCard(title: 'Emergency Contact', items: [
                        _InfoRow(label: 'Name', value: data['emergency_contact_name'] ?? '—'),
                        _InfoRow(label: 'Phone', value: data['emergency_contact_phone'] ?? '—'),
                      ]),
                      const SizedBox(height: 16),
                      _InfoCard(title: 'Account', items: [
                        _InfoRow(label: 'Total Rides', value: '${data['total_rides'] ?? 0}'),
                        _InfoRow(label: 'Member Since', value: data['created_at'] != null ? DateTime.parse(data['created_at']).toLocal().toString().split(' ')[0] : '—'),
                      ]),
                    ] else ...[
                      _SectionTitle('Personal Information'),
                      const SizedBox(height: 12),
                      TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
                      const SizedBox(height: 12),
                      TextFormField(controller: _mobCtrl, decoration: const InputDecoration(labelText: 'Mobility Needs (optional)'), maxLines: 2),
                      const SizedBox(height: 20),
                      _SectionTitle('Emergency Contact'),
                      const SizedBox(height: 12),
                      TextFormField(controller: _ecNameCtrl, decoration: const InputDecoration(labelText: 'Contact Name')),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ecPhoneCtrl,
                        decoration: const InputDecoration(labelText: 'Contact Phone'),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Changes'),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey));
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const _InfoCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
          ),
          const Divider(height: 1),
          ...items,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}
