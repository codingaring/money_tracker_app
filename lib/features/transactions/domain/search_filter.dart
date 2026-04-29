// Design Ref: §6 + §5.4 — Immutable filter state for ListScreen search.
// Plan SC: SC-3.

import 'transaction.dart';

/// Date range. `from` inclusive, `to` exclusive (caller passes month-start
/// pair to express a calendar month). NULL endpoints mean unbounded.
class DateRange {
  const DateRange({this.from, this.to, this.label});

  final DateTime? from;
  final DateTime? to;

  /// Human label for the chip (e.g., "이번 달", "직접 지정"). Used purely for
  /// UI — when null, the chip falls back to "전체기간".
  final String? label;

  bool get isEmpty => from == null && to == null;
}

class SearchFilter {
  const SearchFilter({
    this.keyword = '',
    this.dateRange = const DateRange(),
    this.accountId,
    this.accountName,
    this.categoryId,
    this.categoryName,
    this.type,
  });

  final String keyword;
  final DateRange dateRange;
  final int? accountId;
  final String? accountName;
  final int? categoryId;
  final String? categoryName;
  final TxType? type;

  /// `true` when no axis is constrained — caller falls back to the unfiltered
  /// reactive stream (lower latency, free updates).
  bool get isEmpty =>
      keyword.trim().isEmpty &&
      dateRange.isEmpty &&
      accountId == null &&
      categoryId == null &&
      type == null;

  SearchFilter copyWith({
    String? keyword,
    DateRange? dateRange,
    int? accountId,
    String? accountName,
    int? categoryId,
    String? categoryName,
    TxType? type,
    bool clearAccount = false,
    bool clearCategory = false,
    bool clearType = false,
    bool clearDate = false,
  }) {
    return SearchFilter(
      keyword: keyword ?? this.keyword,
      dateRange: clearDate ? const DateRange() : (dateRange ?? this.dateRange),
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      accountName: clearAccount ? null : (accountName ?? this.accountName),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      categoryName: clearCategory ? null : (categoryName ?? this.categoryName),
      type: clearType ? null : (type ?? this.type),
    );
  }
}
