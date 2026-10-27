// Money display for the driver app. Amounts come from the server as JSON numbers
// already rounded to paisa; these only format them.

/// "PKR 1,234" or "PKR 1,234.50" (no decimals for whole rupees). Rounds to the
/// nearest paisa instead of truncating, and keeps the sign of a negative amount
/// even when it is under one rupee ("−PKR 0.50", which `toInt()` showed as 0).
String formatPkr(num amount) {
  final cents = (amount.abs() * 100).round();
  final negative = amount < 0 && cents > 0;
  final rupees = cents ~/ 100;
  final paisa = cents % 100;
  final grouped = rupees.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      );
  final decimals = paisa == 0 ? '' : '.${paisa.toString().padLeft(2, '0')}';
  return '${negative ? '−' : ''}PKR $grouped$decimals';
}

/// Like [formatPkr] with a leading plus for credits.
String formatSignedPkr(num amount) {
  final text = formatPkr(amount);
  return amount > 0 && !text.startsWith('−') && text != 'PKR 0' ? '+$text' : text;
}

/// A ledger row is a credit when it adds money. The sign of the amount decides:
/// commissions are stored negative, top-ups positive, and an 'adjustment' (the
/// opening balance entry) can be either.
bool isCreditAmount(num amount) => amount > 0;
