// Design Ref: §5.4 — TemplateFormSheet (생성/수정 BottomSheet).
// Plan SC: FR-36. AccountFormSheet 패턴 — type 분기, nullable amount,
// unique name 검증.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/ui/money_format.dart';
import '../../categories/domain/category.dart';
import '../../categories/ui/category_picker.dart';
import '../../transactions/domain/transaction.dart';

class TemplateFormSheet extends ConsumerStatefulWidget {
  const TemplateFormSheet({super.key, this.existing});

  /// Edit mode when non-null.
  final TxTemplate? existing;

  @override
  ConsumerState<TemplateFormSheet> createState() =>
      _TemplateFormSheetState();
}

class _TemplateFormSheetState extends ConsumerState<TemplateFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _memoController;
  late TxType _type;
  int? _fromAccountId;
  int? _toAccountId;
  int? _categoryId;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _amountController = TextEditingController(
      text: e?.amount == null ? '' : Money.format(e!.amount!),
    );
    _memoController = TextEditingController(text: e?.memo ?? '');
    _type = e?.type ?? TxType.expense;
    _fromAccountId = e?.fromAccountId;
    _toAccountId = e?.toAccountId;
    _categoryId = e?.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '이름을 입력하세요');
      return;
    }

    // Plan SC: FR-36 — name unique 검증. 단 자기 자신은 제외.
    final repo = ref.read(templateRepositoryProvider);
    final existing = await repo.findByName(name);
    if (existing != null && existing.id != widget.existing?.id) {
      if (mounted) setState(() => _error = '같은 이름의 템플릿이 이미 있습니다');
      return;
    }

    final amountText = _amountController.text.replaceAll(',', '');
    final amount = amountText.isEmpty ? null : int.tryParse(amountText);
    if (amountText.isNotEmpty && (amount == null || amount <= 0)) {
      setState(() => _error = '금액은 양수만 입력 가능 (또는 비워두기)');
      return;
    }

    final memo = _memoController.text.trim();
    final memoArg = memo.isEmpty ? null : memo;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await repo.update(
          widget.existing!.id,
          name: name,
          type: _type,
          amount: amount,
          clearAmount: amount == null,
          fromAccountId: _expectsFrom() ? _fromAccountId : null,
          clearFrom: !_expectsFrom() || _fromAccountId == null,
          toAccountId: _expectsTo() ? _toAccountId : null,
          clearTo: !_expectsTo() || _toAccountId == null,
          categoryId: _expectsCategory() ? _categoryId : null,
          clearCategory: !_expectsCategory() || _categoryId == null,
          memo: memoArg,
          clearMemo: memoArg == null,
        );
      } else {
        await repo.create(
          name: name,
          type: _type,
          amount: amount,
          fromAccountId: _expectsFrom() ? _fromAccountId : null,
          toAccountId: _expectsTo() ? _toAccountId : null,
          categoryId: _expectsCategory() ? _categoryId : null,
          memo: memoArg,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _expectsFrom() => _type == TxType.expense || _type == TxType.transfer;
  bool _expectsTo() =>
      _type == TxType.income ||
      _type == TxType.transfer ||
      _type == TxType.valuation;
  bool _expectsCategory() => _type == TxType.expense || _type == TxType.income;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;
    final asyncAccounts = ref.watch(accountsStreamProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Text(_isEdit ? '템플릿 수정' : '템플릿 추가',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '이름',
                hintText: '예: 월세, 통신비',
              ),
              maxLength: 40,
            ),
            const SizedBox(height: 12),
            _TypeSelector(
              value: _type,
              onChanged: (v) => setState(() {
                _type = v;
                // type-conditional fields clear
                if (!_expectsFrom()) _fromAccountId = null;
                if (!_expectsTo()) _toAccountId = null;
                if (!_expectsCategory()) _categoryId = null;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                prefixText: '₩  ',
                labelText: '금액 (선택)',
                helperText: '비워두면 사용 시 입력',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _ThousandsFormatter(),
              ],
            ),
            const SizedBox(height: 12),
            asyncAccounts.maybeWhen(
              data: (accounts) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _accountAndCategoryFields(accounts),
              ),
              orElse: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
              ),
              maxLength: 100,
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _save,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? '저장' : '추가'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _accountAndCategoryFields(List<Account> accounts) {
    final widgets = <Widget>[];
    if (_expectsFrom()) {
      widgets.add(_AccountDropdown(
        label: _type == TxType.transfer ? '보내는 계좌' : '계좌',
        accounts: accounts,
        value: _fromAccountId,
        excludedId: _type == TxType.transfer ? _toAccountId : null,
        onChanged: (v) => setState(() => _fromAccountId = v),
      ));
      widgets.add(const SizedBox(height: 12));
    }
    if (_expectsTo()) {
      widgets.add(_AccountDropdown(
        label: _type == TxType.transfer ? '받는 계좌' : '계좌',
        accounts: accounts,
        value: _toAccountId,
        excludedId: _type == TxType.transfer ? _fromAccountId : null,
        onChanged: (v) => setState(() => _toAccountId = v),
      ));
      widgets.add(const SizedBox(height: 12));
    }
    if (_expectsCategory()) {
      widgets.add(CategoryPicker(
        kind: _type == TxType.expense
            ? CategoryKind.expense
            : CategoryKind.income,
        selectedId: _categoryId,
        onChanged: (v) => setState(() => _categoryId = v),
      ));
    }
    return widgets;
  }
}

// ── 부분 위젯 ──────────────────────────────────────────────────────────────

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.value, required this.onChanged});
  final TxType value;
  final ValueChanged<TxType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TxType>(
      segments: const [
        ButtonSegment(value: TxType.expense, label: Text('지출')),
        ButtonSegment(value: TxType.income, label: Text('수입')),
        ButtonSegment(value: TxType.transfer, label: Text('이체')),
        ButtonSegment(value: TxType.valuation, label: Text('평가')),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _AccountDropdown extends StatelessWidget {
  const _AccountDropdown({
    required this.label,
    required this.accounts,
    required this.value,
    required this.onChanged,
    this.excludedId,
  });

  final String label;
  final List<Account> accounts;
  final int? value;
  final int? excludedId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final filtered = accounts.where((a) => a.id != excludedId).toList();
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          isExpanded: true,
          hint: const Text('선택'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('— 없음 —')),
            for (final a in filtered)
              DropdownMenuItem(value: a.id, child: Text(a.name)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// _CategoryChips는 M3 categories-ui에서 CategoryPicker로 swap.

// Reuse existing thousands formatter pattern.
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final clean = newValue.text.replaceAll(',', '');
    final parsed = int.tryParse(clean);
    if (parsed == null) return oldValue;
    final formatted = Money.format(parsed);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
