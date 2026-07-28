import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/driver/dashboard_notifier.dart';
import 'package:patient_app/shared/role_switcher.dart';

const Color _kBlue600 = Color(0xFF0B5980);
const Color _kTeal600 = Color(0xFF0B7777);
const Color _kRed600 = Color(0xFFC62828);
const Color _kText600 = Color(0xFF4A6464);
const Color _kCanvas = Color(0xFFECF7F7);
const Color _kBorder = Color(0xFFC8E2E2);
const double _kRadiusPill = 99;
const double _kRadiusXL = 16;

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => ref.read(dashboardProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dash = ref.watch(dashboardProvider);
    final driverName = dash.driver?.fullName ?? 'Driver';

    return Scaffold(
      backgroundColor: _kCanvas,
      drawer: const PortalDrawer(),
      body: Stack(
        children: [
          Column(
            children: [
              _Header(
                driverName: driverName,
                isVerified: dash.driver?.isVerified ?? false,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: _kBlue600,
                  onRefresh: () =>
                      ref.read(dashboardProvider.notifier).refresh(),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _StatsRow(
                                driver: dash.driver,
                                todayEarningsPkr: dash.todayEarningsPkr,
                              ),
                              const SizedBox(height: 12),
                              _WalletStrip(
                                balance:
                                    dash.driver?.walletBalancePkr ?? 0,
                                isLowBalance:
                                    dash.driver?.isLowBalance ?? false,
                              ),
                              const SizedBox(height: 12),
                              if (dash.error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: core.ErrorState(
                                    message: dash.error!,
                                    onRetry: () => ref
                                        .read(dashboardProvider.notifier)
                                        .refresh(),
                                  ),
                                ),
                              if (dash.isOnline) ...[
                                const _LookingForRidesStrip(),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (dash.isLoading)
                        const SliverFillRemaining(
                          child: core.LoadingState(message: 'Refreshing...'),
                        )
                      else if (dash.isOnline && dash.pendingRides.isEmpty)
                        const SliverFillRemaining(
                          child: core.EmptyState(
                            message:
                                'No pending rides.\nWaiting for new requests...',
                            icon: Icons.wifi_tethering,
                          ),
                        )
                      else if (dash.isOnline)
                        SliverPadding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => _RideRequestCard(
                                ride: dash.pendingRides[i],
                                driverLat: dash.driver?.currentLat,
                                driverLng: dash.driver?.currentLng,
                                onAccept: () =>
                                    _accept(dash.pendingRides[i].id),
                                onDecline: () => ref
                                    .read(dashboardProvider.notifier)
                                    .declineRide(
                                        dash.pendingRides[i].id.toString()),
                              ),
                              childCount: dash.pendingRides.length,
                            ),
                          ),
                        )
                      else
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 100),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 72,
            left: 0,
            right: 0,
            child: Center(
              child: _OnlinePill(
                isOnline: dash.isOnline,
                isVerified: dash.driver?.isVerified ?? false,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _BottomNav(),
    );
  }

  Future<void> _accept(String rideId) async {
    final result =
        await ref.read(dashboardProvider.notifier).acceptRide(rideId);
    if (!mounted) return;
    if (result == AcceptResult.success) {
      context.push('/driver/ride/$rideId');
    } else if (result == AcceptResult.alreadyTaken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ride already taken by another driver')),
      );
      ref.read(dashboardProvider.notifier).refresh();
    }
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.driverName, required this.isVerified});

  final String driverName;
  final bool isVerified;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B5980), Color(0xFF084A6E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Open menu',
                child: GestureDetector(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: const Icon(Icons.menu, color: Colors.white, size: 24),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Driver',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(_kRadiusPill),
                    ),
                    child: Text(
                      ref.watch(cityProvider),
                      style: const TextStyle(
                        color: _kBlue600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Builder(builder: (_) {
                final hasUnread = ref
                    .watch(notificationsProvider('driver'))
                    .any((n) => !n.isRead);
                return Semantics(
                  button: true,
                  label: hasUnread
                      ? 'Notifications, unread notifications available'
                      : 'Notifications',
                  child: GestureDetector(
                    onTap: () => context.push('/driver/notifications'),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_outlined,
                            color: Colors.white, size: 24),
                        if (hasUnread)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_greeting()}, $driverName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (!isVerified) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Verification pending — you cannot go online yet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.driver,
    required this.todayEarningsPkr,
  });

  final core.DriverResponse? driver;
  final double todayEarningsPkr;

  @override
  Widget build(BuildContext context) {
    final ratingText = driver?.rating != null
        ? driver!.rating!.toStringAsFixed(1)
        : '—';
    final earningsText = todayEarningsPkr > 0
        ? 'PKR ${_fmtPkr(todayEarningsPkr)}'
        : 'PKR 0';
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/driver/earnings'),
            child: _StatCard(
              label: "Today's Earnings",
              value: earningsText,
              valueColor: const Color(0xFF1B5E20),
              icon: Icons.trending_up,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Rating',
            value: ratingText,
            valueColor: _kBlue600,
            icon: Icons.star_rounded,
          ),
        ),
      ],
    );
  }

  static String _fmtPkr(double v) => v
      .toInt()
      .toString()
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
  });

  final String label;
  final String value;
  final Color valueColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kRadiusXL),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: valueColor, size: 18),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kText600,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletStrip extends StatelessWidget {
  const _WalletStrip({
    required this.balance,
    required this.isLowBalance,
  });

  final double balance;
  final bool isLowBalance;

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isLowBalance ? _kRed600 : _kBlue600,
        borderRadius: BorderRadius.circular(_kRadiusXL),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isLowBalance ? 'Low Balance ⚠' : 'Wallet Balance',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'PKR $formatted',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push('/driver/wallet'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(_kRadiusPill),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'Top Up →',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LookingForRidesStrip extends StatelessWidget {
  const _LookingForRidesStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kRadiusXL),
        border: Border.all(color: _kBorder),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
                  AlwaysStoppedAnimation<Color>(_kBlue600),
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Looking for ride requests...',
            style: TextStyle(
              fontSize: 13,
              color: _kText600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlinePill extends ConsumerWidget {
  const _OnlinePill({required this.isOnline, required this.isVerified});

  final bool isOnline;
  final bool isVerified;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        if (!isVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Verify your account first')),
          );
          return;
        }
        ref.read(dashboardProvider.notifier).toggleOnline();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 180,
        height: 52,
        decoration: BoxDecoration(
          color: isOnline ? _kBlue600 : const Color(0xFF1A3A4A),
          borderRadius: BorderRadius.circular(_kRadiusPill),
          boxShadow: isOnline
              ? [
                  BoxShadow(
                    color: const Color(0xFF2E7D32).withValues(alpha:0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : const [],
          gradient: isOnline
              ? const LinearGradient(
                  colors: [Color(0xFF0B5980), Color(0xFF0A6E99)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Center(
          child: Text(
            isOnline ? '● Online' : 'Go Online',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.directions_car_outlined,
              label: 'Requests',
              onTap: () => context.go('/driver'),
            ),
            _NavItem(
              icon: Icons.payments_outlined,
              label: 'Earnings',
              onTap: () => context.push('/driver/earnings'),
            ),
            _NavItem(
              icon: Icons.person_outline,
              label: 'Profile',
              onTap: () => context.push('/driver/profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _kBlue600, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: _kBlue600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RideRequestCard extends StatefulWidget {
  const _RideRequestCard({
    required this.ride,
    required this.onAccept,
    required this.onDecline,
    this.driverLat,
    this.driverLng,
  });

  final core.RideResponse ride;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final double? driverLat;
  final double? driverLng;

  @override
  State<_RideRequestCard> createState() => _RideRequestCardState();
}

class _RideRequestCardState extends State<_RideRequestCard> {
  late int _secondsLeft;
  Timer? _timer;

  // Average urban ambulance/taxi speed used to estimate pickup ETA.
  static const _avgSpeedKmh = 25.0;

  /// Haversine distance (km) from the driver to the pickup point, or null
  /// when either position is unknown — never show made-up numbers.
  double? get _distanceKm {
    final dLat = widget.driverLat, dLng = widget.driverLng;
    final pLat = widget.ride.pickupLat, pLng = widget.ride.pickupLng;
    if (dLat == null || dLng == null || pLat == null || pLng == null) {
      return null;
    }
    const earthRadiusKm = 6371.0;
    final dLatRad = _deg2rad(pLat - dLat);
    final dLngRad = _deg2rad(pLng - dLng);
    final a = math.sin(dLatRad / 2) * math.sin(dLatRad / 2) +
        math.cos(_deg2rad(dLat)) *
            math.cos(_deg2rad(pLat)) *
            math.sin(dLngRad / 2) *
            math.sin(dLngRad / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _deg2rad(double deg) => deg * math.pi / 180.0;

  String get _distanceLabel {
    final d = _distanceKm;
    return d == null ? '— km' : '~${d.toStringAsFixed(1)} km';
  }

  String get _etaLabel {
    final d = _distanceKm;
    if (d == null) return '— min';
    final minutes = (d / _avgSpeedKmh * 60).ceil().clamp(1, 999);
    return '$minutes min';
  }

  @override
  void initState() {
    super.initState();
    _secondsLeft = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _isEmergency =>
      widget.ride.rideType == core.RideType.emergency;
  bool get _expired => _secondsLeft == 0;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _expired ? 0.45 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kRadiusXL),
          border: Border.all(
            color: _isEmergency
                ? _kRed600.withValues(alpha:0.35)
                : _kBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isEmergency)
                  Container(
                    height: 4,
                    decoration: const BoxDecoration(
                      color: _kRed600,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(_kRadiusXL),
                        topRight: Radius.circular(_kRadiusXL),
                      ),
                    ),
                  ),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 14, 56, 16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      if (_isEmergency)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text(
                            'EMERGENCY',
                            style: TextStyle(
                              color: _kRed600,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      Text(
                        widget.ride.pickupAddress,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF152626),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.arrow_forward,
                              size: 14, color: _kText600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.ride.hospitalName ??
                                  (widget.ride.hospitalId != null
                                      ? 'Assigned hospital'
                                      : 'Destination'),
                              style: const TextStyle(
                                fontSize: 14,
                                color: _kText600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _InfoChip(
                            icon: Icons.route_outlined,
                            label: _distanceLabel,
                          ),
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.timer_outlined,
                            label: _etaLabel,
                          ),
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.payments_outlined,
                            label: widget.ride.estimatedFarePkr != null
                                ? 'PKR ${widget.ride.estimatedFarePkr!.toInt()}'
                                : 'PKR —',
                          ),
                        ],
                      ),
                      if (_isEmergency &&
                          widget.ride.symptomText != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: widget.ride.symptomText!
                              .split(',')
                              .map((s) => _SymptomChip(
                                  label: s.trim()))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed:
                              _expired ? null : widget.onAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kBlue600,
                            disabledBackgroundColor:
                                _kText600.withValues(alpha:0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Accept',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _expired ? null : widget.onDecline,
                          style: TextButton.styleFrom(
                            foregroundColor: _kRed600,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text(
                            'Decline',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: _isEmergency ? 20 : 12,
              right: 12,
              child: _CountdownRing(secondsLeft: _secondsLeft),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _kCanvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _kText600),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _kText600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SymptomChip extends StatelessWidget {
  const _SymptomChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kTeal600.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(_kRadiusPill),
        border: Border.all(color: _kTeal600.withValues(alpha:0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: _kTeal600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.secondsLeft});

  final int secondsLeft;

  Color get _ringColor {
    if (secondsLeft > 15) return _kBlue600;
    if (secondsLeft > 8) return Colors.amber;
    return _kRed600;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(
        painter: _RingPainter(
          progress: secondsLeft / 30.0,
          color: _ringColor,
        ),
        child: Center(
          child: Text(
            '$secondsLeft',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _ringColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 4) / 2;

    final trackPaint = Paint()
      ..color = color.withValues(alpha:0.15)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color;
}
