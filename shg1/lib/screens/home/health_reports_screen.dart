import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class HealthReportsScreen extends StatefulWidget {
  const HealthReportsScreen({super.key});

  @override
  State<HealthReportsScreen> createState() => _HealthReportsScreenState();
}

class _HealthReportsScreenState extends State<HealthReportsScreen> {
  int _rangeIndex = 1; // 0=Daily, 1=Weekly, 2=Monthly
  final _ranges = const ['Daily', 'Weekly', 'Monthly'];

  // Mock trend data
  final List<FlSpot> _hrTrend = const [
    FlSpot(0, 74), FlSpot(1, 78), FlSpot(2, 76), FlSpot(3, 82),
    FlSpot(4, 79), FlSpot(5, 75), FlSpot(6, 77),
  ];
  final List<FlSpot> _spo2Trend = const [
    FlSpot(0, 97), FlSpot(1, 98), FlSpot(2, 98), FlSpot(3, 96),
    FlSpot(4, 98), FlSpot(5, 99), FlSpot(6, 98),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        surfaceTintColor: Colors.transparent,
        title: const Text('Health Reports', style: TextStyle(color: AppColors.white)),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(_ranges.length, (i) {
                  final selected = i == _rangeIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(_ranges[i], style: TextStyle(color: selected ? AppColors.white : AppColors.grey500, fontWeight: FontWeight.w600)),
                      selected: selected,
                      onSelected: (_) => setState(() => _rangeIndex = i),
                      selectedColor: AppColors.teal,
                      backgroundColor: const Color(0xFF1A2A2A),
                      side: BorderSide(color: selected ? AppColors.teal.withOpacity(0.5) : AppColors.grey600.withOpacity(0.3)),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Heart Rate Trend'),
              _TrendChart(spots: _hrTrend, color: AppColors.teal, unit: 'BPM'),
              const SizedBox(height: 24),
              const SectionHeader(title: 'SpO₂ Trend'),
              _TrendChart(spots: _spo2Trend, color: AppColors.black, unit: '%'),
              const SizedBox(height: 24),
              const SectionHeader(title: 'AI Prediction History'),
              _historyRow('Mon', 'Normal', false),
              _historyRow('Tue', 'Normal', false),
              _historyRow('Wed', 'Elevated Risk', true),
              _historyRow('Thu', 'Normal', false),
              const SizedBox(height: 8),
              const SectionHeader(title: 'Emergency Events'),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.grey600.withOpacity(0.3)),
                ),
                child: const Text('No emergency events this period.', style: TextStyle(color: AppColors.grey500, fontSize: 13)),
              ),
              const SizedBox(height: 8),
              const SectionHeader(title: 'Medicine Adherence'),
              StatTile(label: 'This period', value: '95% taken on time', icon: Icons.medication_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyRow(String day, String status, bool risk) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (risk ? AppColors.warn : AppColors.teal).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.white)),
          Row(
            children: [
              Icon(risk ? Icons.warning_rounded : Icons.check_circle_rounded,
                  size: 16, color: risk ? AppColors.warn : AppColors.teal),
              const SizedBox(width: 6),
              Text(status, style: TextStyle(color: risk ? AppColors.warn : AppColors.teal, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<FlSpot> spots;
  final Color color;
  final String unit;
  const _TrendChart({required this.spots, required this.color, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(8, 14, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: color.withOpacity(0.08)),
            ),
          ],
        ),
      ),
    );
  }
}
