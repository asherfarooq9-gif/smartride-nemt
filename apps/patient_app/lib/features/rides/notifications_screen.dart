import 'package:flutter/material.dart';
import 'package:smartride_core/smartride_core.dart';

class _NotificationItem {
  final String title;
  final String body;
  final String time;
  final IconData icon;
  final bool isRead;

  const _NotificationItem({
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.isRead,
  });
}

const _patientNotifications = [
  _NotificationItem(
    title: 'Ride Confirmed',
    body: 'Your ride to Pakistan Institute of Medical Sciences has been confirmed.',
    time: '2 min ago',
    icon: Icons.check_circle_outline,
    isRead: false,
  ),
  _NotificationItem(
    title: 'Driver On The Way',
    body: 'Ahmed Khan is heading to your pickup location. ETA 8 minutes.',
    time: '10 min ago',
    icon: Icons.directions_car_outlined,
    isRead: false,
  ),
  _NotificationItem(
    title: 'Payment Received',
    body: 'PKR 350 payment processed successfully for your last ride.',
    time: '1 hr ago',
    icon: Icons.payment_outlined,
    isRead: true,
  ),
  _NotificationItem(
    title: 'Ride Completed',
    body: 'Your ride has been completed. Thank you for using SmartRide.',
    time: '3 hr ago',
    icon: Icons.flag_outlined,
    isRead: true,
  ),
  _NotificationItem(
    title: 'Rate Your Driver',
    body: 'How was your experience with Muhammad Ali? Tap to leave a review.',
    time: 'Yesterday',
    icon: Icons.star_outline,
    isRead: true,
  ),
];

const _driverNotifications = [
  _NotificationItem(
    title: 'New Ride Request',
    body: 'Patient pickup at G-10 Markaz. 3.2 km away. Tap to accept.',
    time: '1 min ago',
    icon: Icons.notifications_active_outlined,
    isRead: false,
  ),
  _NotificationItem(
    title: 'Earnings Credited',
    body: 'PKR 420 has been credited to your wallet for 3 completed rides.',
    time: '30 min ago',
    icon: Icons.account_balance_wallet_outlined,
    isRead: false,
  ),
  _NotificationItem(
    title: 'Commission Deducted',
    body: 'PKR 45 platform commission deducted for ride #SR-4821.',
    time: '2 hr ago',
    icon: Icons.receipt_long_outlined,
    isRead: true,
  ),
  _NotificationItem(
    title: 'Verification Approved',
    body: 'Your driver profile has been verified. You can now go online.',
    time: 'Yesterday',
    icon: Icons.verified_outlined,
    isRead: true,
  ),
];

class NotificationsScreen extends StatefulWidget {
  final String portal;

  const NotificationsScreen({super.key, required this.portal});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late List<_NotificationItem> _notifications;
  late List<bool> _readStates;

  bool get _isPatient => widget.portal == 'patient';
  Color get _primary => _isPatient ? kTeal600 : kBlue600;
  Color get _unreadBg => _isPatient ? kTeal50 : kBlue100;

  @override
  void initState() {
    super.initState();
    _notifications = _isPatient ? _patientNotifications : _driverNotifications;
    _readStates = _notifications.map((n) => n.isRead).toList();
  }

  void _markAllRead() {
    setState(() {
      _readStates = List.filled(_notifications.length, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _readStates.any((r) => !r);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: const BackButton(),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Mark all read',
                style: TextStyle(color: _primary, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? const EmptyState(message: 'No notifications yet')
          : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final item = _notifications[index];
                final isRead = _readStates[index];
                return _NotificationTile(
                  item: item,
                  isRead: isRead,
                  primary: _primary,
                  unreadBg: _unreadBg,
                  onTap: () {
                    setState(() => _readStates[index] = true);
                  },
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final _NotificationItem item;
  final bool isRead;
  final Color primary;
  final Color unreadBg;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.item,
    required this.isRead,
    required this.primary,
    required this.unreadBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        color: isRead ? kSurface : unreadBg,
        padding: const EdgeInsets.symmetric(
          horizontal: kSpaceLG,
          vertical: kSpaceMD,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isRead)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: kSpaceSM),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            else
              const SizedBox(width: kSpaceLG),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(kRadiusMD),
              ),
              child: Icon(item.icon, size: 20, color: primary),
            ),
            const SizedBox(width: kSpaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: kFontSmall,
                            fontWeight: FontWeight.w700,
                            color: kText900,
                          ),
                        ),
                      ),
                      const SizedBox(width: kSpaceSM),
                      Text(
                        item.time,
                        style: const TextStyle(
                          fontSize: kFontCaption,
                          color: kText400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: kText600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
