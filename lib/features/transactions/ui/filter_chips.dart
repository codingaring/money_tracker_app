// Design Ref: §5.4 — 4 chip filters (기간/계좌/카테고리/타입) with BottomSheet picker.
// Plan SC: FR-26.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/ui/money_format.dart';
import '../../accounts/domain/account.dart';
import '../../categories/domain/category.dart';
import '../domain/search_filter.dart';
import '../domain/transaction.dart';

class FilterChipsRow extends ConsumerWidget {
  const FilterChipsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(searchFilterProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _DateChip(filter: filter),
          const SizedBox(width: 8),
          _AccountChip(filter: filter),
          const SizedBox(width: 8),
          _CategoryChip(filter: filter),
          const SizedBox(width: 8),
          _TypeChip(filter: filter),
        ],
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InputChip(
      label: Text(label),
      avatar: Icon(
        Icons.expand_more_rounded,
        size: 18,
        color: active ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
      ),
      onPressed: onTap,
      onDeleted: active ? onClear : null,
      deleteIcon: Icon(Icons.close_rounded,
          size: 16, color: theme.colorScheme.onPrimary),
      backgroundColor: active ? theme.colorScheme.primary : Colors.transparent,
      selectedColor: theme.colorScheme.primary,
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: active ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
      ),
      side: active
          ? BorderSide.none
          : BorderSide(color: theme.colorScheme.outlineVariant),
    );
  }
}

// ── Date ───────────────────────────────────────────────────────────────────

class _DateChip extends ConsumerWidget {
  const _DateChip({required this.filter});

  final SearchFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = !filter.dateRange.isEmpty;
    return _ActiveChip(
      label: active ? (filter.dateRange.label ?? '직접지정') : '전체기간',
      active: active,
      onTap: () => _show(context, ref),
      onClear: () => ref.read(searchFilterProvider.notifier).clearDate(),
    );
  }

  Future<void> _show(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month);
    final nextMonthStart = DateTime(now.year, now.month + 1);
    final lastMonthStart = DateTime(now.year, now.month - 1);
    final picked = await showModalBottomSheet<_SheetResult<DateRange>>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('전체 기간'),
              onTap: () =>
                  Navigator.pop(ctx, const _SheetClear<DateRange>()),
            ),
            ListTile(
              title: const Text('이번 달'),
              onTap: () => Navigator.pop(
                ctx,
                _SheetSelect(
                  DateRange(
                    from: thisMonthStart,
                    to: nextMonthStart,
                    label: '이번 달',
                  ),
                ),
              ),
            ),
            ListTile(
              title: const Text('지난 달'),
              onTap: () => Navigator.pop(
                ctx,
                _SheetSelect(
                  DateRange(
                    from: lastMonthStart,
                    to: thisMonthStart,
                    label: '지난 달',
                  ),
                ),
              ),
            ),
            ListTile(
              title: const Text('직접 지정...'),
              onTap: () async {
                Navigator.pop(ctx);
                final r = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(now.year + 1),
                );
                if (r != null) {
                  ref.read(searchFilterProvider.notifier).setDateRange(
                        DateRange(
                          from: r.start,
                          // exclusive end — bump by 1 day so the picked end
                          // date is included in `<` comparison.
                          to: r.end.add(const Duration(days: 1)),
                          label:
                              '${DateLabels.ymd(r.start)} ~ ${DateLabels.ymd(r.end)}',
                        ),
                      );
                }
              },
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final notifier = ref.read(searchFilterProvider.notifier);
    switch (picked) {
      case _SheetClear<DateRange>():
        notifier.clearDate();
      case _SheetSelect<DateRange>(:final value):
        notifier.setDateRange(value);
    }
  }
}

// Sealed result so dismissal (sheet pop with null) and explicit "전체" are
// distinguishable. Without this, an outside-tap silently clears the filter.
sealed class _SheetResult<T> {
  const _SheetResult();
}

class _SheetClear<T> extends _SheetResult<T> {
  const _SheetClear();
}

class _SheetSelect<T> extends _SheetResult<T> {
  const _SheetSelect(this.value);
  final T value;
}

// ── Account ────────────────────────────────────────────────────────────────

class _AccountChip extends ConsumerWidget {
  const _AccountChip({required this.filter});

