import 'package:patient_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/shared/apple_list.dart';

class _Plan {
  final String name;
  final int rides;
  final int price;
  final int pricePerRide;
  final int savingsPct;
  final bool isPopular;

  const _Plan({
    required this.name,
    required this.rides,
    required this.price,
    required this.pricePerRide,
    required this.savingsPct,
    this.isPopular = false,
  });
}

const _plans = [
  _Plan(
    name: 'Starter',
    rides: 7,
    price: 250,
    pricePerRide: 36,
    savingsPct: 20,
  ),
  _Plan(
    name: 'Standard',
    rides: 18,
    price: 540,
    pricePerRide: 30,
    savingsPct: 33,
    isPopular: true,
  ),
  _Plan(
    name: 'Pro',
    rides: 36,
    price: 900,
    pricePerRide: 25,
    savingsPct: 44,
  ),
];

class _PaymentMethod {
  final String label;
  final IconData icon;

  const _PaymentMethod({required this.label, required this.icon});
}

const _paymentMethods = [
  _PaymentMethod(label: 'JazzCash', icon: Icons.phone_android),
  _PaymentMethod(
      label: 'EasyPaisa', icon: Icons.account_balance_wallet_outlined),
  _PaymentMethod(label: 'Bank Transfer', icon: Icons.account_balance_outlined),
  _PaymentMethod(label: 'Card', icon: Icons.credit_card_outlined),
];

const _quickAmounts = [500, 1000, 2000, 5000];

// Same address as the Contact screen; wallet top-ups are confirmed by hand.
const _supportEmail = 'support@smartride.pk';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  int? _selectedPlan;
  bool _isCustom = false;
  final _customAmount = TextEditingController();
  String _paymentMethod = 'JazzCash';

  @override
  void dispose() {
    _customAmount.dispose();
    super.dispose();
  }

  String _confirmLabel(AppLocalizations l) {
    if (_isCustom) {
      final amt = _customAmount.text.trim();
      return amt.isEmpty ? l.enterAnAmount : l.continueAmount(amt);
    }
    if (_selectedPlan != null) {
      final plan = _plans[_selectedPlan!];
      return l.continuePlan(plan.name, plan.price.toString());
    }
    return l.selectPlanOrAmount;
  }

  bool get _canConfirm {
    if (_isCustom) {
      final val = int.tryParse(_customAmount.text.trim());
      return val != null && val > 0;
    }
    return _selectedPlan != null;
  }

  // The server has no self-service payment: an admin credits the wallet after
  // the payment is settled by hand, so this screen explains the steps instead
  // of pretending to charge anything. ponytail: replace with a payment gateway
  // call when one is integrated.
  void _showInstructions(BuildContext context) {
    final amount = _isCustom
        ? _customAmount.text.trim()
        : _plans[_selectedPlan!].price.toString();
    showDialog<void>(
      context: context,
      builder: (_) => _InstructionsDialog(
        title: context.l10n.howToTopUp,
        message: context.l10n
            .topUpInstructions(amount, _paymentMethod, _supportEmail),
        onDone: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.topUpPlans),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: kSpaceLG),
        children: [
          AppleSection(
            header: l.choosePlan,
            children: [
              for (final (i, plan) in _plans.indexed)
                _planRow(
                  context,
                  plan,
                  isSelected: !_isCustom && _selectedPlan == i,
                  onTap: () => setState(() {
                    _selectedPlan = i;
                    _isCustom = false;
                  }),
                ),
              AppleRow(
                title: l.customAmount,
                trailing: _isCustom ? const _Check() : null,
                onTap: () => setState(() {
                  _isCustom = !_isCustom;
                  if (_isCustom) _selectedPlan = null;
                }),
              ),
              if (_isCustom)
                _CustomAmountField(
                  controller: _customAmount,
                  onAmountChanged: () => setState(() {}),
                ),
            ],
          ),
          AppleSection(
            header: l.payFrom,
            dividerIndent: appleIconDividerIndent,
            children: [
              for (final m in _paymentMethods)
                AppleRow(
                  icon: m.icon,
                  title: m.label,
                  trailing: _paymentMethod == m.label ? const _Check() : null,
                  onTap: () => setState(() => _paymentMethod = m.label),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              kSpaceLG,
              kSpaceXL,
              kSpaceLG,
              kSpaceLG,
            ),
            child: PrimaryButton(
              label: _confirmLabel(l),
              onPressed: _canConfirm ? () => _showInstructions(context) : null,
              color: kBlue600,
              height: kButtonHeight,
            ),
          ),
        ],
      ),
    );
  }
}

/// The blue tick that marks the chosen row, as in iOS selection lists.
class _Check extends StatelessWidget {
  const _Check();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Icon(
      Icons.check,
      size: 22,
      color: isDark ? kDarkAccent : kBlue600,
    );
  }
}

/// One plan: name and per-ride price on the left, total and saving on the right.
Widget _planRow(
  BuildContext context,
  _Plan plan, {
  required bool isSelected,
  required VoidCallback onTap,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final popular = plan.isPopular ? ' · ${context.l10n.mostPopular}' : '';
  return AppleRow(
    title: plan.name,
    subtitle: '${plan.rides} rides · PKR ${plan.pricePerRide}/ride$popular',
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'PKR ${plan.price}',
              style: TextStyle(
                fontSize: kFontBody,
                fontWeight: FontWeight.w700,
                color: isDark ? kDarkAccent : kBlue600,
              ),
            ),
            Text(
              '\u2212${plan.savingsPct}%',
              style: TextStyle(
                fontSize: kFontCaption,
                fontWeight: FontWeight.w700,
                color: isDark ? kIosGreen : kOnlineGreen,
              ),
            ),
          ],
        ),
        const SizedBox(width: kSpaceSM),
        SizedBox(width: 22, child: isSelected ? const _Check() : null),
      ],
    ),
    onTap: onTap,
  );
}

/// The amount box and quick amounts, shown under "Custom amount" once chosen.
class _CustomAmountField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAmountChanged;

  const _CustomAmountField({
    required this.controller,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(kSpaceLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            onChanged: (_) => onAmountChanged(),
            decoration: InputDecoration(
              prefixText: 'PKR  ',
              hintText: context.l10n.enterAmount,
            ),
          ),
          const SizedBox(height: kSpaceMD),
          Wrap(
            spacing: kSpaceSM,
            children: [
              for (final amt in _quickAmounts)
                GestureDetector(
                  onTap: () {
                    controller.text = amt.toString();
                    onAmountChanged();
                  },
                  child: Chip(
                    label: Text(
                      amt >= 1000 ? '${amt ~/ 1000},000' : amt.toString(),
                    ),
                    labelStyle: TextStyle(
                      fontSize: kFontSmall,
                      color: isDark ? kDarkAccent : kBlue600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Explains a manual step. It is not a confirmation, so it must not look like one:
/// an earlier version showed "Almost done" with a green check, and a driver could
/// reasonably believe a payment had been taken.
class _InstructionsDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onDone;

  const _InstructionsDialog({
    required this.title,
    required this.message,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusXXL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(kSpaceXXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: kBlue600.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline,
                color: kBlue600,
                size: 40,
              ),
            ),
            const SizedBox(height: kSpaceLG),
            Text(
              title,
              style: TextStyle(
                fontSize: kFontHeading,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: kSpaceMD),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: kFontBody,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: kSpaceXXL),
            PrimaryButton(
              label: context.l10n.done,
              onPressed: onDone,
              color: kBlue600,
              height: kButtonHeight,
            ),
          ],
        ),
      ),
    );
  }
}
