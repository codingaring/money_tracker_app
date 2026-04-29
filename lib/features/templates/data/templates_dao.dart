// Design Ref: §4.2 — TemplatesDao for tx_templates CRUD + reactive watch.
// Repository는 이 DAO만 의존. DAO는 Sheets / 외부 서비스 호출 없음.

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/tables.dart';

part 'templates_dao.g.dart';

@DriftAccessor(tables: [TxTemplates])
class TemplatesDao extends DatabaseAccessor<AppDatabase>
    with _$TemplatesDaoMixin {
  TemplatesDao(super.db);

  /// TemplatesScreen 용 — sortOrder asc, 같으면 id asc.
  Stream<List<TxTemplate>> watchAll() {
    return (select(txTemplates)
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  /// TemplatePickerSheet 용 — lastUsedAt desc, NULL은 가장 아래.
  Stream<List<TxTemplate>> watchByLastUsed() {
    return (select(txTemplates)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.lastUsedAt,
                  mode: OrderingMode.desc,
                  nulls: NullsOrder.last,
                ),
            (t) => OrderingTerm.asc(t.sortOrder),
          ]))
        .watch();
  }

  Future<List<TxTemplate>> readAll() {
    return (select(txTemplates)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  Future<TxTemplate?> findById(int id) {
    return (select(txTemplates)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<TxTemplate?> findByName(String name) {
    return (select(txTemplates)..where((t) => t.name.equals(name)))
        .getSingleOrNull();
  }

  Future<int> insertOne(TxTemplatesCompanion data) {
    return into(txTemplates).insert(data);
  }

  /// updatedAt 자동 갱신.
  Future<int> updateById(int id, TxTemplatesCompanion patch) {
    return (update(txTemplates)..where((t) => t.id.equals(id)))
        .write(patch.copyWith(updatedAt: Value(DateTime.now())));
  }

  Future<int> deleteById(int id) {
    return (delete(txTemplates)..where((t) => t.id.equals(id))).go();
  }

  /// strftime('%s','now')는 Drift가 DateTime을 Unix epoch INT로 저장하기
  /// 때문에 필수. ISO 문자열은 read 시 FormatException — feedback 메모리 참고.
  Future<void> markUsed(int id) async {
    await customStatement(
      "UPDATE tx_templates "
      "SET last_used_at = strftime('%s', 'now'), "
      "    updated_at = strftime('%s', 'now') "
      "WHERE id = ?",
      [id],
    );
  }

  /// Atomic reorder — caller passes ids in their new order. sortOrder는
  /// 10단위로 부여해 사이 삽입 여유.
  Future<void> reorder(List<int> idsInOrder) async {
    await db.transaction(() async {
      for (var i = 0; i < idsInOrder.length; i++) {
        await (update(txTemplates)..where((t) => t.id.equals(idsInOrder[i])))
            .write(TxTemplatesCompanion(sortOrder: Value(i * 10)));
      }
    });
  }
}