  final SearchFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = filter.accountId != null;
    return _ActiveChip(
      label: active ? (filter.accountName ?? '계좌') : '전체계좌',
      active: active,
      onTap: () => _show(context, ref),
      onClear: () => ref.read(searchFilterProvider.notifier).clearAccount(),
    );
  }

  Future<void> _show(BuildContext context, WidgetRef ref) async {
    final accountsAsync = ref.read(accountsStreamProvider);
    final accounts = accountsAsync.value ?? const <Account>[];
    final result = await showModalBottomSheet<_SheetResult<Account>>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('전체 계좌'),
              onTap: () => Navigator.pop(ctx, const _SheetClear<Account>()),
            ),
            const Divider(height: 1),
            for (final a in accounts)
              ListTile(
                title: Text(a.name),
                subtitle: Text(_typeLabel(a.type)),
                onTap: () => Navigator.pop(ctx, _SheetSelect(a)),
              ),
          ],
        ),
      ),
    );
    if (result == null) return; // Dismissed — preserve current state.
    final notifier = ref.read(searchFilterProvider.notifier);
    switch (result) {
      case _SheetClear<Account>():
        notifier.clearAccount();
      case _SheetSelect<Account>(:final value):
        notifier.setAccount(id: value.id, name: value.name);
    }
  }

  String _typeLabel(AccountType t) => switch (t) {
        AccountType.cash => '현금',
        AccountType.investment => '투자',
        AccountType.savings => '저축',
        AccountType.realEstate => '부동산',
        AccountType.creditCard => '신용카드',
        AccountType.loan => '대출',
      };
}

// ── Category ───────────────────────────────────────────────────────────────

class _CategoryChip extends ConsumerWidget {
  const _CategoryChip({required this.filter});

  final SearchFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = filter.categoryId != null;
    return _ActiveChip(
      label: active ? (filter.categoryName ?? '카테고리') : '전체카테고리',
      active: active,
      onTap: () => _show(context, ref),
      onClear: () => ref.read(searchFilterProvider.notifier).clearCategory(),
    );
  }

  Future<void> _show(BuildContext context, WidgetRef ref) async {
    // M3 categories-ui: 2-level BottomSheet — 대분류 expand → 소분류 list.
    final all = ref.read(categoriesListProvider).value ?? const <Category>[];
    final topLevels = all.where((c) => c.parentCategoryId == null).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final byParent = <int, List<Category>>{};
    for (final c in all) {
      final pid = c.parentCategoryId;
      if (pid != null) (byParent[pid] ??= []).add(c);
    }
    for (final list in byParent.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    final result = await showModalBottomSheet<_SheetResult<Category>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) => SafeArea(
            child: ListView(
              controller: scrollCtrl,
              children: [
                ListTile(
                  title: const Text('전체 카테고리'),
                  onTap: () =>
                      Navigator.pop(ctx, const _SheetClear<Category>()),
                ),
                const Divider(height: 1),
                for (final top in topLevels)
                  _ExpandableCategoryRow(
                    parent: top,
                    children: byParent[top.id] ?? const <Category>[],
                    onSelect: (c) => Navigator.pop(ctx, _SheetSelect(c)),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (result == null) return;
    final notifier = ref.read(searchFilterProvider.notifier);
    switch (result) {
      case _SheetClear<Category>():
        notifier.clearCategory();
      case _SheetSelect<Category>(:final value):
        notifier.setCategory(id: value.id, name: value.name);
    }
  }
}

class _ExpandableCategoryRow extends StatelessWidget {
  const _ExpandableCategoryRow({
    required this.parent,
    required this.children,
    required this.onSelect,
  });

  final Category parent;
  final List<Category> children;
  final void Function(Category) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (children.isEmpty) {
      // 소분류 없는 대분류 — 단일 행으로 표시
      return ListTile(
        title: Text(parent.name),
        subtitle: Text(parent.kind == CategoryKind.expense ? '지출' : '수입'),
        onTap: () => onSelect(parent),
      );
    }
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(parent.name),
        subtitle: Text(
            '${parent.kind == CategoryKind.expense ? '지출' : '수입'} · ${children.length}개'),
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(40, 0, 16, 0),
            leading: Icon(Icons.subdirectory_arrow_right_rounded,
                color: theme.colorScheme.onSurfaceVariant),
            title: Text('전체 ${parent.name}'),
            onTap: () => onSelect(parent),
          ),
          ...children.map((c) => ListTile(
                contentPadding: const EdgeInsets.fromLTRB(40, 0, 16, 0),
                title: Text(c.name),
                onTap: () => onSelect(c),
              )),
        ],
      ),
    );
  }
}

// ── Type ───────────────────────────────────────────────────────────────────

class _TypeChip extends ConsumerWidget {
  const _TypeChip({required this.filter});

  final SearchFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = filter.type != null;
    return _ActiveChip(
      label: active ? _label(filter.type!) : '전체타입',
      active: active,
      onTap: () => _show(context, ref),
      onClear: () => ref.read(searchFilterProvider.notifier).clearType(),
    );
  }

  Future<void> _show(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<_SheetResult<TxType>>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('전체 타입'),
              onTap: () => Navigator.pop(ctx, const _SheetClear<TxType>()),
            ),
            for (final t in TxType.values)
              ListTile(
                title: Text(_label(t)),
                onTap: () => Navigator.pop(ctx, _SheetSelect(t)),
              ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final notifier = ref.read(searchFilterProvider.notifier);
    switch (result) {
      case _SheetClear<TxType>():
        notifier.clearType();
      case _SheetSelect<TxType>(:final value):
        notifier.setType(value);
    }
  }

  String _label(TxType t) => switch (t) {
        TxType.expense => '지출',
        TxType.income => '수입',
        TxType.transfer => '이체',
        TxType.valuation => '평가',
      };
}
