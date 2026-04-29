// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'templates_dao.dart';

// ignore_for_file: type=lint
mixin _$TemplatesDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $CategoriesTable get categories => attachedDatabase.categories;
  $TxTemplatesTable get txTemplates => attachedDatabase.txTemplates;
  TemplatesDaoManager get managers => TemplatesDaoManager(this);
}

class TemplatesDaoManager {
  final _$TemplatesDaoMixin _db;
  TemplatesDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$TxTemplatesTableTableManager get txTemplates =>
      $$TxTemplatesTableTableManager(_db.attachedDatabase, _db.txTemplates);
}
