import 'dart:math';

/// A unique key for one logical ride-booking attempt. Generate it once when
/// the user starts a submission and reuse it across retries of that same
/// attempt (including the offline pending-ride queue) — a fresh key per
/// retry would defeat the point, since the backend dedupes by this value.
String generateIdempotencyKey() {
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${DateTime.now().microsecondsSinceEpoch}-$hex';
}
