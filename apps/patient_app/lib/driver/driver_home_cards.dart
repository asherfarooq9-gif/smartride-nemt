import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/driver/money_format.dart';
import 'package:patient_app/features/rides/home_glass_card.dart';
import 'package:patient_app/features/rides/home_sheet_parts.dart'
    show SheetGreeting;

const Color _kAmber = Color(0xFFF59E0B);
const Color _kAmberText = Color(0xFF8A5300);
const Color _kGreen = Color(0xFF22A55A);
const Color _kGreenText = Color(0xFF167A41);

/// "Good evening, Asher" with a wave and a calm line under it. Falls back to
/// "Driver" until the profile has loaded.
class DriverGreeting extends StatelessWidget {
  const DriverGreeting({super.key, this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);
    final who = (name == null || name!.trim().isEmpty) ? 'Driver' : name!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Semantics(
                header: true,
                child: Text(
                  '${SheetGreeting.greetingFor(DateTime.now())}, $who',
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
          "Stay safe. You're on the road.",
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
      label: 'Verification pending. You cannot go online until your account '
          'is verified.',
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
                      'Verification pending',
                      style: TextStyle(
                        fontSize: core.kFontSmall + 1,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : _kAmberText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'You cannot go online until your account is verified.',
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

/// Today's earnings and the driver's rating, side by side.
class DriverStatsRow extends StatelessWidget {
  const DriverStatsRow({
    super.key,
    required this.todayEarningsPkr,
    required this.rating,
  });

  /// Null while the server has not said: shown as a dash, never as PKR 0.
  final double? todayEarningsPkr;

  /// Null while the driver has no rating yet.
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final earnings =
        todayEarningsPkr == null ? '—' : formatPkr(todayEarningsPkr!);
    final ratingText = rating == null ? '—' : rating!.toStringAsFixed(1);
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.trending_up_rounded,
            iconBackground: _kGreen.withValues(alpha: 0.14),
            iconColor: _kGreenText,
            label: "Today's Earnings",
            value: earnings,
            semanticsLabel: todayEarningsPkr == null
                ? "Today's earnings, not available. View earnings"
                : "Today's earnings, $earnings. View earnings",
            onTap: () => context.push('/driver/earnings'),
          ),
        ),
        const SizedBox(width: core.kSpaceSM),
        Expanded(
          child: _StatCard(
            icon: Icons.star_rounded,
            label: 'Rating',
            value: ratingText,
            semanticsLabel: rating == null
                ? 'Rating, not rated yet'
                : 'Rating, $ratingText',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.semanticsLabel,
    this.iconBackground,
    this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final Color? iconBackground;
  final Color? iconColor;
  final String label;
  final String value;
  final String semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      child: HomeGlassCard(
        onTap: onTap,
        radius: 16,
        isSeeThrough: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: core.kSpaceSM + 2,
              vertical: 6,
            ),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: iconBackground ?? palette.iconTint,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: Icon(
                      icon,
                      size: 18,
                      color: iconColor ?? palette.iconColor,
                    ),
                  ),
                ),
                const SizedBox(width: core.kSpaceSM),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: palette.muted),
                      ),
                      // A money amount is never cut off: it shrinks a little to fit.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: palette.heading,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: palette.muted),
              ],
            ),
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
                        isLowBalance ? 'Low balance' : 'Wallet Balance',
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
      label: 'Top up wallet',
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
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Top Up',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
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
