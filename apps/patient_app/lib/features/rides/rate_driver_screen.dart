import 'package:patient_app/l10n/l10n.dart';
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
        comment:
            _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } on core.AppError catch (e) {
      _failed(e.message);
    } on Exception catch (e, st) {
      core.ErrorReporter.report('Submitting a rating failed', e, st);
      _failed(context.l10n.couldNotSubmitRating);
    }
  }

  void _failed(String message) {
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: core.kError,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.rateYourDriverTitle),
        automaticallyImplyLeading: false,
      ),
      body: _submitted
          ? _SuccessView(onDone: () => context.go('/'))
          : _RatingForm(
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

  List<String> _labels(AppLocalizations l) => [
        l.ratingTerrible,
        l.ratingPoor,
        l.ratingOkay,
        l.ratingGood,
        l.ratingExcellent,
      ];

  @override
  Widget build(BuildContext context) {
    final ratingInt = rating.round().clamp(1, 5);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(core.kSpaceXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: core.kSpaceXL),
          const Icon(Icons.directions_car,
              size: 72, color: core.kPatientPrimary),
          const SizedBox(height: core.kSpaceLG),
          Text(
            context.l10n.howWasRide,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: core.kSpaceSM),
          Text(
            _labels(context.l10n)[ratingInt - 1],
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: core.kTextSecondary),
          ),
          const SizedBox(height: core.kSpaceXL),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return IconButton(
                tooltip: '$star out of 5 stars',
                isSelected: star == ratingInt,
                onPressed: () => onRatingChanged(star.toDouble()),
                constraints: const BoxConstraints(
                    minWidth: core.kMinTapTarget,
                    minHeight: core.kMinTapTarget),
                icon: Icon(
                  star <= ratingInt
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 40,
                  color: star <= ratingInt ? Colors.amber : core.kBorder,
                ),
              );
            }),
          ),
          const SizedBox(height: core.kSpaceXL),
          TextField(
            controller: commentCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: context.l10n.anyComments,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: core.kSpaceXL),
          core.PrimaryButton(
            label: context.l10n.submitRating,
            onPressed: submitting ? null : onSubmit,
            isLoading: submitting,
            color: core.kPatientPrimary,
            height: core.kButtonHeight,
          ),
          const SizedBox(height: core.kSpaceMD),
          TextButton(
            onPressed: submitting ? null : onSkip,
            child: Text(context.l10n.skip),
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
            const Icon(Icons.check_circle_outline,
                size: 80, color: core.kPatientPrimary),
            const SizedBox(height: core.kSpaceLG),
            Text(
              context.l10n.thankYou,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: core.kSpaceSM),
            Text(
              context.l10n.feedbackHelps,
              textAlign: TextAlign.center,
              style: const TextStyle(color: core.kTextSecondary),
            ),
            const SizedBox(height: core.kSpaceXXL),
            core.PrimaryButton(
              label: context.l10n.backToHome,
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
