// Design Ref: §5.2 — Category donut. Top 5 + "기타"합산.
// Plan SC: SC-2 (월별 카테고리 도너츠).

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/money_format.dart';
import '../domain/category_segment.dart';

class CategoryDonutChart extends StatelessWidget {
  const CategoryDonutChart({super.key, required this.segments});

  final List<CategorySegment> segments;

  static const _topN = 5;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return const _EmptyDonut();
    }
    final theme = Theme.of(context);
    final visible = _collapseTail(segments);
    final total = segments.fold<int>(0, (s, e) => s + e.totalAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 56,
              sections: [
                for (var i = 0; i < visible.length; i++)
                  PieChartSectionData(
                    value: visible[i].totalAmount.toDouble(),
                    title: '',
                    radius: 36,
                    color: _colorFor(theme, i),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...visible.asMap().entries.map(
              (e) => _LegendRow(
                color: _colorFor(theme, e.key),
                label: e.value.categoryName,
                amount: e.value.totalAmount,
                ratio: total == 0 ? 0 : e.value.totalAmount / total,
              ),
            ),
      ],
    );
  }

  /// Keeps top N as-is, sums the rest into a single "기타" bucket.
  /// Input must already be sorted desc by [CategorySegment.totalAmount].
  List<CategorySegment> _collapseTail(List<CategorySegment> sorted) {
    if (sorted.length <= _topN) return sorted;
    final keep = sorted.take(_topN).toList();
    final tail = sorted.skip(_topN);
    final tailTotal = tail.fold<int>(0, (s, e) => s + e.totalAmount);
    if (tailTotal == 0) return keep;
    keep.add(
      CategorySegment(
        categoryId: -1,
        categoryName: '기타',
        isFixed: false,
        totalAmount: tailTotal,
      ),
    );
    return keep;
  }

  Color _colorFor(ThemeData theme, int i) {
    // Material 3 color rotation. Stable mapping per index keeps legend ↔ slice
    // alignment consistent within a single render.
    final cs = theme.colorScheme;
    const palette = [
      _PaletteRef.primary,
      _PaletteRef.secondary,
      _PaletteRef.tertiary,
      _PaletteRef.primaryContainer,
      _PaletteRef.secondaryContainer,
      _PaletteRef.tertiaryContainer,
    ];
    return switch (palette[i % palette.length]) {
      _PaletteRef.primary => cs.primary,
      _PaletteRef.secondary => cs.secondary,
      _PaletteRef.tertiary => cs.tertiary,
      _PaletteRef.primaryContainer => cs.primaryContainer,
      _PaletteRef.secondaryContainer => cs.secondaryContainer,
      _PaletteRef.tertiaryContainer => cs.tertiaryContainer,
    };
  }
}

enum _PaletteRef {
  primary,
  secondary,
  tertiary,
  primaryContainer,
  secondaryContainer,
  tertiaryContainer,
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.amount,
    required this.ratio,
  });

  final Color color;
  final String label;
  final int amount;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(ratio * 100).round()}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            Money.formatKrw(amount),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDonut extends StatelessWidget {
  const _EmptyDonut();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.donut_large_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            '이 달에는 거래가 없습니다',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
