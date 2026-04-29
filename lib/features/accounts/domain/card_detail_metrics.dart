// Design Ref: §4.2 — UI domain object for CardDetailScreen.
// Plan SC: SC-1 (카드 결제 예정 D-day + 예상 금액 정확).

import '../../../core/db/app_database.dart';

class CardDetailMetrics {
  const CardDetailMetrics({
    required this.account,
    required this.currentMonthCharges,
    required this.nextDueDate,
    required this.daysUntilDue,
    required this.expectedPayment,
    required this.recentCharges,
  });

  final Account account;

  /// 이번 달 해당 카드로 발생한 expense 합계 (절댓값, KRW).
  final int currentMonthCharges;

  /// 다음 결제 예정일. due_day가 NULL이거나 type≠credit_card이면 NULL.
  final DateTime? nextDueDate;

  /// 오늘부터 [nextDueDate]까지 일수. NULL일 때 -1.
  /// 0이면 "오늘 결제일", 음수는 발생하지 않음 ([computeNextDueDate] 사후 보정).
  final int daysUntilDue;

  /// 예상 결제액 = -account.balance (음수를 양수로). 양수면 과오결제.
  final int expectedPayment;

  /// 해당 카드 최근 사용 내역 10건 (오늘부터 과거).
  final List<TxRow> recentCharges;

  /// `dueDay`가 잡혀있는지 — UI가 "결제일 미설정" 안내를 표시할지 결정.
  bool get hasDueDay => nextDueDate != null;
}
