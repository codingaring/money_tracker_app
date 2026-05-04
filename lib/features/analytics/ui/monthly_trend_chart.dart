// Design Ref: §5.2 — MonthlyTrendChart. 수입/지출/순이익 3선 라인 차트.
// Plan SC: FR-77. fl_chart LineChart. FixedVariableLineChart 패턴 재사용.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/analytics_repository.dart';

class MonthlyTrendChart extends StatelessWidget {
  const MonthlyTrendChart({super.key, required this.data});

  final List<MonthlyTrend> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = data.any((d) => d.income > 0 || d.expense > 0);
    if (!hasData) {
      return _EmptyLine(theme: theme);
    }

    final maxY = data
        .expand((d) => [d.income.toDouble(), d.expense.toDouble()])
        .fold<double>(0, (a, b) => a > b ? a : b);
    final yMax = maxY <= 0 ? 1.0 : maxY * 1.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: yMax,
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= data.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${data[i].month}월',
                          style: theme.textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56,
                    getTitlesWidget: (value, meta) {
                      final manwon = (value / 10000).round();
                      return Text(
                        manwon == 0 ? '0' : '$manwon만',
                        style: theme.textTheme.bodySmall,
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: theme.colorScheme.outlineVariant,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                _line(
                  data: [
                    for (var i = 0; i < data.length; i++)
                      FlSpot(i.toDouble(), data[i].income.toDouble()),
                  ],
                  color: theme.colorScheme.primary,
                ),
                _line(
                  data: [
                    for (var i = 0; i < data.length; i++)
                      FlSpot(i.toDouble(), data[i].expense.toDouble()),
                  ],
                  color: theme.colorScheme.error,
                ),
                _line(
                  data: [
                    for (var i = 0; i < data.length; i++)
                      FlSpot(i.toDouble(), data[i].net.toDouble()),
                  ],
                  color: theme.colorScheme.tertiary,
                  dashed: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _LegendDot(color: theme.colorScheme.primary, label: '수입'),
            const SizedBox(width: 16),
            _LegendDot(color: theme.colorScheme.error, label: '지출'),
            const SizedBox(width: 16),
            _LegendDot(color: theme.colorScheme.tertiary, label: '순이익'),
          ],
        ),
      ],
    );
  }

  LineChartBarData _line({
    required List<FlSpot> data,
    required Color color,
    bool dashed = false,
  }) {
    return LineChartBarData(
      isCurved: false,
      spots: data,
      barWidth: dashed ? 1.5 : 2.5,
      color: color,
      dashArray: dashed ? [4, 4] : null,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 3,
          color: color,
          strokeWidth: 0,
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.show_chart_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            '아직 거래 데이터가 없습니다',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
