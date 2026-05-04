// Reference UI redesign — hero balance + cyan/pink mini metric cards.
// Plan SC: FR-08 (dashboard).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/ui/money_format.dart';
import '../data/recurring_rule_repository.dart';
import '../domain/dashboard_metrics.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMetrics = ref.watch(dashboardMetricsProvider);
    final pending = ref.watch(syncPendingCountProvider).valueOrNull ?? 0;
    final signedIn = ref.watch(authSignedInProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('머니 로그'),
        actions: [
          if (!signedIn || pending > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: !signedIn
                    ? const _NotSignedInChip()
                    : _PendingChip(count: pending),
              ),
            ),
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: asyncMetrics.when(
        data: (m) => _DashboardBody(metrics: m),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('대시보드 로딩 실패\n$e', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.metrics});

  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        _HeroBalance(metrics: metrics),
        // Design Ref: §5.1 — 반복 거래 도래 배지. isDue 규칙 있을 때만 표시.
        const _RecurringDueBadge(),
        const SizedBox(height: 20),
        _MonthMetricsRow(metrics: metrics),
        const SizedBox(height: 20),
        _AssetBreakdownCard(metrics: metrics),
        const SizedBox(height: 20),
        const _ReportCard(),
      ],
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────────────

class _HeroBalance extends StatelessWidget {
  const _HeroBalance({required this.metrics});

  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = metrics.availableCash;
    final negative = available < 0;
    final color = negative
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '가용 현금',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.formatKrw(available),
              style: theme.textTheme.displayMedium?.copyWith(
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '현금 ${Money.format(metrics.cashAssets)}'
            ' · 카드 ${Money.formatSigned(metrics.creditCardBalance)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Income / Expense mini cards ──────────────────────────────────────────────

class _MonthMetricsRow extends StatelessWidget {
  const _MonthMetricsRow({required this.metrics});

  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _MetricMiniCard(
            label: '이번 달 수입',
            value: metrics.currentMonthIncome,
            icon: Icons.south_west_rounded,
            color: theme.colorScheme.tertiary,
            background: theme.colorScheme.tertiaryContainer,
            sign: '+',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricMiniCard(
            label: '이번 달 지출',
            value: metrics.currentMonthExpense,
            icon: Icons.north_east_rounded,
            color: theme.colorScheme.primary,
            background: theme.colorScheme.primaryContainer,
            sign: '-',
          ),
        ),
      ],
    );
  }
}

class _MetricMiniCard extends StatelessWidget {
  const _MetricMiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
    required this.sign,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final Color background;
  final String sign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$sign${Money.formatKrw(value)}',
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Asset breakdown ──────────────────────────────────────────────────────────

class _AssetBreakdownCard extends StatelessWidget {
  const _AssetBreakdownCard({required this.metrics});

  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = metrics.netWorth;
    final monthNet = metrics.currentMonthNet;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('순자산', style: theme.textTheme.titleMedium),
                Text(
                  Money.formatKrw(net),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Text(
                '이번 달 순증감 ${Money.formatSigned(monthNet)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: monthNet < 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.tertiary,
                ),
              ),
            ),
            Divider(color: theme.colorScheme.outlineVariant, height: 1),
            _BreakdownRow(label: '현금성 자산', value: metrics.cashAssets),
            _BreakdownRow(label: '투자 자산', value: metrics.investmentAssets),
            _BreakdownRow(
              label: '카드 미결제',
              value: metrics.creditCardBalance,
              valueColor: metrics.creditCardBalance < 0
                  ? theme.colorScheme.error
                  : null,
              signed: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.signed = false,
  });

  final String label;
  final int value;
  final Color? valueColor;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = signed ? Money.formatSigned(value) : Money.format(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            text,
            style: theme.textTheme.titleMedium?.copyWith(
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Report Card ──────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  const _ReportCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.card),
      onTap: () => context.push('/reports'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.bar_chart_rounded,
                color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '연간 리포트',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ── Status chips ─────────────────────────────────────────────────────────────

class _PendingChip extends StatelessWidget {
  const _PendingChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotSignedInChip extends StatelessWidget {
  const _NotSignedInChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber, size: 14, color: theme.colorScheme.error),
          const SizedBox(width: 6),
          Text(
            '로그인 필요',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recurring Due Badge ───────────────────────────────────────────────────────

// Design Ref: §5.1 — 반복 거래 도래 배지. dueRecurringRulesProvider watch.
// count > 0일 때만 표시. 탭 → _RecurringDueSheet 모달.
class _RecurringDueBadge extends ConsumerWidget {
  const _RecurringDueBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueRecurringRulesProvider);
    if (due.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const _RecurringDueSheet(),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Row(
            children: [
              Icon(
                Icons.assignment_late_outlined,
                color: theme.colorScheme.onSecondaryContainer,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '반복 거래 ${due.length}건 처리 필요',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Recurring Due Sheet ───────────────────────────────────────────────────────

// Design Ref: §5.2 — RecurringDueSheet. HomeScreen 전용 private.
// "건너뜀": markHandled → badge count 감소 (stream 재계산).
// "입력 화면으로": push /input extra:{templateId} → pop(true) → markHandled.
// 모든 항목 처리 시 ref.listen → 자동 닫힘.
class _RecurringDueSheet extends ConsumerWidget {
  const _RecurringDueSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueRecurringRulesProvider);
    final theme = Theme.of(context);

    ref.listen<List<RecurringRule>>(dueRecurringRulesProvider, (_, rules) {
      if (rules.isEmpty && context.mounted) {
        Navigator.of(context).maybePop();
      }
    });

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('처리할 반복 거래', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '도래한 항목을 확인하거나 건너뛰세요',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ...due.map((rule) => _DueRuleItem(rule: rule, ref: ref)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DueRuleItem extends StatelessWidget {
  const _DueRuleItem({required this.rule, required this.ref});

  final RecurringRule rule;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountText = rule.templateAmount != null
        ? Money.formatKrw(rule.templateAmount!)
        : '금액 미정';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              const Icon(Icons.assignment_outlined, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.templateName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '매월 ${rule.dayOfMonth}일  ·  $amountText',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(56, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () async {
                  await ref
                      .read(recurringRuleRepositoryProvider)
                      .markHandled(rule.id);
                },
                child: const Text('건너뜀'),
              ),
              const SizedBox(width: 4),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(72, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () async {
                  final result = await context.push<bool>(
                    '/input',
                    extra: <String, dynamic>{'templateId': rule.templateId},
                  );
                  if (result == true && context.mounted) {
                    await ref
                        .read(recurringRuleRepositoryProvider)
                        .markHandled(rule.id);
                  }
                },
                child: const Text('입력'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
