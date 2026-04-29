// Design Ref: §4.3 — TemplateRepository: 비즈니스 로직 + DAO 추상화.
// AccountFormSheet의 clear flag 패턴 동일 — clearAmount/clearFrom 등으로
// nullable 컬럼을 명시적으로 NULL로 set 가능.

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../transactions/domain/transaction.dart';
import 'templates_dao.dart';

class TemplateRepository {
  TemplateRepository({required TemplatesDao dao}) : _dao = dao;
  final TemplatesDao _dao;

  Stream<List<TxTemplate>> watchAll() => _dao.watchAll();
  Stream<List<TxTemplate>> watchByLastUsed() => _dao.watchByLastUsed();
  Future<List<TxTemplate>> readAll() => _dao.readAll();
  Future<TxTemplate?> findById(int id) => _dao.findById(id);
  Future<TxTemplate?> findByName(String name) => _dao.findByName(name);

  Future<TxTemplate> create({
    required String name,
    required TxType type,
    int? amount,
    int? fromAccountId,
    int? toAccountId,
    int? categoryId,
    String? memo,
    int sortOrder = 0,
  }) async {
    final id = await _dao.insertOne(TxTemplatesCompanion.insert(
      name: name,
      type: type,
      amount: Value(amount),
      fromAccountId: Value(fromAccountId),
      toAccountId: Value(toAccountId),
      categoryId: Value(categoryId),
      memo: Value(memo),
      sortOrder: Value(sortOrder),
    ));
    final row = await _dao.findById(id);
    if (row == null) throw StateError('inserted template not found id=$id');
    return row;
  }

  /// Updates non-key fields. Use clear* flags to explicitly NULL a nullable
  /// column (otherwise null param means "no change", as per Drift's
  /// `Value.absent` semantics).
  Future<void> update(
    int id, {
    String? name,
    TxType? type,
    int? amount,
    bool clearAmount = false,
    int? fromAccountId,
    bool clearFrom = false,
    int? toAccountId,
    bool clearTo = false,
    int? categoryId,
    bool clearCategory = false,
    String? memo,
    bool clearMemo = false,
  }) {
    return _dao.updateById(
      id,
      TxTemplatesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        type: type == null ? const Value.absent() : Value(type),
        amount: clearAmount
            ? const Value(null)
            : (amount == null ? const Value.absent() : Value(amount)),
        fromAccountId: clearFrom
            ? const Value(null)
            : (fromAccountId == null
                ? const Value.absent()
                : Value(fromAccountId)),
        toAccountId: clearTo
            ? const Value(null)
            : (toAccountId == null
                ? const Value.absent()
                : Value(toAccountId)),
        categoryId: clearCategory
            ? const Value(null)
            : (categoryId == null
                ? const Value.absent()
                : Value(categoryId)),
        memo: clearMemo
            ? const Value(null)
            : (memo == null ? const Value.absent() : Value(memo)),
      ),
    );
  }

  Future<void> delete(int id) => _dao.deleteById(id);

  Future<void> reorder(List<int> idsInOrder) => _dao.reorder(idsInOrder);

  /// Plan SC: FR-38 — Input save 성공 시점에만 호출. 취소·실패면 갱신 안 함.
  Future<void> markUsed(int id) => _dao.markUsed(id);
}
