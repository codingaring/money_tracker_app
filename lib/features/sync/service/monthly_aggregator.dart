// Design Ref: §4.7 — Pure aggregation. No DB / network access.
// Plan SC: monthly_summary push (FR-12).
//
// Computes [months] consecutive monthly summaries ending at "now", in
// ascending year_month order. netWorthEnd is computed by walking backward
// from current accounts.balance sum, undoing each month's stored deltas.

import '../../../core/db/app_database.dart';
import '../../transactions/domain/transaction.dart';

class MonthlySummary {
  const MonthlySummary({
    required this.yearMonth,
    required this.income,
    required this.expense,
    required this.netWorthEnd,
  });

  /// 'YYYY-MM'.
  final String yearMonth;
  final int income;
  final int expense;
  int get net => income - expense;
  final int netWorthEnd;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MonthlySummary &&
          other.yearMonth == yearMonth &&
          other.income == income &&
          other.expense == expense &&
          other.netWorthEnd == netWorthEnd);

  @override
  int get hashCode =>
      Object.hash(yearMonth, income, expense, netWorthEnd);

  @override
  String toString() =>
      'MonthlySummary($yearMonth, in=$income, out=$expense, net=$net, end=$netWorthEnd)';
}

class MonthlyAggregator {
  const MonthlyAggregator._();

  /// [transactions] should be the non-deleted set (Repository.watchAll already
  /// filters). [accounts] is the current snapshot. [months] is the window size
  /// (12 by design §4.6). [now] defaults to DateTime.now() — pass for testing.
  static List<MonthlySummary> compute({
    required List<TxRow> transactions,
    required List<Account> accounts,
    required int months,
    DateTime? now,
  }) {
    if (months <= 0) return const [];
    final today = now ?? DateTime.now();
    final monthsList = _lastNMonths(today, months); // ascending

    // Group transactions by year_month.
    final byMonth = <String, List<TxRow>>{};
    for (final tx in transactions) {
      if (tx.deletedAt != null) continue;
      final ym = formatYearMonth(tx.occurredAt);
      byMonth.putIfAbsent(ym, () => []).add(tx);
    }

    final currentNetWorth = accounts.fold<int>(0, (sum, a) => sum + a.balance);

    // Walk backward from "now" to fill netWorthEnd per month.
    final result = <MonthlySummary>[];
    var runningNetWorth = currentNetWorth;
    for (final ym in monthsList.reversed) {
      final tx = byMonth[ym] ?? const <TxRow>[];
      final income = _sumWhere(tx, TxType.income);
      final expense = _sumWhere(tx, TxType.expense);
      final monthDelta =
          tx.fold<int>(0, (s, t) => s + (t.fromDelta ?? 0) + (t.toDelta ?? 0));

      result.insert(0, MonthlySummary(
        yearMonth: ym,
        income: income,
        expense: expense,
        netWorthEnd: runningNetWorth,
      ));
      runningNetWorth -= monthDelta;
    }
    return result;
  }

  static int _sumWhere(List<TxRow> tx, TxType type) {
    var s = 0;
    for (final t in tx) {
      if (t.type == type) s += t.amount;
    }
    return s;
  }

  static String formatYearMonth(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  /// Returns last [n] year_months in ascending order, ending at month containing [today].
  static List<String> _lastNMonths(DateTime today, int n) {
    final result = <String>[];
    for (int i = n - 1; i >= 0; i--) {
      // Dart auto-rolls negative months back into prior year — perfect for us.
      final d = DateTime(today.year, today.month - i);
      result.add(formatYearMonth(d));
    }
    return result;
  }
}
