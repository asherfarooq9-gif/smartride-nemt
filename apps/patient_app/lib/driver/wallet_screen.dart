import 'package:patient_app/l10n/l10n.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/driver/money_format.dart';
import 'package:patient_app/shared/apple_list.dart';

final _walletProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (_) => getDriverWallet(),
);

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.walletTitle),
        leading: const BackButton(),
      ),
      body: ref.watch(_walletProvider).when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.failedLoadWallet,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: kSpaceMD),
                  TextButton(
                    onPressed: () => ref.invalidate(_walletProvider),
                    child: Text(context.l10n.retry),
                  ),
                ],
              ),
            ),
            data: (wallet) {
              final balance = (wallet['balance_pkr'] as num?)?.toDouble() ?? 0;
              final lowBalance = wallet['low_balance'] as bool? ?? false;
              final plan = wallet['plan'] as String? ?? 'Pay Per Ride · 10%';
              final weeklyCommission =
                  (wallet['weekly_commission_paid'] as num?)?.toDouble() ?? 0;
              final weeklyNet =
                  (wallet['weekly_net_earnings'] as num?)?.toDouble() ?? 0;
              final transactions =
                  wallet['transactions'] as List<dynamic>? ?? [];

              return ListView(
                padding: const EdgeInsets.symmetric(vertical: kSpaceLG),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kSpaceLG),
                    child: _BalanceCard(
                      balance: balance,
                      lowBalance: lowBalance,
                      onTopUp: () => context.push('/driver/top-up'),
                    ),
                  ),
                  _CurrentPlanCard(
                    plan: plan,
                    onChangePlan: () => context.push('/driver/top-up'),
                  ),
                  _WeekSummaryRow(
                    weeklyCommission: weeklyCommission,
                    weeklyNet: weeklyNet,
                  ),
                  _TransactionsList(transactions: transactions),
                  const SizedBox(height: kSpaceSM),
                  Center(
                    child: TextButton(
                      onPressed: () => context.push('/driver/earnings'),
                      child: Text(
                        context.l10n.driverEarningsHistory,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: kSpaceLG),
                ],
              );
            },
          ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double balance;
  final bool lowBalance;
  final VoidCallback onTopUp;

  const _BalanceCard({
    required this.balance,
    required this.lowBalance,
    required this.onTopUp,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = formatPkr(balance);
    return Container(
      padding: const EdgeInsets.all(kSpaceXL),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kBlue600, kBlue800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(kRadiusXXL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.accountBalance,
            style: const TextStyle(
              fontSize: kFontCaption,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: kSpaceSM),
          Text(
            formatted,
            style: const TextStyle(
              fontSize: kFontDisplay,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: kSpaceSM),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpaceMD,
              vertical: kSpaceXS,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(kRadiusPill),
            ),
            child: Text(
              lowBalance ? context.l10n.lowBalanceChip : context.l10n.allSet,
              style: TextStyle(
                fontSize: kFontCaption,
                fontWeight: FontWeight.w600,
                color: lowBalance
                    ? const Color(
                        0xFFFFD180) // light amber: readable on the blue card
                    : const Color(0xFF69F0AE),
              ),
            ),
          ),
          const SizedBox(height: kSpaceXL),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: onTopUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: kBlue600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadiusMD),
                ),
                padding: const EdgeInsets.symmetric(horizontal: kSpaceXL),
              ),
              child: Text(
                context.l10n.topUp,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The green and red that stay readable on the current surface.
Color _gain(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? kIosGreen : kOnlineGreen;
Color _loss(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? kDarkRed : kRed600;

class _CurrentPlanCard extends StatelessWidget {
  final String plan;
  final VoidCallback onChangePlan;

  const _CurrentPlanCard({
    required this.plan,
    required this.onChangePlan,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppleSection(
      children: [
        AppleRow(
          icon: Icons.workspace_premium_outlined,
          title: plan,
          subtitle: context.l10n.perCompletedRide,
          trailing: Text(
            context.l10n.changePlan,
            style: TextStyle(
              fontSize: kFontSmall,
              fontWeight: FontWeight.w600,
              color: isDark ? kDarkAccent : kBlue600,
            ),
          ),
          onTap: onChangePlan,
        ),
      ],
    );
  }
}

class _WeekSummaryRow extends StatelessWidget {
  final double weeklyCommission;
  final double weeklyNet;

  const _WeekSummaryRow({
    required this.weeklyCommission,
    required this.weeklyNet,
  });

  @override
  Widget build(BuildContext context) {
    return AppleSection(
      children: [
        Padding(
          padding: const EdgeInsets.all(kSpaceLG),
          child: Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: context.l10n.commissionPaid,
                  value: formatPkr(weeklyCommission),
                  valueColor: _loss(context),
                ),
              ),
              SizedBox(
                width: 0.5,
                height: 40,
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  label: context.l10n.netEarnings,
                  value: formatPkr(weeklyNet),
                  valueColor: _gain(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: kFontCaption,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: kSpaceXS),
        Text(
          value,
          style: TextStyle(
            fontSize: kFontSubhead,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _TransactionsList extends StatelessWidget {
  final List<dynamic> transactions;

  const _TransactionsList({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return AppleSection(
      header: context.l10n.recentTransactions,
      dividerIndent: appleIconDividerIndent,
      children: [
        if (transactions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(kSpaceLG),
            child: Text(
              context.l10n.noTransactionsYet,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final tx in transactions)
          _transactionRow(context, tx as Map<String, dynamic>),
      ],
    );
  }
}

/// One wallet movement: green and + when money came in, red and - when it went out.
Widget _transactionRow(BuildContext context, Map<String, dynamic> tx) {
  final amount = (tx['amount_pkr'] as num?)?.toDouble() ?? 0;
  final description = tx['description'] as String? ?? '';
  final createdAt = tx['created_at'] as String? ?? '';
  // By the sign of the amount, not the type: commissions are stored
  // negative and an opening 'adjustment' can be either.
  final isCredit = isCreditAmount(amount);
  final color = isCredit ? _gain(context) : _loss(context);
  return AppleRow(
    icon: isCredit ? Icons.add : Icons.remove,
    iconColor: isCredit ? kOnlineGreen : kRed600,
    title: description,
    subtitle: createdAt,
    trailing: Text(
      formatSignedPkr(amount),
      style: TextStyle(
        fontSize: kFontSmall,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}
