// Design Ref: §5.5 — BudgetComparisonSection. 예산 vs 실제 연간 평균.
// Plan SC: FR-80. data.isEmpty → 섹션 전체 숨김. isAvgOver → error 색상.

import 'package:flutter/material.dart';

import '../../../core/ui/money_format.dart';
import '../data/analytics_repository.dart';

class BudgetComparisonSection extends StatelessWidget {
  const BudgetComparisonSection({super.key, required this.data});

  final List<BudgetVsActual> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var i = 0; i < data.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _BudgetRow(item: data[i]),
        ],
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.item});

  final BudgetVsActual item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOver = item.isAvgOver;
    final barColor =
        isOver ? theme.colorScheme.error : theme.colorScheme.primary;
    final pct = (item.avgRatio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.categoryName,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (isOver)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.warning_rounded,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
              ),
            Text(
              '$pct% avg',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isOver ? theme.colorScheme.error : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: item.avgRatio.clamp(0.0, 1.0),
            backgroundColor: theme.colorScheme.surfaceContainer,
            color: barColor,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '월평균 ${Money.formatKrw(item.avgMonthlySpent)} / 예산 ${Money.formatKrw(item.monthlyBudget)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
