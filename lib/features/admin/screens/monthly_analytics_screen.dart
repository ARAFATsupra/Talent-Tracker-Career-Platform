import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_constants.dart';
import '../providers/admin_providers.dart';

/// S-34 — Monthly Analytics Screen.
/// "View monthly trend charts for registrations and placements. Line
/// chart for registrations per month, bar chart for placements per
/// month, date range filter."
///
/// 🔶 "Date range filter" — monthlyRegistrationsProvider/
/// monthlyPlacementsProvider are fixed to a trailing 12-month window
/// (the natural unit for a "monthly trend" chart). A true arbitrary
/// date-range filter would change the BUCKETING granularity (weekly?
/// daily? for a 2-month range vs. monthly for a 3-year range), which
/// the spec doesn't specify — scoped to the well-defined "last 12
/// months" case rather than guessing at that behavior.
class MonthlyAnalyticsScreen extends ConsumerWidget {
  const MonthlyAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registrations = ref.watch(monthlyRegistrationsProvider);
    final placements = ref.watch(monthlyPlacementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Registrations — last 12 months', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: _RegistrationsLineChart(data: registrations),
          ),
          const SizedBox(height: 28),
          Text('Placements — last 12 months', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: _PlacementsBarChart(data: placements),
          ),
        ],
      ),
    );
  }
}

class _RegistrationsLineChart extends StatelessWidget {
  const _RegistrationsLineChart({required this.data});

  final List<MonthlyCount> data;

  @override
  Widget build(BuildContext context) {
    if (data.every((d) => d.count == 0)) {
      return const Center(child: Text('No registrations recorded yet.'));
    }

    final maxCount = data.map((d) => d.count).reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: (maxCount + 1).toDouble(),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) => _MonthLabel(data: data, index: value.toInt()),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i].count.toDouble())],
            isCurved: true,
            color: AppColors.primaryBlue,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: AppColors.primaryBlue.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }
}

class _PlacementsBarChart extends StatelessWidget {
  const _PlacementsBarChart({required this.data});

  final List<MonthlyCount> data;

  @override
  Widget build(BuildContext context) {
    if (data.every((d) => d.count == 0)) {
      return const Center(child: Text('No placements recorded yet.'));
    }

    final maxCount = data.map((d) => d.count).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: (maxCount + 1).toDouble(),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) => _MonthLabel(data: data, index: value.toInt()),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < data.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(toY: data[i].count.toDouble(), color: AppColors.secondaryTeal, width: 14),
              ],
            ),
        ],
      ),
    );
  }
}

class _MonthLabel extends StatelessWidget {
  const _MonthLabel({required this.data, required this.index});

  final List<MonthlyCount> data;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (index < 0 || index >= data.length) return const SizedBox.shrink();
    // Show every other month's label to avoid crowding a 12-point axis.
    if (index.isOdd) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(DateFormat('MMM').format(data[index].month), style: const TextStyle(fontSize: 10)),
    );
  }
}
