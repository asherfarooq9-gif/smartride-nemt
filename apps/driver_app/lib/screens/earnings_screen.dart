import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/providers.dart';
import '../core/theme.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rideHistoryProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(rideHistoryProvider);

    if (history.loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Earnings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final now = DateTime.now();
    final todayRides = history.rides.where((r) {
      final dt = DateTime.tryParse(r['requested_at'] as String? ?? '');
      return dt != null && dt.day == now.day && dt.month == now.month && dt.year == now.year;
    }).toList();

    final weekRides = history.rides.where((r) {
      final dt = DateTime.tryParse(r['requested_at'] as String? ?? '');
      if (dt == null) return false;
      return now.difference(dt).inDays < 7;
    }).toList();

    final monthRides = history.rides.where((r) {
      final dt = DateTime.tryParse(r['requested_at'] as String? ?? '');
      return dt != null && dt.month == now.month && dt.year == now.year;
    }).toList();

    double sumFares(List<Map<String, dynamic>> rides) =>
        rides.where((r) => r['final_fare_pkr'] != null).fold(0.0, (s, r) => s + (r['final_fare_pkr'] as num).toDouble());

    final todayEarnings = sumFares(todayRides);
    final weekEarnings = sumFares(weekRides);
    final monthEarnings = sumFares(monthRides);

    final avgFare = history.completedCount > 0 ? history.totalEarnings / history.completedCount : 0.0;

    // Build last 7 days bar data
    final barGroups = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final dayRides = history.rides.where((r) {
        final dt = DateTime.tryParse(r['requested_at'] as String? ?? '');
        return dt != null && dt.day == day.day && dt.month == day.month && dt.year == day.year && r['final_fare_pkr'] != null;
      });
      final earned = dayRides.fold(0.0, (s, r) => s + (r['final_fare_pkr'] as num).toDouble());
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(toY: earned, color: kGreen, width: 18, borderRadius: BorderRadius.circular(6)),
        ],
      );
    });

    final dayLabels = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[day.weekday - 1];
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary cards
          Row(children: [
            Expanded(child: _EarningCard(label: "Today", value: todayEarnings, color: kGreen)),
            const SizedBox(width: 10),
            Expanded(child: _EarningCard(label: "This Week", value: weekEarnings, color: kBlue)),
            const SizedBox(width: 10),
            Expanded(child: _EarningCard(label: "This Month", value: monthEarnings, color: kAmber)),
          ]),
          const SizedBox(height: 20),

          // Stats row
          Row(children: [
            Expanded(child: _StatTile(label: 'Total Rides', value: '${history.rides.length}', icon: Icons.directions_car_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(label: 'Emergency', value: '${history.emergencyCount}', icon: Icons.emergency_rounded, color: kRed)),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(label: 'Avg Fare', value: 'PKR ${avgFare.toStringAsFixed(0)}', icon: Icons.payments_rounded, color: kGreen)),
          ]),
          const SizedBox(height: 24),

          // Bar chart
          const Text('Last 7 Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            height: 220,
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: barGroups.every((g) => g.barRods.first.toY == 0)
                ? const Center(child: Text('No earnings this week', style: TextStyle(color: Colors.grey)))
                : BarChart(
                    BarChartData(
                      barGroups: barGroups,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (v) => const FlLine(color: Color(0xFFE5E7EB), strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) => Text(
                              dayLabels[v.toInt()],
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (v, _) => Text(
                              v == 0 ? '' : '${v.toInt()}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                            'PKR ${rod.toY.toStringAsFixed(0)}',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 20),

          // Trip breakdown
          const Text('Trip Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          _BreakdownCard(
            label: 'Emergency Rides',
            count: history.emergencyCount,
            total: history.rides.isNotEmpty ? history.emergencyCount / history.rides.length : 0,
            color: kRed,
          ),
          const SizedBox(height: 8),
          _BreakdownCard(
            label: 'Scheduled Rides',
            count: history.rides.length - history.emergencyCount,
            total: history.rides.isNotEmpty ? (history.rides.length - history.emergencyCount) / history.rides.length : 0,
            color: kBlue,
          ),
        ],
      ),
    );
  }
}

class _EarningCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _EarningCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('PKR ${value.toStringAsFixed(0)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.icon, this.color = kBlue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final String label;
  final int count;
  final double total;
  final Color color;
  const _BreakdownCard({required this.label, required this.count, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('$count rides', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text('${(total * 100).toStringAsFixed(0)}% of total trips', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
