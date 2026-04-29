// Design Ref: §5.2 — 고정/변동 라인 차트 (최근 6개월).
// Plan SC: SC-2 (고정/변동 분리 추이).

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/money_format.dart';
import '../domain/monthly_split_series.dart';

class FixedVariableLineChart extends StatelessWidget {
  const FixedVariableLineChart({super.key, required this.series});

  final List<MonthlySplitSeries> series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (series.isEmpty) {
      return _EmptyLine(theme: theme);
    }
    final maxY = series
        .map((s) => s.fixedAmount > s.variableAmount
            ? s.fixedAmount
            : s.variableAmount)
        .fold<int>(0, (a, b) => a > b ? a : b)
        .toDouble();
    // Round up to a clean grid step. 0 budget would crash fl_chart; floor at 1.
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
                      if (i < 0 || i >= series.length) {
                        return const SizedBox.shrink();
                      }
                      // Display "MM월" — full YYYY-MM label is too crowded.
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${int.parse(series[i].yearMonth.substring(5))}월',
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
                      // Show in 만원 (10K) units for readability.
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
                    for (var i = 0; i < series.length; i++)
                      FlSpot(i.toDouble(), series[i].fixedAmount.toDouble()),
                  ],
                  color: theme.colorScheme.primary,
                ),
                _line(
                  data: [
                    for (var i = 0; i < series.length; i++)
                      FlSpot(
                        i.toDouble(),
                        series[i].variableAmount.toDouble(),
                      ),
                  ],
                  color: theme.colorScheme.tertiary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _LegendDot(color: theme.colorScheme.primary, label: '고정비'),
            const SizedBox(width: 16),
            _LegendDot(color: theme.colorScheme.tertiary, label: '변동비'),
          ],
        ),
        const SizedBox(height: 8),
        ..._monthlyLabels(),
      ],
    );
  }

  LineChartBarData _line({required List<FlSpot> data, required Color color}) {
    return LineChartBarData(
      isCurved: false,
      spots: data,
      barWidth: 2.5,
      color: color,
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

  List<Widget> _monthlyLabels() {
    return [
      for (final s in series)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              return Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      _shortMonth(s.yearMonth),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '고정 ${Money.formatKrw(s.fixedAmount)} / 변동 ${Money.formatKrw(s.variableAmount)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
    ];
  }

  String _shortMonth(String yearMonth) {
    final mm = int.parse(yearMonth.substring(5));
    return '$mm월';
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
            '추이를 그릴 데이터가 부족합니다',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
