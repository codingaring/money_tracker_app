// Design Ref: §5.2 — RecurringRulesScreen (M4 recurring-mgmt).
// CRUD UI for recurring_rules. Edit via bottom sheet, active toggle inline.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/ui/money_format.dart';
import '../data/recurring_rule_repository.dart';
import 'recurring_rule_form_sheet.dart';

class RecurringRulesScreen extends ConsumerWidget {
  const RecurringRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(allRecurringRulesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('반복 거래 관리')),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (rules) {
          if (rules.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat, size: 48, color: Colors.black26),
                  SizedBox(height: 12),
                  Text('등록된 반복 거래가 없습니다',
                      style: TextStyle(color: Colors.black45)),
                  SizedBox(height: 4),
                  Text('+ 버튼으로 추가하세요',
                      style: TextStyle(color: Colors.black38, fontSize: 12)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rules.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, i) =>
                _RuleItem(rule: rules[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'recurring-fab',
        onPressed: () => _openForm(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openForm(
      BuildContext context, WidgetRef ref, RecurringRule? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RecurringRuleFormSheet(existing: existing),
    );
  }
}

class _RuleItem extends ConsumerWidget {
  const _RuleItem({required this.rule});

  final RecurringRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(recurringRuleRepositoryProvider);
    final theme = Theme.of(context);
    final amountStr = rule.templateAmount != null
        ? '  ·  ${Money.format(rule.templateAmount!)}'
        : '';

    return ListTile(
      leading: _DayBadge(day: rule.dayOfMonth),
      title: Text(rule.templateName,
          style: rule.isActive
              ? null
              : TextStyle(color: theme.colorScheme.outline)),
      subtitle: Text(
        '매월 ${rule.dayOfMonth}일$amountStr',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: rule.isActive,
            onChanged: (_) => repo.update(
              rule.id,
              RecurringRulesCompanion(isActive: Value(!rule.isActive)),
            ),
          ),
          PopupMenuButton<_MenuAction>(
            onSelected: (action) => _onAction(context, ref, action),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _MenuAction.edit,
                child: Text('수정'),
              ),
              PopupMenuItem(
                value: _MenuAction.delete,
                child: Text('삭제'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onAction(
      BuildContext context, WidgetRef ref, _MenuAction action) async {
    switch (action) {
      case _MenuAction.edit:
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => RecurringRuleFormSheet(existing: rule),
        );
      case _MenuAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('반복 거래 삭제'),
            content: Text('"${rule.templateName}" 규칙을 삭제할까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('삭제'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await ref.read(recurringRuleRepositoryProvider).delete(rule.id);
        }
    }
  }
}

enum _MenuAction { edit, delete }

class _DayBadge extends StatelessWidget {
  const _DayBadge({required this.day});

  final int day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          Text(
            '일',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
