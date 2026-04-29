// Design Ref: §4.1 — MonthlySplitSeries value object for line chart.
// Plan SC: SC-2 (고정/변동 분리 라인 차트).

class MonthlySplitSeries {
  const MonthlySplitSeries({
    required this.yearMonth,
    required this.fixedAmount,
    required this.variableAmount,
  });

  /// `YYYY-MM` (e.g., `2026-04`). Stable sort key for chronological plot.
  final String yearMonth;
  final int fixedAmount;
  final int variableAmount;

  int get totalExpense => fixedAmount + variableAmount;
}
