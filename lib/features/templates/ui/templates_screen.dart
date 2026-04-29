// Design Ref: §5.3 — TemplatesScreen (설정 sub).
// Plan SC: FR-35. ReorderableListView로 sortOrder 변경 + tap edit + swipe delete + FAB.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/db/app_database.dart';
import '../../../core/ui/money_format.dart';
import '../../transactions/domain/transaction.dart';
import 'template_form_sheet.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTemplates = ref.watch(templatesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('거래 템플릿')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'templates-add-fab',
        icon: const Icon(Icons.add),
        label: const Text('템플릿 추가'),
        onPressed: () => _openCreate(context),
      ),
      body: asyncTemplates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('로드 실패: $e')),
        data: (templates) {
          if (templates.isEmpty) return const _Empty();
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
            itemCount: templates.length,
            onReorder: (oldIdx, newIdx) async {
              // ReorderableListView quirk — newIdx > oldIdx면 1 빼야 정확.
              final adjusted = newIdx > oldIdx ? newIdx - 1 : newIdx;
              final mutable = [...templates];
              final moved = mutable.removeAt(oldIdx);
              mutable.insert(adjusted, moved);
              final ids = mutable.map((t) => t.id).toList();
              await ref.read(templateRepositoryProvider).reorder(ids);
            },
            itemBuilder: (ctx, i) {
              final t = templates[i];
              return _TemplateTile(
                key: ValueKey('tpl-${t.id}'),
                template: t,
                onTap: () => _openEdit(context, t),
                onDelete: () => _confirmDelete(context, ref, t),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openCreate(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const TemplateFormSheet(),
    );
  }

  Future<void> _openEdit(BuildContext context, TxTemplate t) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TemplateFormSheet(existing: t),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, TxTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('템플릿 삭제'),
        content: Text("'${t.name}' 템플릿을 삭제할까요?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(templateRepositoryProvider).delete(t.id);
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required Key key,
    required this.template,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  final TxTemplate template;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Dismissible(
        key: ValueKey('dis-${template.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          onDelete();
          return false; // reactive rebuild via Repository
        },
        background: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: Icon(Icons.delete_rounded,
              color: theme.colorScheme.onErrorContainer),
        ),
        child: Material(
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: [
                  _TypeBadge(type: template.type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(template.name,
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.drag_handle_rounded,
                      color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final amount = template.amount == null
        ? '₩(자동)'
        : Money.formatKrw(template.amount!);
    final memo = template.memo == null || template.memo!.isEmpty
        ? ''
        : ' · ${template.memo}';
    return '${_typeLabel(template.type)} · $amount$memo';
  }

  String _typeLabel(TxType t) => switch (t) {
        TxType.expense => '지출',
        TxType.income => '수입',
        TxType.transfer => '이체',
        TxType.valuation => '평가',
      };
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final TxType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg, icon) = switch (type) {
      TxType.expense => (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.primary,
          Icons.north_east_rounded
        ),
      TxType.income => (
          theme.colorScheme.tertiaryContainer,
          theme.colorScheme.tertiary,
          Icons.south_west_rounded
        ),
      TxType.transfer => (
          theme.colorScheme.surfaceContainer,
          theme.colorScheme.onSurfaceVariant,
          Icons.swap_horiz_rounded
        ),
      TxType.valuation => (
          theme.colorScheme.secondaryContainer,
          theme.colorScheme.secondary,
          Icons.trending_up_rounded
        ),
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: fg),
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
            Icon(Icons.bookmark_outline_rounded,
                size: 80, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('템플릿이 없습니다',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '자주 쓰는 거래(월세/통신비 등)를 저장해두면\n입력할 때 한 번에 채워집니다.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
