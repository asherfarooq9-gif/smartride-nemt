import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/core/providers.dart';

class SavedPlacesScreen extends ConsumerWidget {
  const SavedPlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(savedPlacesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Places'),
        leading: const BackButton(),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kTeal600,
        foregroundColor: Colors.white,
        onPressed: () => _openSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: places.isEmpty
          ? _EmptyState(onAdd: () => _openSheet(context, ref))
          : ListView.separated(
              padding: const EdgeInsets.all(kSpaceLG),
              itemCount: places.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: kSpaceMD),
              itemBuilder: (context, i) {
                if (i == places.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: kSpaceSM),
                    child: _AddPlaceButton(
                        onTap: () => _openSheet(context, ref)),
                  );
                }
                return _PlaceCard(
                  place: places[i],
                  onEdit: () =>
                      _openSheet(context, ref, existing: places[i]),
                  onDelete: () => _confirmDelete(context, ref, places[i]),
                );
              },
            ),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref,
      {SavedPlace? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
      ),
      builder: (_) => _PlaceSheet(
        existing: existing,
        onSave: (place) {
          if (existing != null) {
            ref.read(savedPlacesProvider.notifier).update(place);
          } else {
            ref.read(savedPlacesProvider.notifier).add(place);
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, SavedPlace place) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove place'),
        content: Text('Remove "${place.label}" from saved places?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: kError),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(savedPlacesProvider.notifier).remove(place.id);
    }
  }
}

// ── Place card ─────────────────────────────────────────────────────────────────

class _PlaceCard extends StatelessWidget {
  const _PlaceCard(
      {required this.place, required this.onEdit, required this.onDelete});

  final SavedPlace place;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusXL),
        border: Border.all(color: kBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: kSpaceLG, vertical: kSpaceSM),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: kTeal600.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(kRadiusMD),
          ),
          child: Icon(place.icon, color: kTeal600, size: 22),
        ),
        title: Text(
          place.label,
          style: const TextStyle(
            fontSize: kFontBody,
            fontWeight: FontWeight.w700,
            color: kText900,
          ),
        ),
        subtitle: Text(
          place.address,
          style: const TextStyle(fontSize: kFontSmall, color: kText600),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: kText400),
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: kError)),
            ),
          ],
        ),
        minVerticalPadding: 0,
      ),
    );
  }
}

// ── Add place button ───────────────────────────────────────────────────────────

class _AddPlaceButton extends StatelessWidget {
  const _AddPlaceButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: kMinTapTarget,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kRadiusLG),
          border: Border.all(color: kBorder),
        ),
        child: const Center(
          child: Text(
            '＋  Add a place',
            style: TextStyle(
              fontSize: kFontSmall,
              fontWeight: FontWeight.w600,
              color: kTeal600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place_outlined, size: 64, color: kText400),
          const SizedBox(height: kSpaceLG),
          const Text('No saved places yet',
              style: TextStyle(fontSize: kFontBody, color: kText600)),
          const SizedBox(height: kSpaceSM),
          TextButton(
            onPressed: onAdd,
            child: const Text('Add your first place',
                style: TextStyle(
                    color: kTeal600, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Add / edit bottom sheet ────────────────────────────────────────────────────

class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet({this.existing, required this.onSave});

  final SavedPlace? existing;
  final void Function(SavedPlace) onSave;

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _iconType = 'place';

  static const _iconOptions = [
    ('home', 'Home', Icons.home_outlined),
    ('work', 'Work', Icons.work_outline),
    ('hospital', 'Hospital', Icons.local_hospital_outlined),
    ('place', 'Other', Icons.place_outlined),
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _labelCtrl.text = p.label;
      _addressCtrl.text = p.address;
      _iconType = p.iconType;
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSave(SavedPlace(
      id: widget.existing?.id ??
          '${DateTime.now().millisecondsSinceEpoch}',
      label: _labelCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      iconType: _iconType,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          kSpaceLG, kSpaceLG, kSpaceLG, kSpaceLG + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: kSpaceLG),
            Text(
              isEdit ? 'Edit Place' : 'Add Place',
              style: const TextStyle(
                fontSize: kFontSubhead,
                fontWeight: FontWeight.w700,
                color: kText900,
              ),
            ),
            const SizedBox(height: kSpaceLG),
            Wrap(
              spacing: kSpaceSM,
              runSpacing: kSpaceSM,
              children: [
                for (final (type, lbl, icon) in _iconOptions)
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            size: 15,
                            color: _iconType == type
                                ? kTeal600
                                : kText600),
                        const SizedBox(width: 4),
                        Text(lbl),
                      ],
                    ),
                    selected: _iconType == type,
                    selectedColor: kTeal600.withValues(alpha: 0.12),
                    onSelected: (_) => setState(() => _iconType = type),
                  ),
              ],
            ),
            const SizedBox(height: kSpaceLG),
            TextFormField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Label',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: kSpaceMD),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: kSpaceXL),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: kSpaceMD),
                Expanded(
                  child: PrimaryButton(
                    label: isEdit ? 'Save' : 'Add',
                    onPressed: _submit,
                    height: kMinTapTarget,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
