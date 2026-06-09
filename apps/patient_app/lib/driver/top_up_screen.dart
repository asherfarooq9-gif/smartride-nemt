import 'package:flutter/material.dart';
import 'package:smartride_core/smartride_core.dart';

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
  _PaymentMethod(label: 'EasyPaisa', icon: Icons.account_balance_wallet_outlined),
  _PaymentMethod(label: 'Bank Transfer', icon: Icons.account_balance_outlined),
  _PaymentMethod(label: 'Card', icon: Icons.credit_card_outlined),
];

const _quickAmounts = [500, 1000, 2000, 5000];

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
  bool _loading = false;

  @override
  void dispose() {
    _customAmount.dispose();
    super.dispose();
  }

  String get _confirmLabel {
    if (_isCustom) {
      final amt = _customAmount.text.trim();
      return amt.isEmpty ? 'Enter an amount' : 'Top Up PKR $amt';
    }
    if (_selectedPlan != null) {
      final plan = _plans[_selectedPlan!];
      return 'Activate ${plan.name} · PKR ${plan.price}';
    }
    return 'Select a plan or amount';
  }

  bool get _canConfirm {
    if (_isCustom) {
      final val = int.tryParse(_customAmount.text.trim());
      return val != null && val > 0;
    }
    return _selectedPlan != null;
  }

  void _showSuccess(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _SuccessDialog(
        title: _isCustom ? 'Top-up successful!' : 'Plan activated!',
        onDone: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCanvas,
      appBar: AppBar(
        backgroundColor: kBlue600,
        foregroundColor: Colors.white,
        title: const Text('Top Up & Plans'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(kSpaceLG),
        children: [
          const Text(
            'Choose a plan',
            style: TextStyle(
              fontSize: kFontSubhead,
              fontWeight: FontWeight.w700,
              color: kText900,
            ),
          ),
          const SizedBox(height: kSpaceMD),
          ..._plans.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: kSpaceMD),
                  child: _PlanCard(
                    plan: entry.value,
                    isSelected: !_isCustom && _selectedPlan == entry.key,
                    onTap: () => setState(() {
                      _selectedPlan = entry.key;
                      _isCustom = false;
                    }),
                  ),
                ),
              ),
          _CustomAmountTile(
            isSelected: _isCustom,
            controller: _customAmount,
            onToggle: () => setState(() {
              _isCustom = !_isCustom;
              if (_isCustom) _selectedPlan = null;
            }),
            onAmountChanged: () => setState(() {}),
          ),
          const SizedBox(height: kSpaceXL),
          const Text(
            'Pay From',
            style: TextStyle(
              fontSize: kFontSubhead,
              fontWeight: FontWeight.w700,
              color: kText900,
            ),
          ),
          const SizedBox(height: kSpaceMD),
          Container(
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(kRadiusXL),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              children: _paymentMethods
                  .map(
                    (m) => _PaymentMethodRow(
                      method: m,
                      isSelected: _paymentMethod == m.label,
                      onTap: () => setState(() => _paymentMethod = m.label),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: kSpaceXXL),
          PrimaryButton(
            label: _confirmLabel,
            isLoading: _loading,
            onPressed: _canConfirm
                ? () async {
                    setState(() => _loading = true);
                    try {
                      await topUpWallet(
                        amountPkr: _isCustom
                            ? (double.tryParse(_customAmount.text) ?? 0)
                            : null,
                        planId: _isCustom ? null : const ['starter', 'standard', 'pro'][_selectedPlan!],
                        paymentMethod: _paymentMethod,
                      );
                      if (!mounted) return;
                      // ignore: use_build_context_synchronously
                      _showSuccess(context);
                    } on AppError catch (e) {
                      if (!mounted) return;
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.message),
                          backgroundColor: kRed600,
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  }
                : null,
            color: kBlue600,
            height: kButtonHeight,
          ),
          const SizedBox(height: kSpaceLG),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(kSpaceLG),
        decoration: BoxDecoration(
          color: isSelected ? kBlue100 : kSurface,
          borderRadius: BorderRadius.circular(kRadiusXL),
          border: Border.all(
            color: isSelected ? kBlue600 : kBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                          fontSize: kFontBody,
                          fontWeight: FontWeight.w700,
                          color: kText900,
                        ),
                      ),
                      if (plan.isPopular) ...[
                        const SizedBox(width: kSpaceSM),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpaceSM,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: kTeal600.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(kRadiusPill),
                          ),
                          child: const Text(
                            'Most Popular',
                            style: TextStyle(
                              fontSize: kFontCaption,
                              fontWeight: FontWeight.w700,
                              color: kTeal600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: kSpaceXS),
                  Text(
                    '${plan.rides} rides · PKR ${plan.pricePerRide}/ride',
                    style: const TextStyle(
                      fontSize: kFontSmall,
                      color: kText600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'PKR ${plan.price}',
                  style: const TextStyle(
                    fontSize: kFontSubhead,
                    fontWeight: FontWeight.w700,
                    color: kBlue600,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpaceSM,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: kOnlineGreen.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(kRadiusPill),
                  ),
                  child: Text(
                    '−${plan.savingsPct}%',
                    style: const TextStyle(
                      fontSize: kFontCaption,
                      fontWeight: FontWeight.w700,
                      color: kOnlineGreen,
                    ),
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

class _CustomAmountTile extends StatelessWidget {
  final bool isSelected;
  final TextEditingController controller;
  final VoidCallback onToggle;
  final VoidCallback onAmountChanged;

  const _CustomAmountTile({
    required this.isSelected,
    required this.controller,
    required this.onToggle,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(kSpaceLG),
      decoration: BoxDecoration(
        color: isSelected ? kBlue100 : kSurface,
        borderRadius: BorderRadius.circular(kRadiusXL),
        border: Border.all(
          color: isSelected ? kBlue600 : kBorder,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Row(
              children: [
                SizedBox(
                  width: kMinTapTarget,
                  height: kMinTapTarget,
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? kBlue600 : kBorder,
                          width: isSelected ? 6 : 2,
                        ),
                      ),
                    ),
                  ),
                ),
                const Text(
                  'Custom amount',
                  style: TextStyle(
                    fontSize: kFontBody,
                    fontWeight: FontWeight.w600,
                    color: kText900,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected) ...[
            const SizedBox(height: kSpaceMD),
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              onChanged: (_) => onAmountChanged(),
              decoration: const InputDecoration(
                prefixText: 'PKR  ',
                hintText: 'Enter amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: kSpaceMD),
            Wrap(
              spacing: kSpaceSM,
              children: _quickAmounts
                  .map(
                    (amt) => GestureDetector(
                      onTap: () {
                        controller.text = amt.toString();
                        onAmountChanged();
                      },
                      child: Chip(
                        label: Text(
                          amt >= 1000
                              ? '${amt ~/ 1000},000'
                              : amt.toString(),
                        ),
                        backgroundColor: kCanvas,
                        side: const BorderSide(color: kBorder),
                        labelStyle: const TextStyle(
                          fontSize: kFontSmall,
                          color: kBlue600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentMethodRow extends StatelessWidget {
  final _PaymentMethod method;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodRow({
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: kMinTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: kSpaceLG),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorder, width: 0.5)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: kMinTapTarget,
              height: kMinTapTarget,
              child: Center(
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? kBlue600 : kBorder,
                      width: isSelected ? 6 : 2,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kBlue600.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(kRadiusSM),
              ),
              child: Icon(method.icon, color: kBlue600, size: 18),
            ),
            const SizedBox(width: kSpaceMD),
            Text(
              method.label,
              style: const TextStyle(
                fontSize: kFontBody,
                fontWeight: FontWeight.w500,
                color: kText900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  final String title;
  final VoidCallback onDone;

  const _SuccessDialog({required this.title, required this.onDone});

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
                color: kOnlineGreen.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: kOnlineGreen,
                size: 40,
              ),
            ),
            const SizedBox(height: kSpaceLG),
            Text(
              title,
              style: const TextStyle(
                fontSize: kFontHeading,
                fontWeight: FontWeight.w700,
                color: kText900,
              ),
            ),
            const SizedBox(height: kSpaceXXL),
            PrimaryButton(
              label: 'Done',
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
