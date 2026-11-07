import 'package:patient_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/driver/money_format.dart';
import 'package:patient_app/features/rides/home_glass_card.dart';
import 'package:patient_app/features/rides/home_sheet_parts.dart'
    show SheetGreeting;

const Color _kAmber = Color(0xFFF59E0B);
const Color _kAmberText = Color(0xFF8A5300);

/// "Good evening, Asher" with a wave and a calm line under it. Falls back to
/// "Driver" until the profile has loaded.
class DriverGreeting extends StatelessWidget {
  const DriverGreeting({super.key, this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);
    final who = (name == null || name!.trim().isEmpty)
        ? context.l10n.driverWord
        : name!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Semantics(
                header: true,
                child: Text(
                  '${SheetGreeting.greetingFor(context.l10n, DateTime.now())}, $who',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: core.kFontHeading,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: palette.heading,
                  ),
                ),
              ),
            ),
            const SizedBox(width: core.kSpaceSM),
            const ExcludeSemantics(
              child: Text('👋', style: TextStyle(fontSize: 19)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          context.l10n.driverStaySafe,
          style: TextStyle(fontSize: core.kFontSmall, color: palette.muted),
        ),
      ],
    );
  }
}

/// Shown only while the server says the driver is not verified. It explains why
/// the Online controls are locked; it never unlocks them.
class VerificationCard extends StatelessWidget {
  const VerificationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      container: true,
      label: context.l10n.verificationSemantic,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _kAmber.withValues(alpha: isDark ? 0.18 : 0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kAmber.withValues(alpha: 0.45)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(core.kSpaceSM + 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: _kAmber),
              const SizedBox(width: core.kSpaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.verificationPending,
                      style: TextStyle(
                        fontSize: core.kFontSmall + 1,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : _kAmberText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.verificationBody,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white70 : _kAmberText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The reference gradient runs to a pale blue that white text cannot be read
// on, so the far end is deeper.
const _kWalletGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFF2569BC), Color(0xFF3A7BCF)],
);
const _kWalletLowGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFFB3261E), Color(0xFFD64540)],
);

/// The wallet balance with a Top Up shortcut. Turns red when the balance is low.
class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.balancePkr,
    required this.isLowBalance,
  });

  /// Null until the account has loaded: shown as a dash, never as PKR 0.
  final double? balancePkr;
  final bool isLowBalance;

  @override
  Widget build(BuildContext context) {
    final balance = balancePkr == null ? '—' : formatPkr(balancePkr!);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isLowBalance ? _kWalletLowGradient : _kWalletGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2569BC).withValues(alpha: 0.26),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: core.kSpaceSM + 2,
            vertical: 6,
          ),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: core.kSpaceSM + 2),
              Expanded(
                child: Semantics(
                  label:
                      '${isLowBalance ? 'Low wallet balance' : 'Wallet balance'}'
                      ', $balance',
                  excludeSemantics: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLowBalance
                            ? context.l10n.lowBalance
                            : context.l10n.walletBalance,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        balance,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: core.kSpaceSM),
              _TopUpButton(onTap: () => context.push('/driver/wallet')),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopUpButton extends StatelessWidget {
  const _TopUpButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.topUpWalletLabel,
      excludeSemantics: true,
      // The pill is compact, but the area that answers a tap is still 44 high.
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                // A darker tint, not a lighter one: white text stays readable.
                color: Colors.black.withValues(alpha: 0.18),
                shape: StadiumBorder(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.topUp,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 14, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
