// Design Ref: §5.3 — MonthlyCategoryBarChart. 월별 카테고리 지출 GroupedBarChart.
// Plan SC: FR-78. 상위 5개 카테고리 + 기타 합산. fl_chart BarChart.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/money_format.dart';
import '../data/analytics_repository.dart';

class MonthlyCategoryBarChart extends StatelessWidget {
  const MonthlyCategoryBarChart({super.key, required this.data});

  final List<MonthlyCategorySpend> data;

  static const _maxCategories = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) {
      return _EmptyBar(theme: theme);
    }

    // 연간 합계 기준 상위 N개 카테고리 선정.
    final totals = <int, int>{};
    for (final d in data) {
      totals[d.categoryId] = (totals[d.categoryId] ?? 0) + d.amount;
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topIds = sorted.take(_maxCategories).map((e) => e.key).toList();

    // 카테고리별 색상 (colorScheme 순환).
    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.error,
      theme.colorScheme.primaryContainer,
      theme.colorScheme.outlineVariant,
    ];

    // 이름 맵 (categoryId → name)
    final nameMap = <int, String>{};
    for (final d in data) {
      nameMap[d.categoryId] = d.categoryName;
    }

    // 월별 그룹 데이터 구성
    final monthGroups = <int, Map<int, int>>{};
    for (var m = 1; m <= 12; m++) {
      monthGroups[m] = {};
    }
    for (final d in data) {
      final catKey = topIds.contains(d.categoryId) ? d.categoryId : -1;
      final prev = monthGroups[d.month]![catKey] ?? 0;
      monthGroups[d.month]![catKey] = prev + d.amount;
    }

    // 최대 Y 계산
    double maxY = 0;
    for (final m in monthGroups.values) {
      final total = m.values.fold<int>(0, (a, b) => a + b).toDouble();
      if (total > maxY) maxY = total;
    }
    if (maxY <= 0) maxY = 1;
    maxY *= 1.15;

    // BarChart groups (1월 ~ 12월)
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < 12; i++) {
      final m = i + 1;
      final mData = monthGroups[m]!;
      final bars = <BarChartRodData>[];
      int stackStart = 0;
      // 상위 카테고리 순서대로 stacked bar
      for (var ci = 0; ci < topIds.length; ci++) {
        final id = topIds[ci];
        final amount = mData[id] ?? 0;
        if (amount > 0) {
          bars.add(BarChartRodData(
            toY: (stackStart + amount).toDouble(),
            fromY: stackStart.toDouble(),
            color: colors[ci % colors.length],
            width: 10,
            borderRadius: ci == topIds.length - 1
                ? const BorderRadius.vertical(top: Radius.circular(3))
                : BorderRadius.zero,
          ));
          stackStart += amount;
        }
      }
      // 기타
      final other = mData[-1] ?? 0;
      if (other > 0) {
        bars.add(BarChartRodData(
          toY: (stackStart + other).toDouble(),
          fromY: stackStart.toDouble(),
          color: colors[5],
          width: 10,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ));
      }
      groups.add(BarChartGroupData(
        x: i,
        barRods: bars.isEmpty
            ? [BarChartRodData(toY: 0, color: Colors.transparent, width: 10)]
            : bars,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              barGroups: groups,
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
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${value.toInt() + 1}',
                          style: theme.textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
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
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final amount = (rod.toY - rod.fromY).round();
                    return BarTooltipItem(
                      Money.formatKrw(amount),
                      theme.textTheme.bodySmall!,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (var i = 0; i < topIds.length; i++)
              _LegendChip(
                color: colors[i % colors.length],
                label: nameMap[topIds[i]] ?? '?',
                theme: theme,
              ),
            if (sorted.length > _maxCategories)
              _LegendChip(
                color: colors[5],
                label: '기타',
                theme: theme,
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.label,
    required this.theme,
  });

  final Color color;
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _EmptyBar extends StatelessWidget {
  const _EmptyBar({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            '아직 지출 데이터가 없습니다',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
