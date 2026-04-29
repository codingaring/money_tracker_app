// Design Ref: §5.2 — Input form state held by Riverpod Notifier.
// Plan SC: FR-16 (type별 동적 폼).
// M3: appliedTemplateId 추적 — 저장 성공 시 markUsed 호출용.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../domain/transaction.dart';

class InputFormState {
  const InputFormState({
    required this.type,
    required this.amount,
    required this.occurredAt,
    this.fromAccountId,
    this.toAccountId,
    this.categoryId,
    this.memo = '',
    this.appliedTemplateId,
  });

  factory InputFormState.initial() => InputFormState(
        type: TxType.expense,
        amount: 0,
        occurredAt: DateTime.now(),
      );

  final TxType type;
  final int amount;
  final int? fromAccountId;
  final int? toAccountId;
  final int? categoryId;
  final String memo;
  final DateTime occurredAt;

  /// M3 — 사용자가 템플릿에서 prefill했을 때 그 템플릿의 id. 저장 성공 시
  /// TemplateRepository.markUsed에 사용. 취소·실패면 호출 안 됨.
  final int? appliedTemplateId;

  /// Build the draft if all fields are present and valid.
  /// Returns null + the violation message if not.
  ({NewTransaction? draft, String? error}) toDraft() {
    if (amount <= 0) return (draft: null, error: '금액을 입력하세요');
    final draft = NewTransaction(
      type: type,
      amount: amount,
      fromAccountId: _expectsFrom() ? fromAccountId : null,
      toAccountId: _expectsTo() ? toAccountId : null,
      categoryId: _expectsCategory() ? categoryId : null,
      memo: memo.isEmpty ? null : memo,
      occurredAt: occurredAt,
    );
    final violation = draft.validate();
    return (draft: violation == null ? draft : null, error: violation);
  }

  bool _expectsFrom() => type == TxType.expense || type == TxType.transfer;
  bool _expectsTo() =>
      type == TxType.income ||
      type == TxType.transfer ||
      type == TxType.valuation;
  bool _expectsCategory() => type == TxType.expense || type == TxType.income;

  InputFormState copyWith({
    TxType? type,
    int? amount,
    DateTime? occurredAt,
    Object? fromAccountId = _sentinel,
    Object? toAccountId = _sentinel,
    Object? categoryId = _sentinel,
    String? memo,
    Object? appliedTemplateId = _sentinel,
  }) {
    return InputFormState(
      type: type ?? this.type,
      amount: amount ?? this.amount,
      occurredAt: occurredAt ?? this.occurredAt,
      fromAccountId: identical(fromAccountId, _sentinel)
          ? this.fromAccountId
          : fromAccountId as int?,
      toAccountId: identical(toAccountId, _sentinel)
          ? this.toAccountId
          : toAccountId as int?,
      categoryId: identical(categoryId, _sentinel)
          ? this.categoryId
          : categoryId as int?,
      memo: memo ?? this.memo,
      appliedTemplateId: identical(appliedTemplateId, _sentinel)
          ? this.appliedTemplateId
          : appliedTemplateId as int?,
    );
  }

  static const _sentinel = Object();
}

class InputFormNotifier extends Notifier<InputFormState> {
  @override
  InputFormState build() => InputFormState.initial();

  /// Switching type clears fields that don't apply to the new type — prevents
  /// stale leftovers like a categoryId on a transfer. Also clears
  /// appliedTemplateId since template's type may not match.
  void setType(TxType v) {
    state = InputFormState(
      type: v,
      amount: state.amount,
      occurredAt: state.occurredAt,
      memo: state.memo,
      // intentionally drop account/category/templateId
    );
  }

  void setAmount(int v) => state = state.copyWith(amount: v);
  void setMemo(String v) => state = state.copyWith(memo: v);
  void setOccurredAt(DateTime v) => state = state.copyWith(occurredAt: v);
  void setFromAccount(int? v) => state = state.copyWith(fromAccountId: v);
  void setToAccount(int? v) => state = state.copyWith(toAccountId: v);
  void setCategory(int? v) => state = state.copyWith(categoryId: v);

  /// Plan SC: FR-38 — prefill form from a template.
  /// occurredAt remains today (default at form open). appliedTemplateId is
  /// recorded so InputScreen can call markUsed after a successful save.
  void applyTemplate(TxTemplate t) {
    state = InputFormState(
      type: t.type,
      amount: t.amount ?? 0,
      occurredAt: state.occurredAt, // keep today (or whatever user set)
      fromAccountId: t.fromAccountId,
      toAccountId: t.toAccountId,
      categoryId: t.categoryId,
      memo: t.memo ?? '',
      appliedTemplateId: t.id,
    );
  }

  /// Mark the applied template as cleared (e.g., after save success when we
  /// don't want re-mark on subsequent save).
  void clearAppliedTemplate() =>
      state = state.copyWith(appliedTemplateId: null);

  void reset() => state = InputFormState.initial();
}

final inputFormProvider =
    NotifierProvider<InputFormNotifier, InputFormState>(InputFormNotifier.new);
