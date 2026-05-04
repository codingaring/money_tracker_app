// Design Ref: §5.2 — RecurringRuleFormSheet (M4 recurring-mgmt, M5 recurrence-type).
// insert/update form. template + recurrenceType(월/주/일) + dayOfMonth/dayOfWeek.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../data/recurring_rule_repository.dart';

const _kWeekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

class RecurringRuleFormSheet extends ConsumerStatefulWidget {
  const RecurringRuleFormSheet({super.key, this.existing});

  /// null = create mode, non-null = edit mode.
  final RecurringRule? existing;

  @override
  ConsumerState<RecurringRuleFormSheet> createState() =>
      _RecurringRuleFormSheetState();
}

class _RecurringRuleFormSheetState
    extends ConsumerState<RecurringRuleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  TxTemplate? _selectedTemplate;
  int _dayOfMonth = 1;
  String _recurrenceType = 'monthly';
  int _dayOfWeek = 1; // 1=월~7=일
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _dayOfMonth = widget.existing!.dayOfMonth;
      _recurrenceType = widget.existing!.recurrenceType;
      _dayOfWeek = widget.existing!.dayOfWeek ?? 1;
      // Template will be resolved after first frame once stream emits.
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(templatesListProvider);
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;

    // Once templates are available, resolve the existing template for edit mode.
    if (_selectedTemplate == null && isEdit) {
      templatesAsync.whenData((list) {
        final match = list
            .where((t) => t.id == widget.existing!.templateId)
            .firstOrNull;
        if (match != null && _selectedTemplate == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedTemplate = match);
          });
        }
      });
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEdit ? '반복 거래 수정' : '반복 거래 추가',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Template dropdown
            templatesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('템플릿 로드 실패: $e'),
              data: (templates) {
                if (templates.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '템플릿이 없습니다. 먼저 거래 템플릿을 등록하세요.',
                      style: TextStyle(
                          color: theme.colorScheme.onErrorContainer),
                    ),
                  );
                }
                return DropdownButtonFormField<TxTemplate>(
                  // key forces recreation when edit-mode template resolves async.
                  key: ValueKey(_selectedTemplate?.id ?? 0),
                  initialValue: _selectedTemplate,
                  decoration: const InputDecoration(
                    labelText: '거래 템플릿',
                    border: OutlineInputBorder(),
                  ),
                  items: templates
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (t) => setState(() => _selectedTemplate = t),
                  validator: (v) => v == null ? '템플릿을 선택하세요' : null,
                );
              },
            ),
            const SizedBox(height: 16),

            // Recurrence type dropdown
            DropdownButtonFormField<String>(
              initialValue: _recurrenceType,
              decoration: const InputDecoration(
                labelText: '반복 주기',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'monthly', child: Text('매월')),
                DropdownMenuItem(value: 'weekly', child: Text('매주')),
                DropdownMenuItem(value: 'daily', child: Text('매일')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _recurrenceType = v);
              },
            ),
            const SizedBox(height: 16),

            // Day of month (monthly only)
            if (_recurrenceType == 'monthly')
              DropdownButtonFormField<int>(
                initialValue: _dayOfMonth,
                decoration: const InputDecoration(
                  labelText: '매월 반복일 (1-28일)',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(
                  28,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text('${i + 1}일'),
                  ),
                ),
                onChanged: (v) {
                  if (v != null) setState(() => _dayOfMonth = v);
                },
              ),

            // Day of week (weekly only)
            if (_recurrenceType == 'weekly')
              DropdownButtonFormField<int>(
                initialValue: _dayOfWeek,
                decoration: const InputDecoration(
                  labelText: '매주 반복 요일',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(
                  7,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text(_kWeekdayLabels[i]),
                  ),
                ),
                onChanged: (v) {
                  if (v != null) setState(() => _dayOfWeek = v);
                },
              ),

            const SizedBox(height: 28),

            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEdit ? '저장' : '추가'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(recurringRuleRepositoryProvider);
      final isEdit = widget.existing != null;
      final dow =
          _recurrenceType == 'weekly' ? Value(_dayOfWeek) : const Value<int?>(null);
      if (isEdit) {
        await repo.update(
          widget.existing!.id,
          RecurringRulesCompanion(
            templateId: Value(_selectedTemplate!.id),
            dayOfMonth: Value(_dayOfMonth),
            recurrenceType: Value(_recurrenceType),
            dayOfWeek: dow,
            updatedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await repo.insert(
          RecurringRulesCompanion.insert(
            templateId: _selectedTemplate!.id,
            dayOfMonth: _dayOfMonth,
            recurrenceType: Value(_recurrenceType),
            dayOfWeek: dow,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
