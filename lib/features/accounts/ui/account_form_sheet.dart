// Design Ref: §5.6 — AccountFormSheet (M2 확장).
// M1: name, type, initial balance (create only), is_active (edit only).
// M2: due_day (credit_card 분기), parent_account_id (cash 아닐 때 dropdown).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/ui/money_format.dart';
import '../domain/account.dart';

class AccountFormSheet extends ConsumerStatefulWidget {
  const AccountFormSheet({super.key, this.existing});

  final Account? existing;

  @override
  ConsumerState<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<AccountFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late final TextEditingController _noteController;
  late AccountType _type;
  late bool _isActive;
  int? _dueDay;
  int? _parentAccountId;
  List<Account>? _candidateParents; // cash-type others, loaded once.
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _balanceController = TextEditingController(
      text: e == null ? '' : Money.format(e.balance),
    );
    _noteController = TextEditingController(text: e?.note ?? '');
    _type = e?.type ?? AccountType.cash;
    _isActive = e?.isActive ?? true;
    _dueDay = e?.dueDay;
    _parentAccountId = e?.parentAccountId;
    _loadParentCandidates();
  }

  Future<void> _loadParentCandidates() async {
    // Plan SC: FR-29 — parent dropdown sources cash-type accounts only,
    // excluding self to prevent cycles.
    final dao = ref.read(accountsDaoProvider);
    final all = await dao.readAll();
    if (!mounted) return;
    setState(() {
      _candidateParents = all
          .where((a) => a.type == AccountType.cash)
          .where((a) => a.id != widget.existing?.id)
          .toList();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '계좌명을 입력하세요');
      return;
    }
    if (_type == AccountType.creditCard && _dueDay == null) {
      setState(() => _error = '신용카드는 결제일을 입력하세요');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(accountRepositoryProvider);
      if (_isEdit) {
        // type changed cash → credit_card or vice versa: clear stale fields.
        final priorType = widget.existing!.type;
        final typeChanged = priorType != _type;
        await repo.updateMeta(
          widget.existing!.id,
          name: name,
          type: _type,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          isActive: _isActive,
          dueDay: _type == AccountType.creditCard ? _dueDay : null,
          clearDueDay:
              typeChanged && _type != AccountType.creditCard,
          parentAccountId:
              _type == AccountType.cash ? null : _parentAccountId,
          clearParent:
              _type == AccountType.cash || _parentAccountId == null,
        );
      } else {
        final balance = int.tryParse(
                _balanceController.text.replaceAll(',', '')) ??
            0;
        await repo.create(
          name: name,
          type: _type,
          initialBalance: balance,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          dueDay: _type == AccountType.creditCard ? _dueDay : null,
          parentAccountId:
              _type == AccountType.cash ? null : _parentAccountId,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(_isEdit ? '계좌 수정' : '계좌 추가',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '계좌명',
                border: OutlineInputBorder(),
              ),
              maxLength: 40,
            ),
            const SizedBox(height: 12),
            _TypeSelector(
              value: _type,
              onChanged: (v) => setState(() {
                _type = v;
                // Reset type-conditioned fields when leaving their domain.
                if (v != AccountType.creditCard) _dueDay = null;
                if (v == AccountType.cash) _parentAccountId = null;
              }),
            ),
            const SizedBox(height: 12),
            if (!_isEdit)
              TextField(
                controller: _balanceController,
                decoration: InputDecoration(
                  prefixText: '₩  ',
                  labelText: '초기 잔액',
                  helperText: _type == AccountType.creditCard ||
                          _type == AccountType.loan
                      ? '부채는 음수로 입력 (예: -1500000)'
                      : null,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    signed: true, decimal: false),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,\-]')),
                ],
              ),
            if (_type == AccountType.creditCard) ...[
              const SizedBox(height: 12),
              _DueDayPicker(
                value: _dueDay,
                onChanged: (v) => setState(() => _dueDay = v),
              ),
            ],
            if (_type != AccountType.cash) ...[
              const SizedBox(height: 12),
              _ParentDropdown(
                candidates: _candidateParents,
                value: _parentAccountId,
                onChanged: (v) => setState(() => _parentAccountId = v),
              ),
            ],
            if (_isEdit) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('활성'),
                subtitle: Text(_isActive ? '거래 입력에서 선택 가능' : '비활성 (목록 회색 처리)'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '비고 (선택)',
                border: OutlineInputBorder(),
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
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
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
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.value, required this.onChanged});

  final AccountType value;
  final ValueChanged<AccountType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AccountType.values
          .map((t) => ChoiceChip(
                label: Text(_label(t)),
                selected: t == value,
                onSelected: (sel) {
                  if (sel) onChanged(t);
                },
              ))
          .toList(),
    );
  }

  String _label(AccountType t) => switch (t) {
        AccountType.cash => '현금',
        AccountType.investment => '투자',
        AccountType.savings => '저축',
        AccountType.realEstate => '부동산',
        AccountType.creditCard => '신용카드',
        AccountType.loan => '대출',
      };
}

class _DueDayPicker extends StatelessWidget {
  const _DueDayPicker({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    // 1-28 only — Design §3.1 + Plan §7 (2월 안전, M2 단일 dueDay).
    final items = List<int>.generate(28, (i) => i + 1);
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: '결제일',
        helperText: '매월 결제일 (1-28). 변동 결제일은 M3에서 보완.',
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          hint: const Text('결제일을 선택'),
          items: items
              .map((d) => DropdownMenuItem(
                    value: d,
                    child: Text('$d일'),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ParentDropdown extends StatelessWidget {
  const _ParentDropdown({
    required this.candidates,
    required this.value,
    required this.onChanged,
  });

  final List<Account>? candidates;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (candidates == null) {
      return const _ParentLoadingBox();
    }
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: '부모 계좌 (선택)',
        helperText: '이 계좌가 결제·정산되는 통장. 비우면 독립 표시.',
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          isExpanded: true,
          hint: const Text('없음 (독립 표시)'),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('— 없음 —'),
            ),
            for (final a in candidates!)
              DropdownMenuItem<int?>(
                value: a.id,
                child: Text(a.name),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ParentLoadingBox extends StatelessWidget {
  const _ParentLoadingBox();

  @override
  Widget build(BuildContext context) {
    return const InputDecorator(
      decoration: InputDecoration(
        labelText: '부모 계좌',
        border: OutlineInputBorder(),
      ),
      child: SizedBox(
        height: 24,
        child: Center(
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))),
      ),
    );
  }
}
