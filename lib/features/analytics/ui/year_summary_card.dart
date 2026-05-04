// Design Ref: §5.4 — YearSummaryCard. 연간 요약 카드.
// Plan SC: FR-79 총수입/총지출/저축률 3칸 + 전년 대비 delta.

import 'package:flutter/material.dart';

import '../../../core/ui/money_format.dart';
import '../data/analytics_repository.dart';

class YearSummaryCard extends StatelessWidget {
  const YearSummaryCard({super.key, required this.summary});

  final YearSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _SummaryColumn(
              label: '총수입',
              amount: summary.totalIncome,
              delta: summary.incomeGrowth,
              positiveIsGood: true,
              theme: theme,
            ),
            _VerticalDivider(theme: theme),
            _SummaryColumn(
              label: '총지출',
              amount: summary.totalExpense,
              delta: summary.expenseGrowth,
              positiveIsGood: false,
              theme: theme,
            ),
            _VerticalDivider(theme: theme),
            _SavingsColumn(summary: summary, theme: theme),
          ],
        ),
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({
    required this.label,
    required this.amount,
    required this.delta,
    required this.positiveIsGood,
    required this.theme,
  });

  final String label;
  final int amount;
  final int? delta;
  final bool positiveIsGood;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            Money.formatKrw(amount),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          if (delta != null) ...[
            const SizedBox(height: 4),
            _DeltaBadge(delta: delta!, positiveIsGood: positiveIsGood, theme: theme),
          ],
        ],
      ),
    );
  }
}

class _SavingsColumn extends StatelessWidget {
  const _SavingsColumn({required this.summary, required this.theme});

  final YearSummary summary;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final pct = (summary.savingsRate * 100).round();
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('저축률', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            '$pct%',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: pct >= 20
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '순이익 ${Money.formatKrw(summary.netIncome)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({
    required this.delta,
    required this.positiveIsGood,
    required this.theme,
  });

  final int delta;
  final bool positiveIsGood;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isPositive = delta > 0;
    final isGood = positiveIsGood ? isPositive : !isPositive;
    final color = isGood ? theme.colorScheme.primary : theme.colorScheme.error;
    final arrow = isPositive ? '▲' : '▼';
    final abs = delta.abs();
    return Text(
      '$arrow ${Money.formatKrw(abs)}',
      style: theme.textTheme.bodySmall?.copyWith(color: color),
      textAlign: TextAlign.center,
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 56,
      color: theme.colorScheme.outlineVariant,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
