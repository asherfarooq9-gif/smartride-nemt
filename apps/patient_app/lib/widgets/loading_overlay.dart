import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  final bool loading;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.loading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (loading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

/// Skeleton shimmer card for list loading states
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bar(context, width: 120, height: 12),
            const SizedBox(height: 10),
            _bar(context, width: double.infinity, height: 14),
            const SizedBox(height: 6),
            _bar(context, width: 180, height: 12),
          ],
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
