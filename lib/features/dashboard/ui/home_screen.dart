// Reference UI redesign — hero balance + cyan/pink mini metric cards.
// Plan SC: FR-08 (dashboard).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/ui/money_format.dart';
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
        title: const Text('로그 머니'),
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
        const SizedBox(height: 20),
        _MonthMetricsRow(metrics: metrics),
        const SizedBox(height: 20),
        _AssetBreakdownCard(metrics: metrics),
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
    final color = negative ? theme.colorScheme.error : theme.colorScheme.onSurface;

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
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
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
                Text('순자산',
                    style: theme.textTheme.titleMedium),
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
          Text(label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
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
          Icon(Icons.cloud_off,
              size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text('$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              )),
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
          Icon(Icons.warning_amber,
              size: 14, color: theme.colorScheme.error),
          const SizedBox(width: 6),
          Text('로그인 필요',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}
