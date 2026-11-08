import 'package:patient_app/shared/apple_alert.dart';
import 'package:patient_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/shared/apple_list.dart';

class SavedPlacesScreen extends ConsumerWidget {
  const SavedPlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(savedPlacesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.savedPlaces),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: context.l10n.addPlaceBtn,
            onPressed: () => _openSheet(context, ref),
          ),
        ],
      ),
      body: places.isEmpty
          ? _EmptyState(onAdd: () => _openSheet(context, ref))
          : ListView(
              padding: const EdgeInsets.only(bottom: kSpaceXXL),
              children: [
                AppleSection(
                  dividerIndent: appleIconDividerIndent,
                  children: [
                    for (final place in places)
                      _PlaceRow(
                        place: place,
                        onEdit: () => _openSheet(context, ref, existing: place),
                        onDelete: () => _confirmDelete(context, ref, place),
                      ),
                    _AddPlaceRow(onTap: () => _openSheet(context, ref)),
                  ],
                ),
              ],
            ),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref,
      {SavedPlace? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
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
      builder: (_) => AppleAlertDialog(
        title: Text(context.l10n.removePlace),
        content: Text('Remove "${place.label}" from saved places?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: kError),
            child: Text(context.l10n.remove),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(savedPlacesProvider.notifier).remove(place.id);
    }
  }
}

// -- Place row --------------------------------------------------------------

class _PlaceRow extends StatelessWidget {
  const _PlaceRow(
      {required this.place, required this.onEdit, required this.onDelete});

  final SavedPlace place;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hint = isDark ? kDarkText3 : kText400;
    return AppleRow(
      icon: place.icon,
      title: place.label,
      subtitle: place.address,
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_horiz, color: hint),
        onSelected: (value) {
          if (value == 'edit') onEdit();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'edit', child: Text(context.l10n.edit)),
          PopupMenuItem(
            value: 'delete',
            child: Text(
              context.l10n.delete,
              style: TextStyle(color: isDark ? kDarkRed : kError),
            ),
          ),
        ],
      ),
      onTap: onEdit,
    );
  }
}

// -- Add place row ----------------------------------------------------------

class _AddPlaceRow extends StatelessWidget {
  const _AddPlaceRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final link =
        scheme.brightness == Brightness.dark ? kDarkAccent : scheme.primary;
    return ListTile(
      minTileHeight: 48,
      contentPadding: const EdgeInsets.symmetric(horizontal: kSpaceLG),
      leading: Icon(Icons.add_circle, color: link, size: 30),
      horizontalTitleGap: kSpaceMD,
      title: Text(
        context.l10n.addPlaceBtn,
        style: TextStyle(fontSize: kFontBody, color: link),
      ),
      onTap: onTap,
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
          Icon(Icons.place_outlined,
              size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: kSpaceLG),
          Text(context.l10n.noSavedPlaces,
              style: TextStyle(
                  fontSize: kFontBody,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: kSpaceSM),
          TextButton(
            onPressed: onAdd,
            child: Text(context.l10n.addFirstPlace,
                style: const TextStyle(fontWeight: FontWeight.w600)),
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

  List<(String, String, IconData)> _iconOptions(AppLocalizations l) => [
        ('home', l.placeHome, Icons.home_outlined),
        ('work', l.placeWork, Icons.work_outline),
        ('hospital', l.placeHospital, Icons.local_hospital_outlined),
        ('place', l.placeOther, Icons.place_outlined),
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
      id: widget.existing?.id ?? '${DateTime.now().millisecondsSinceEpoch}',
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
            Text(
              isEdit ? context.l10n.editPlace : context.l10n.addPlace,
              style: TextStyle(
                fontSize: kFontSubhead,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: kSpaceLG),
            Wrap(
              spacing: kSpaceSM,
              runSpacing: kSpaceSM,
              children: [
                for (final (type, lbl, icon) in _iconOptions(context.l10n))
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            size: 15,
                            color: _iconType == type
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(lbl),
                      ],
                    ),
                    selected: _iconType == type,
                    selectedColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    onSelected: (_) => setState(() => _iconType = type),
                  ),
              ],
            ),
            const SizedBox(height: kSpaceLG),
            TextFormField(
              controller: _labelCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.labelField,
                prefixIcon: const Icon(Icons.label_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.l10n.required
                  : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: kSpaceMD),
            TextFormField(
              controller: _addressCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.addressField,
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.l10n.required
                  : null,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: kSpaceXL),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.cancel),
                  ),
                ),
                const SizedBox(width: kSpaceMD),
                Expanded(
                  child: PrimaryButton(
                    label: isEdit ? context.l10n.save : 'Add',
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
