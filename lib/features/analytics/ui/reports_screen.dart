// Design Ref: §5.1 — ReportsScreen. 5번째 탭 메인.
// Plan SC: FR-76 연도 선택 헤더 + 4개 섹션 (연간 요약 / 월별 추이 / 카테고리 바 / 예산 비교).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import 'budget_comparison_section.dart';
import 'monthly_category_bar_chart.dart';
import 'monthly_trend_chart.dart';
import 'year_summary_card.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(yearSummaryProvider(_selectedYear));
    final trend = ref.watch(monthlyTrendProvider(_selectedYear));
    final catSpend = ref.watch(monthlyCategorySpendProvider(_selectedYear));
    final bva = ref.watch(budgetVsActualProvider(_selectedYear));

    return Scaffold(
      appBar: AppBar(title: const Text('리포트')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          _YearPicker(
            year: _selectedYear,
            onPrev: () => setState(() => _selectedYear--),
            onNext: () => setState(() => _selectedYear++),
          ),
          const SizedBox(height: 16),
          summary.when(
            loading: () => const _LoadingBox(height: 80),
            error: (e, _) => _ErrorBox(message: '$e'),
            data: (s) => YearSummaryCard(summary: s),
          ),
          const SizedBox(height: 24),
          _SectionTitle(text: '월별 수입 / 지출 추이'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: trend.when(
                loading: () => const _LoadingBox(height: 220),
                error: (e, _) => _ErrorBox(message: '$e'),
                data: (data) => MonthlyTrendChart(data: data),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(text: '월별 카테고리 지출'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: catSpend.when(
                loading: () => const _LoadingBox(height: 200),
                error: (e, _) => _ErrorBox(message: '$e'),
                data: (data) => MonthlyCategoryBarChart(data: data),
              ),
            ),
          ),
          bva.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (data) {
              if (data.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _SectionTitle(text: '예산 vs 실제 평균'),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: BudgetComparisonSection(data: data),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _YearPicker extends StatelessWidget {
  const _YearPicker({
    required this.year,
    required this.onPrev,
    required this.onNext,
  });

  final int year;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrentYear = year >= DateTime.now().year;
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
            tooltip: '이전 연도',
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$year년',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: isCurrentYear ? null : onNext,
            tooltip: '다음 연도',
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
      child: Text('로드 실패\n$message'),
    );
  }
}
