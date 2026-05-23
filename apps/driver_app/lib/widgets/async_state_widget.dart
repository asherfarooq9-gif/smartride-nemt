import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A generic widget that handles the three states of a Riverpod [AsyncValue]:
/// loading, error, and data.
///
/// Usage:
/// ```dart
/// AsyncStateWidget<MyData>(
///   value: ref.watch(myProvider),
///   onData: (data) => Text(data.toString()),
/// )
/// ```
class AsyncStateWidget<T> extends StatelessWidget {
  const AsyncStateWidget({
    super.key,
    required this.value,
    required this.onData,
    this.onError,
    this.onLoading,
    this.onRetry,
  });

  /// The [AsyncValue] to observe.
  final AsyncValue<T> value;

  /// Builder for the data state.
  final Widget Function(T data) onData;

  /// Optional builder for the error state. Defaults to a centred red error
  /// message with an optional retry button.
  final Widget Function(Object error, StackTrace? stack)? onError;

  /// Optional builder for the loading state. Defaults to a centred
  /// [CircularProgressIndicator].
  final Widget Function()? onLoading;

  /// If provided, a "Retry" button is shown beneath the default error message.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () =>
          onLoading?.call() ??
          const Center(child: CircularProgressIndicator()),
      error: (e, st) =>
          onError?.call(e, st) ??
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Error: $e',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
      data: onData,
    );
  }
}
