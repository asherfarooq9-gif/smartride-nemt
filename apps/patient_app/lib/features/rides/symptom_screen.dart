import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/location.dart';
import 'package:patient_app/core/request_id.dart';
import 'package:smartride_core/smartride_core.dart' as core;

const _symptoms = [
  'Chest Pain',
  'Breathing Trouble',
  'Pregnancy',
  'Injury / Accident',
  'Child Sick',
  'Other / Not Sure',
];

const _fieldFill = Color(0xFF2D1010);
const _fieldBorder = Color(0xFF5A2020);
const _emptySymptomsMessage =
    'Tell us what is happening: choose an option or describe it below. '
    'If someone is in immediate danger, call 1122.';

typedef EmergencyRideCreator = Future<core.RideResponse> Function(
  core.EmergencyRideRequest request, {
  String? idempotencyKey,
});

/// Indirection so tests can count submissions without a server.
final emergencyRideCreatorProvider =
    Provider<EmergencyRideCreator>((ref) => core.createEmergencyRide);

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

  bool _isBusy = false;
  bool _hasSymptomError = false;

  // A retry of the same request reuses its key, so a timeout followed by a
  // second tap can never dispatch two ambulances.
  String? _lastPayload;
  String? _lastKey;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  void _toggle(String s) => setState(() {
        _selected.contains(s) ? _selected.remove(s) : _selected.add(s);
        _hasSymptomError = false;
      });

  String get _symptomText {
    final details = _detailsCtrl.text.trim();
    if (_selected.isEmpty) return details;
    return [_selected.join(', '), if (details.isNotEmpty) details].join('. ');
  }

  String _keyFor(String payload) {
    if (payload != _lastPayload) {
      _lastPayload = payload;
      _lastKey = newRequestId();
    }
    return _lastKey!;
  }

  Future<void> _submit() async {
    if (_isBusy) return;
    final symptomText = _symptomText;
    if (symptomText.isEmpty) {
      setState(() => _hasSymptomError = true);
      return;
    }
    setState(() => _isBusy = true); // before any await: blocks a second tap
    try {
      await _requestHelp(symptomText);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _requestHelp(String symptomText) async {
    final position = await ref.read(locationReaderProvider)();
    if (!mounted) return;
    if (position == null) {
      _askForLocation();
      return;
    }
    final address = _addressCtrl.text.trim().isEmpty
        ? 'Current location'
        : _addressCtrl.text.trim();
    final request = core.EmergencyRideRequest(
      pickupAddress: address,
      symptomText: symptomText,
      pickupLat: position.latitude,
      pickupLng: position.longitude,
    );
    try {
      final ride = await ref.read(emergencyRideCreatorProvider)(
        request,
        idempotencyKey: _keyFor('$address|$symptomText'),
      );
      if (mounted) context.go('/dispatching/${ride.id}');
    } on core.AppError catch (e) {
      _showError(e.message);
    } on Exception catch (e, st) {
      core.ErrorReporter.report('Emergency request failed', e, st);
      _showError('We could not send your request. Please try again, '
          'or call 1122.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: core.kError,
    ));
  }

  void _askForLocation() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text(
          'We need your location to send help. Turn on location and try again.'),
      backgroundColor: core.kError,
      action: SnackBarAction(
        label: 'Enable',
        textColor: Colors.white,
        onPressed: () => context.push('/permissions'),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
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
                          size: 18, color: Colors.white70),
                      label: const Text('Cancel',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(core.kSpaceLG),
                  child: _FormBody(
                    selected: _selected,
                    onToggle: _toggle,
                    detailsCtrl: _detailsCtrl,
                    addressCtrl: _addressCtrl,
                    hasSymptomError: _hasSymptomError,
                  ),
                ),
              ),
              _SubmitBar(isBusy: _isBusy, onSubmit: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.selected,
    required this.onToggle,
    required this.detailsCtrl,
    required this.addressCtrl,
    required this.hasSymptomError,
  });

  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final TextEditingController detailsCtrl;
  final TextEditingController addressCtrl;
  final bool hasSymptomError;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          "Help is being arranged. Tell us what's happening so we can send the right support.",
          style: TextStyle(
              fontSize: core.kFontSmall, color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: core.kSpaceXL),
        const _Caption("WHAT'S HAPPENING?"),
        const SizedBox(height: core.kSpaceMD),
        Wrap(
          spacing: core.kSpaceSM,
          runSpacing: core.kSpaceSM,
          children: [
            for (final s in _symptoms)
              _SymptomChip(
                label: s,
                selected: selected.contains(s),
                onTap: () => onToggle(s),
              ),
          ],
        ),
        if (hasSymptomError)
          Padding(
            padding: const EdgeInsets.only(top: core.kSpaceMD),
            child: Semantics(
              liveRegion: true,
              child: const Text(
                _emptySymptomsMessage,
                style: TextStyle(
                  color: Color(0xFFFFB4AB),
                  fontSize: core.kFontSmall,
                  height: 1.4,
                ),
              ),
            ),
          ),
        const SizedBox(height: core.kSpaceXL),
        const _Caption('ANY OTHER DETAILS? (OPTIONAL)'),
        const SizedBox(height: core.kSpaceMD),
        TextFormField(
          controller: detailsCtrl,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: _fieldDecoration(
            hint: 'e.g. patient is conscious, address details...',
          ),
        ),
        const SizedBox(height: core.kSpaceLG),
        TextFormField(
          controller: addressCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: _fieldDecoration(
            hint: 'Pickup address (leave blank for current location)',
            prefix: const Icon(Icons.location_on, color: Colors.white70),
          ),
        ),
      ],
    );
  }
}

InputDecoration _fieldDecoration({required String hint, Widget? prefix}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(core.kRadiusMD),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white70),
    prefixIcon: prefix,
    filled: true,
    fillColor: _fieldFill,
    border: border(_fieldBorder),
    enabledBorder: border(_fieldBorder),
    focusedBorder: border(core.kEmergencyRed, 1.5),
  );
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: core.kFontSmall,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
            letterSpacing: 1.1,
          ),
        ),
      );
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.isBusy, required this.onSubmit});

  final bool isBusy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          core.kSpaceLG, 0, core.kSpaceLG, core.kSpaceLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: isBusy ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: core.kEmergencyRed,
              foregroundColor: Colors.white,
              disabledBackgroundColor: core.kRed800,
              disabledForegroundColor: Colors.white70,
              minimumSize:
                  const Size.fromHeight(core.kMinTapTarget + 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(core.kRadiusLG),
              ),
            ),
            child: isBusy
                ? Semantics(
                    label: 'Sending your request',
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : const Text(
                    'Send for Help',
                    style: TextStyle(
                      fontSize: core.kFontMD,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(height: core.kSpaceMD),
          const Text(
            'Or call directly: 1122',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: core.kFontSmall),
          ),
        ],
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
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: true,
      checkmarkColor: Colors.white,
      backgroundColor: _fieldFill,
      selectedColor: core.kEmergencyRed,
      side: BorderSide(color: selected ? core.kEmergencyRed : _fieldBorder),
      labelStyle: TextStyle(
        color: Colors.white,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        fontSize: core.kFontSmall,
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: core.kSpaceSM, vertical: core.kSpaceMD),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(core.kRadiusLG),
      ),
    );
  }
}
