import 'package:patient_app/l10n/l10n.dart';

/// The ways a driver can say they take payment, in the order they are listed.
/// Must match PAYMENT_METHODS in the backend.
const paymentMethodIds = ['cash', 'easypaisa', 'jazzcash', 'bank_transfer'];

String paymentMethodLabel(AppLocalizations l, String id) => switch (id) {
      'cash' => l.paymentCash,
      'easypaisa' => l.paymentEasypaisa,
      'jazzcash' => l.paymentJazzcash,
      'bank_transfer' => l.paymentBank,
      _ => id,
    };

/// "Cash · Easypaisa", or an empty string when the driver listed none.
String paymentMethodsSummary(AppLocalizations l, List<String> ids) =>
    ids.map((id) => paymentMethodLabel(l, id)).join(' · ');
