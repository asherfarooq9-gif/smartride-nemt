import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;

class RateDriverScreen extends StatefulWidget {
  const RateDriverScreen({super.key, required this.rideId});
  final String rideId;

  @override
  State<RateDriverScreen> createState() => _RateDriverScreenState();
}

class _RateDriverScreenState extends State<RateDriverScreen> {
  double _rating = 5;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await core.rateRide(
        widget.rideId,
        _rating,
        comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() { _submitting = false; _submitted = true; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is core.AppError ? e.message : 'Could not submit rating'),
        backgroundColor: core.kError,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Driver'),
        automaticallyImplyLeading: false,
      ),
      body: _submitted ? _SuccessView(onDone: () => context.go('/')) : _RatingForm(
        rating: _rating,
        commentCtrl: _commentCtrl,
        submitting: _submitting,
        onRatingChanged: (v) => setState(() => _rating = v),
        onSubmit: _submit,
        onSkip: () => context.go('/'),
      ),
    );
  }
}

class _RatingForm extends StatelessWidget {
  const _RatingForm({
    required this.rating,
    required this.commentCtrl,
    required this.submitting,
    required this.onRatingChanged,
    required this.onSubmit,
    required this.onSkip,
  });

  final double rating;
  final TextEditingController commentCtrl;
  final bool submitting;
  final ValueChanged<double> onRatingChanged;
  final VoidCallback onSubmit;
  final VoidCallback onSkip;

  static const _labels = ['Terrible', 'Poor', 'Okay', 'Good', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    final ratingInt = rating.round().clamp(1, 5);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(core.kSpaceXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: core.kSpaceXL),
          const Icon(Icons.directions_car, size: 72, color: core.kPatientPrimary),
          const SizedBox(height: core.kSpaceLG),
          Text(
            'How was your ride?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: core.kSpaceSM),
          Text(
            _labels[ratingInt - 1],
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: core.kTextSecondary),
          ),
          const SizedBox(height: core.kSpaceXL),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => onRatingChanged(star.toDouble()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    star <= ratingInt ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 48,
                    color: star <= ratingInt ? Colors.amber : core.kBorder,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: core.kSpaceXL),
          TextField(
            controller: commentCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Any comments? (optional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: core.kSpaceXL),
          core.PrimaryButton(
            label: 'Submit Rating',
            onPressed: submitting ? null : onSubmit,
            isLoading: submitting,
            color: core.kPatientPrimary,
            height: core.kButtonHeight,
          ),
          const SizedBox(height: core.kSpaceMD),
          TextButton(
            onPressed: submitting ? null : onSkip,
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(core.kSpaceXXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: core.kPatientPrimary),
            const SizedBox(height: core.kSpaceLG),
            Text(
              'Thank you!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: core.kSpaceSM),
            const Text(
              'Your feedback helps us improve the service.',
              textAlign: TextAlign.center,
              style: TextStyle(color: core.kTextSecondary),
            ),
            const SizedBox(height: core.kSpaceXXL),
            core.PrimaryButton(
              label: 'Back to Home',
              onPressed: onDone,
              color: core.kPatientPrimary,
              height: core.kButtonHeight,
            ),
          ],
        ),
      ),
    );
  }
}
