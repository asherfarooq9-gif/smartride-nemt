import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';

final _walletProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (_) => getDriverWallet(),
);

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: kCanvas,
      appBar: AppBar(
        backgroundColor: kBlue600,
        foregroundColor: Colors.white,
        title: const Text('Wallet'),
        leading: const BackButton(),
      ),
      body: ref.watch(_walletProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Failed to load wallet',
                    style: TextStyle(color: kText600),
                  ),
                  const SizedBox(height: kSpaceMD),
                  TextButton(
                    onPressed: () => ref.invalidate(_walletProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (wallet) {
              final balance =
                  (wallet['balance_pkr'] as num?)?.toDouble() ?? 0;
              final lowBalance = wallet['low_balance'] as bool? ?? false;
              final plan =
                  wallet['plan'] as String? ?? 'Pay Per Ride · 10%';
              final weeklyCommission =
                  (wallet['weekly_commission_paid'] as num?)?.toDouble() ??
                      0;
              final weeklyNet =
                  (wallet['weekly_net_earnings'] as num?)?.toDouble() ?? 0;
              final transactions =
                  wallet['transactions'] as List<dynamic>? ?? [];

              return ListView(
                padding: const EdgeInsets.all(kSpaceLG),
                children: [
                  _BalanceCard(
                    balance: balance,
                    lowBalance: lowBalance,
                    onTopUp: () => context.push('/driver/top-up'),
                  ),
                  const SizedBox(height: kSpaceLG),
                  _CurrentPlanCard(
                    plan: plan,
                    onChangePlan: () => context.push('/driver/top-up'),
                  ),
                  const SizedBox(height: kSpaceLG),
                  _WeekSummaryRow(
                    weeklyCommission: weeklyCommission,
                    weeklyNet: weeklyNet,
                  ),
                  const SizedBox(height: kSpaceLG),
                  _TransactionsList(transactions: transactions),
                  const SizedBox(height: kSpaceSM),
                  Center(
                    child: TextButton(
                      onPressed: () => context.push('/driver/earnings'),
                      child: const Text(
                        'Driver earnings history →',
                        style: TextStyle(
                          color: kBlue600,
                          fontWeight: FontWeight.w600,
                        ),
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
    final formatted = balance
        .toInt()
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
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
          const Text(
            'ACCOUNT BALANCE',
            style: TextStyle(
              fontSize: kFontCaption,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: kSpaceSM),
          Text(
            'PKR $formatted',
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
              lowBalance ? '⚠ Low balance' : '● All set',
              style: TextStyle(
                fontSize: kFontCaption,
                fontWeight: FontWeight.w600,
                color: lowBalance
                    ? const Color(0xFFFF7043)
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
                padding:
                    const EdgeInsets.symmetric(horizontal: kSpaceXL),
              ),
              child: const Text(
                'Top Up',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  final String plan;
  final VoidCallback onChangePlan;

  const _CurrentPlanCard({
    required this.plan,
    required this.onChangePlan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusXL),
        border: Border.all(color: kBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: kSpaceLG,
          vertical: kSpaceSM,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: kBlue600.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(kRadiusMD),
          ),
          child: const Icon(
            Icons.workspace_premium_outlined,
            color: kBlue600,
            size: 22,
          ),
        ),
        title: Text(
          plan,
          style: const TextStyle(
            fontSize: kFontBody,
            fontWeight: FontWeight.w700,
            color: kText900,
          ),
        ),
        subtitle: const Text(
          'per completed ride',
          style: TextStyle(fontSize: kFontSmall, color: kText600),
        ),
        trailing: GestureDetector(
          onTap: onChangePlan,
          child: const Text(
            'Change Plan →',
            style: TextStyle(
              fontSize: kFontSmall,
              fontWeight: FontWeight.w600,
              color: kBlue600,
            ),
          ),
        ),
      ),
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
    return Container(
      padding: const EdgeInsets.all(kSpaceLG),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusXL),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              label: 'Commission paid',
              value: 'PKR ${weeklyCommission.toInt()}',
              valueColor: kRed600,
            ),
          ),
          const SizedBox(width: 1, height: 40, child: ColoredBox(color: kBorder)),
          Expanded(
            child: _SummaryItem(
              label: 'Net earnings',
              value: 'PKR ${weeklyNet.toInt()}',
              valueColor: kOnlineGreen,
            ),
          ),
        ],
      ),
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
          style: const TextStyle(
            fontSize: kFontCaption,
            color: kText600,
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
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusXL),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
                kSpaceLG, kSpaceLG, kSpaceLG, kSpaceSM),
            child: Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: kFontBody,
                fontWeight: FontWeight.w700,
                color: kText900,
              ),
            ),
          ),
          const Divider(height: 1, color: kBorder),
          ...transactions.map((tx) {
            final txMap = tx as Map<String, dynamic>;
            final amount =
                (txMap['amount_pkr'] as num?)?.toDouble() ?? 0;
            final description =
                txMap['description'] as String? ?? '';
            final type = txMap['type'] as String? ?? '';
            final createdAt = txMap['created_at'] as String? ?? '';
            final isCredit = type == 'topup';
            return _TransactionRow(
              amount: amount,
              description: description,
              isCredit: isCredit,
              date: createdAt,
            );
          }),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final double amount;
  final String description;
  final bool isCredit;
  final String date;

  const _TransactionRow({
    required this.amount,
    required this.description,
    required this.isCredit,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final amountColor = isCredit ? kOnlineGreen : kRed600;
    final amountText = isCredit
        ? '+PKR ${amount.toInt()}'
        : '−PKR ${amount.toInt()}';
    final icon =
        isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline;

    return Container(
      constraints: const BoxConstraints(minHeight: kMinTapTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: kSpaceLG,
        vertical: kSpaceMD,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: amountColor, size: 20),
          const SizedBox(width: kSpaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: kFontSmall,
                    fontWeight: FontWeight.w500,
                    color: kText900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: kFontCaption,
                    color: kText400,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amountText,
            style: TextStyle(
              fontSize: kFontSmall,
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}
