// Design Ref: §5.5 — BudgetScreen. 카테고리별 월 한도 설정/수정/삭제.
// Plan SC: FR-48.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/ui/money_format.dart';
import '../../categories/domain/category.dart';
import '../data/budget_repository.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync =
        ref.watch(topLevelCategoriesProvider(CategoryKind.expense));
    final budgetsAsync = ref.watch(allBudgetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('예산 관리')),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('카테고리 로드 실패: $e')),
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Text(
                '지출 카테고리를 먼저 추가해주세요',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            );
          }
          final budgets = budgetsAsync.valueOrNull ?? [];
          final budgetByCategory = {for (final b in budgets) b.categoryId: b};

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '카테고리별 월 한도를 설정하면 분석 탭에서 초과 여부를 확인할 수 있습니다.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: categories.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (ctx, i) {
                    final cat = categories[i];
                    final budget = budgetByCategory[cat.id];
                    return _BudgetCategoryTile(
                      category: cat,
                      budget: budget,
                      onSet: (limit) =>
                          ref.read(budgetRepositoryProvider).upsert(cat.id, limit),
                      onDelete: budget != null
                          ? () => ref.read(budgetRepositoryProvider).delete(cat.id)
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BudgetCategoryTile extends StatelessWidget {
  const _BudgetCategoryTile({
    required this.category,
    required this.budget,
    required this.onSet,
    this.onDelete,
  });

  final Category category;
  final Budget? budget;
  final Future<void> Function(int limit) onSet;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLimit = budget != null;

    return ListTile(
      title: Text(category.name),
      subtitle: hasLimit
          ? Text(
              '${Money.formatKrw(budget!.monthlyLimit)} / 월',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            )
          : Text(
              '미설정',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => _showLimitDialog(context),
            child: Text(hasLimit ? '수정' : '설정'),
          ),
          if (hasLimit)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: theme.colorScheme.error),
              onPressed: onDelete,
              tooltip: '예산 삭제',
            ),
        ],
      ),
    );
  }

  Future<void> _showLimitDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: budget != null ? budget!.monthlyLimit.toString() : '',
    );
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${category.name} 월 한도'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            prefixText: '₩ ',
            hintText: '한도 금액 입력',
          ),
          onSubmitted: (_) {
            final v = int.tryParse(controller.text);
            if (v != null && v > 0) Navigator.pop(ctx, v);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text);
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) await onSet(result);
  }
}
