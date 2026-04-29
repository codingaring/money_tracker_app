// Design Ref: §5.9 — CategoriesScreen (설정 sub: 카테고리 관리).
// Plan SC: FR-50. 지출/수입 탭 + ExpansionTile per 대분류 + drag-reorder + FAB.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/db/app_database.dart';
import '../domain/category.dart';
import 'category_form_sheet.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  CategoryKind get _currentKind =>
      _tabs.index == 0 ? CategoryKind.expense : CategoryKind.income;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('카테고리'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: '지출'),
            Tab(text: '수입'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'categories-add-fab',
        icon: const Icon(Icons.add),
        label: const Text('카테고리 추가'),
        onPressed: () => _openCreate(),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _CategoryList(kind: CategoryKind.expense),
          _CategoryList(kind: CategoryKind.income),
        ],
      ),
    );
  }

  Future<void> _openCreate() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryFormSheet(defaultKind: _currentKind),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.kind});

  final CategoryKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(categoriesByKindProvider(kind));
    return allAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('로드 실패: $e')),
      data: (all) {
        final topLevels = all.where((c) => c.parentCategoryId == null).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        if (topLevels.isEmpty) return const _Empty();

        final byParent = <int, List<Category>>{};
        for (final c in all) {
          final pid = c.parentCategoryId;
          if (pid != null) {
            (byParent[pid] ??= []).add(c);
          }
        }

        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
          itemCount: topLevels.length,
          onReorder: (oldIdx, newIdx) async {
            final adjusted = newIdx > oldIdx ? newIdx - 1 : newIdx;
            final mutable = [...topLevels];
            final moved = mutable.removeAt(oldIdx);
            mutable.insert(adjusted, moved);
            final ids = mutable.map((c) => c.id).toList();
            await ref.read(categoryRepositoryProvider).reorder(ids);
          },
          itemBuilder: (ctx, i) {
            final top = topLevels[i];
            final children = (byParent[top.id] ?? const <Category>[]).toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            return _TopLevelTile(
              key: ValueKey('top-${top.id}'),
              parent: top,
              children: children,
              onEdit: (c) => _openEdit(context, c),
              onDelete: (c) => _confirmDelete(context, ref, c),
            );
          },
        );
      },
    );
  }

  Future<void> _openEdit(BuildContext context, Category c) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryFormSheet(existing: c),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('카테고리 삭제'),
        content: Text(
          c.parentCategoryId == null
              ? "'${c.name}' 카테고리를 삭제할까요?\n자식 소분류는 자동으로 대분류로 승격됩니다."
              : "'${c.name}' 소분류를 삭제할까요?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(categoryRepositoryProvider).deleteById(c.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }
}

class _TopLevelTile extends StatelessWidget {
  const _TopLevelTile({
    required Key key,
    required this.parent,
    required this.children,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  final Category parent;
  final List<Category> children;
  final void Function(Category c) onEdit;
  final void Function(Category c) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        child: Theme(
          // ExpansionTile divider 제거 위해 hairline color override
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: children.isNotEmpty,
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.fromLTRB(20, 4, 4, 4),
            childrenPadding: EdgeInsets.zero,
            title: Row(
              children: [
                if (parent.isFixed)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      '고정',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(parent.name,
                      style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: '수정',
                  onPressed: () => onEdit(parent),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error),
                  tooltip: '삭제',
                  onPressed: () => onDelete(parent),
                ),
                Icon(Icons.drag_handle_rounded,
                    color: theme.colorScheme.outline),
                const SizedBox(width: 8),
              ],
            ),
            children: [
              if (children.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 16, 12),
                  child: Text(
                    '소분류가 없습니다',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ...children.map((c) => _ChildTile(
                      child: c,
                      onEdit: () => onEdit(c),
                      onDelete: () => onDelete(c),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildTile extends StatelessWidget {
  const _ChildTile({
    required this.child,
    required this.onEdit,
    required this.onDelete,
  });

  final Category child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 4, 0),
      child: Row(
        children: [
          Icon(Icons.subdirectory_arrow_right_rounded,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(child.name, style: theme.textTheme.bodyLarge),
          ),
          if (child.isFixed)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  '고정',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: '수정',
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 20, color: theme.colorScheme.error),
            tooltip: '삭제',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.label_outline_rounded,
                size: 80, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('카테고리가 없습니다',
                style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
