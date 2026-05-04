// Design Ref: §5.8 — CategoryPicker (cascading 2-step).
// Plan SC: FR-49. InputScreen·TemplateFormSheet·FilterChip 공유 위젯.
//
// 1단: 대분류 chip wrap (parent NULL인 카테고리)
// 2단: 선택된 대분류의 자식 chip wrap. 자식 없으면 "소분류 없음" 표시.
//      자식 있으면 "전체 [대분류]" 옵션 + 각 소분류 chip.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../app/providers.dart';
import '../domain/category.dart';
import 'category_form_sheet.dart';

class CategoryPicker extends ConsumerWidget {
  const CategoryPicker({
    super.key,
    required this.kind,
    required this.selectedId,
    required this.onChanged,
    this.label = '카테고리',
  });

  final CategoryKind kind;
  final int? selectedId;
  final ValueChanged<int?> onChanged;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allAsync = ref.watch(categoriesByKindProvider(kind));

    return allAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('카테고리 로드 실패: $e'),
      data: (all) {
        final topLevels = all.where((c) => c.parentCategoryId == null).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        // selected의 parent 찾기 — selected가 대분류면 자기 자신, 소분류면 부모.
        // selectedId가 stale (예: 삭제된 카테고리)이면 null 처리.
        int? selectedTopId;
        if (selectedId != null) {
          final selected =
              all.where((c) => c.id == selectedId).firstOrNull;
          if (selected != null) {
            selectedTopId = selected.parentCategoryId ?? selected.id;
          }
        }

        final children = selectedTopId == null
            ? const <Category>[]
            : (all.where((c) => c.parentCategoryId == selectedTopId).toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));
        final selectedTopName = selectedTopId == null
            ? null
            : all
                .where((c) => c.id == selectedTopId)
                .firstOrNull
                ?.name;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            // 1단: 대분류 chip
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...topLevels.map((c) => FilterChip(
                      label: Text(c.name),
                      selected: selectedTopId == c.id,
                      onSelected: (sel) {
                        if (sel) {
                          onChanged(c.id);
                        } else {
                          onChanged(null);
                        }
                      },
                    )),
                ActionChip(
                  avatar: Icon(Icons.add,
                      size: 16,
                      color: theme.colorScheme.primary),
                  label: Text('추가',
                      style:
                          TextStyle(color: theme.colorScheme.primary)),
                  backgroundColor: theme.colorScheme.primaryContainer,
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => CategoryFormSheet(defaultKind: kind),
                  ),
                ),
              ],
            ),
            // 2단: 자식 (대분류 선택됐을 때만)
            if (selectedTopId != null && selectedTopName != null) ...[
              const SizedBox(height: 12),
              if (children.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '소분류 없음 — $selectedTopName 그대로 사용',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                _ChildrenRow(
                  topId: selectedTopId,
                  topName: selectedTopName,
                  children: children,
                  selectedId: selectedId,
                  onChanged: onChanged,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _ChildrenRow extends StatelessWidget {
  const _ChildrenRow({
    required this.topId,
    required this.topName,
    required this.children,
    required this.selectedId,
    required this.onChanged,
  });

  final int topId;
  final String topName;
  final List<Category> children;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '소분류',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // "전체 [대분류]" — 대분류 자체를 카테고리로 사용
            ChoiceChip(
              label: Text('전체 $topName'),
              selected: selectedId == topId,
              onSelected: (sel) => onChanged(sel ? topId : null),
            ),
            ...children.map((c) => ChoiceChip(
                  label: Text(c.name),
                  selected: selectedId == c.id,
                  onSelected: (sel) => onChanged(sel ? c.id : null),
                )),
          ],
        ),
      ],
    );
  }
}
