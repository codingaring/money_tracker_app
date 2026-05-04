// Design Ref: §5.2 + §5.1 — AnalyticsScreen (월 picker + 달력 + 도너츠 + 라인).
// Plan SC: SC-2 + FR-39~42 (M3 calendar).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/ui/money_format.dart';
import '../../transactions/domain/search_filter.dart';
import '../data/budget_repository.dart';
import 'category_donut_chart.dart';
import 'daily_calendar.dart';
import 'fixed_variable_line_chart.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Always start the donut on the current month (Design §5.2).
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
  }

  /// Plan SC: FR-42 — 셀 탭 → searchFilter에 단일 일자 적용 + 내역 탭 전환.
  void _onDayTap(DateTime day) {
    final next = day.add(const Duration(days: 1));
    final dateLabel = '${day.month}월 ${day.day}일';
    ref.read(searchFilterProvider.notifier).setDateRange(
          DateRange(from: day, to: next, label: dateLabel),
        );
    // GoRouter shell — '/list'로 가면 자동으로 branch 1(내역 탭)로 전환됨.
    context.go('/list');
  }

  @override
  Widget build(BuildContext context) {
    final dailyMap = ref.watch(dailyExpenseMapProvider(_selectedMonth));
    final donut = ref.watch(categoryDonutProvider(_selectedMonth));
    final line = ref.watch(fixedVariableSeriesProvider);
    final overlay = ref.watch(budgetOverlayProvider(_selectedMonth));
    final overlayStatuses = overlay.valueOrNull ?? const <BudgetStatus>[];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('분석')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          _MonthPicker(
            month: _selectedMonth,
            onPrev: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
          ),
          const SizedBox(height: 20),
          _SectionTitle(text: '일별 지출'),
          const SizedBox(height: 4),
          Text(
            '셀을 탭하면 그 날짜의 거래를 볼 수 있어요.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: dailyMap.when(
                loading: () => const _LoadingBox(height: 320),
                error: (e, _) => _ErrorBox(message: '$e'),
                data: (map) => DailyCalendar(
                  month: _selectedMonth,
                  dailyMap: map,
                  onDayTap: _onDayTap,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(text: '카테고리 비중'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: donut.when(
                loading: () => const _LoadingBox(height: 280),
                error: (e, _) => _ErrorBox(message: '$e'),
                data: (segments) => CategoryDonutChart(segments: segments),
              ),
            ),
          ),
          if (overlayStatuses.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionTitle(text: '예산 현황'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _BudgetOverlaySection(statuses: overlayStatuses),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _SectionTitle(text: '고정비 vs 변동비'),
          const SizedBox(height: 4),
          Text(
            '최근 6개월',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: line.when(
                loading: () => const _LoadingBox(height: 280),
                error: (e, _) => _ErrorBox(message: '$e'),
                data: (series) => FixedVariableLineChart(series: series),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'expense 거래만 집계됩니다.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  bool _isCurrentMonth() {
    final now = DateTime.now();
    return now.year == month.year && now.month == month.month;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onPrev,
            tooltip: '이전 달',
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${month.year}년 ${month.month}월',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _isCurrentMonth() ? null : onNext,
            tooltip: '다음 달',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text('차트 로드 실패\n$message'),
    );
  }
}

// Design Ref: §5.6 — _BudgetOverlaySection. 예산 있는 카테고리만 표시 (ratio desc 정렬).
class _BudgetOverlaySection extends StatelessWidget {
  const _BudgetOverlaySection({required this.statuses});
  final List<BudgetStatus> statuses;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < statuses.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _BudgetRow(status: statuses[i]),
        ],
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.status});
  final BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOver = status.isOver;
    final barColor =
        isOver ? theme.colorScheme.error : theme.colorScheme.primary;
    final pct = (status.ratio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                status.categoryName,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (isOver)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.warning_rounded,
                    size: 16, color: theme.colorScheme.error),
              ),
            Text(
              '$pct%',
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
            value: status.ratio.clamp(0.0, 1.0),
            backgroundColor: theme.colorScheme.surfaceContainer,
            color: barColor,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${Money.formatKrw(status.spent)} / ${Money.formatKrw(status.limit)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
