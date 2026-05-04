// Design Ref: §5.5 — Account / sync / Sheets / version.
// Plan SC: FR-15 (sync status + sheet link), FR-09 (sign in flow surface).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../../core/ui/money_format.dart';
import '../../../infrastructure/sheets/sheets_client.dart';
import '../../accounts/data/balance_reconciler.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/data/category_seed.dart';
import '../../sync/service/sync_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _syncing = false;
  bool _reconciling = false;
  bool _resetting = false;
  String? _email;
  DateTime? _lastSyncAt;
  String? _spreadsheetId;
  String? _flashMessage;
  BalanceReconcileResult? _reconcileResult;

  @override
  void initState() {
    super.initState();
    _loadKvBackedState();
  }

  Future<void> _loadKvBackedState() async {
    final auth = ref.read(googleAuthProvider);
    final email = await auth.currentEmail();
    final lastSyncStr = await _readKv('last_sync_at');
    final id = await _readKv('spreadsheet_id');
    if (!mounted) return;
    setState(() {
      _email = email;
      _lastSyncAt =
          lastSyncStr == null ? null : DateTime.tryParse(lastSyncStr);
      _spreadsheetId = id;
    });
  }

  Future<String?> _readKv(String key) async {
    final db = ref.read(appDatabaseProvider);
    final row = await (db.select(db.kvStore)
          ..where((k) => k.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _signIn() async {
    final auth = ref.read(googleAuthProvider);
    final ok = await auth.signIn();
    if (ok) {
      final email = await auth.currentEmail();
      if (mounted) setState(() => _email = email);
    }
  }

  Future<void> _signOut() async {
    await ref.read(googleAuthProvider).signOut();
    if (mounted) setState(() => _email = null);
  }

  Future<void> _flushNow() async {
    setState(() {
      _syncing = true;
      _flashMessage = null;
    });
    try {
      final auth = ref.read(googleAuthProvider);
      if (!await auth.isSignedIn()) {
        setState(() => _flashMessage = '먼저 로그인하세요');
        return;
      }
      final client = await auth.authenticatedClient();
      if (client == null) {
        setState(() => _flashMessage = 'AuthClient 발급 실패 — 재로그인 필요');
        return;
      }
      final db = ref.read(appDatabaseProvider);
      final svc = SyncService(
        db: db,
        accountsDao: ref.read(accountsDaoProvider),
        transactionsDao: ref.read(transactionsDaoProvider),
        templatesDao: ref.read(templatesDaoProvider),
        queueDao: ref.read(syncQueueDaoProvider),
        sheets: SheetsClient(client),
        auth: auth,
      );
      final result = await svc.flush();
      if (!mounted) return;
      setState(() {
        _flashMessage = result.isSuccess
            ? '동기화 완료 (+${result.txAppended} ~${result.txUpdated} -${result.txCleared})'
            : '동기화 실패: ${result.error ?? result.skippedReason}';
      });
      await _loadKvBackedState();
    } catch (e) {
      if (mounted) setState(() => _flashMessage = '동기화 오류: $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _runIntegrityCheck() async {
    setState(() {
      _reconciling = true;
      _reconcileResult = null;
    });
    try {
      final result =
          await ref.read(balanceReconcilerProvider).compute();
      if (mounted) setState(() => _reconcileResult = result);
    } catch (e) {
      if (mounted) {
        setState(() => _flashMessage = '무결성 검증 오류: $e');
      }
    } finally {
      if (mounted) setState(() => _reconciling = false);
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('전체 데이터 초기화'),
        content: const Text(
          '거래 내역, 계좌, 템플릿, 반복 거래, 예산이 모두 삭제됩니다.\n'
          '기본 카테고리는 다시 생성됩니다.\n\n'
          '이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _resetAllData();
  }

  Future<void> _resetAllData() async {
    setState(() => _resetting = true);
    try {
      final db = ref.read(appDatabaseProvider);
      await db.transaction(() async {
        await db.delete(db.transactions).go();
        await db.delete(db.syncQueue).go();
        await db.delete(db.recurringRules).go();
        await db.delete(db.budgets).go();
        await db.delete(db.txTemplates).go();
        await db.delete(db.accounts).go();
        await db.delete(db.categories).go();
        await db.delete(db.kvStore).go();
      });
      await CategorySeeder(CategoryRepository(db)).run();
      if (!mounted) return;
      setState(() {
        _email = null;
        _lastSyncAt = null;
        _spreadsheetId = null;
        _reconcileResult = null;
        _flashMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초기화 완료')),
      );
    } catch (e) {
      if (mounted) setState(() => _flashMessage = '초기화 오류: $e');
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  Future<void> _openSheet() async {
    if (_spreadsheetId == null) return;
    final url = Uri.parse(
        'https://docs.google.com/spreadsheets/d/$_spreadsheetId/edit');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(syncPendingCountProvider).valueOrNull ?? 0;
    final signedInAsync = ref.watch(authSignedInProvider);

    // Refresh email when sign-in state changes.
    ref.listen(authSignedInProvider, (prev, next) {
      next.whenData((signed) async {
        if (signed) {
          final email = await ref.read(googleAuthProvider).currentEmail();
          if (mounted) setState(() => _email = email);
        } else {
          if (mounted) setState(() => _email = null);
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('계정'),
          Card(
            child: signedInAsync.when(
              loading: () => const ListTile(
                leading: CircularProgressIndicator(),
                title: Text('확인 중...'),
              ),
              error: (e, _) => ListTile(
                leading: const Icon(Icons.error),
                title: Text('상태 확인 실패: $e'),
              ),
              data: (signed) {
                if (!signed || _email == null) {
                  return ListTile(
                    leading: const Icon(Icons.login),
                    title: const Text('Google 로그인'),
                    subtitle: const Text('Sheets 동기화에 필요합니다'),
                    trailing: FilledButton(
                      // theme의 Size.fromHeight(52) (= minWidth Infinity) override —
                      // ListTile.trailing의 좁은 slot에서 layout 깨짐 방지.
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(72, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: _signIn,
                      child: const Text('로그인'),
                    ),
                  );
                }
                return ListTile(
                  leading: const Icon(Icons.account_circle),
                  title: Text(_email!),
                  trailing: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: _signOut,
                    child: const Text('로그아웃'),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          _SectionTitle('데이터 관리'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.bookmark_outline_rounded),
                  title: const Text('거래 템플릿 관리'),
                  subtitle: const Text('자주 쓰는 거래를 저장해두면 입력이 빨라집니다'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/settings/templates'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.label_outline_rounded),
                  title: const Text('카테고리 관리'),
                  subtitle: const Text('대분류·소분류로 정리하면 분석이 더 정확해집니다'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/settings/categories'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.repeat_rounded),
                  title: const Text('반복 거래 관리'),
                  subtitle: const Text('매월 고정 지출·수입을 등록해두면 알림을 받습니다'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/settings/recurring'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.savings_outlined),
                  title: const Text('예산 관리'),
                  subtitle: const Text('카테고리별 월 한도를 설정하면 분석 탭에서 초과 여부를 확인합니다'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/settings/budget'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _SectionTitle('동기화'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _KeyValueRow(
                    label: '미동기화 거래',
                    value: '$pendingCount건',
                    valueIsHighlight: pendingCount > 0,
                  ),
                  const SizedBox(height: 8),
                  _KeyValueRow(
                    label: '마지막 성공',
                    value: DateLabels.relativeAgo(_lastSyncAt),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _syncing ? null : _flushNow,
                    icon: _syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_sync),
                    label: const Text('지금 동기화'),
                  ),
                  if (_flashMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(_flashMessage!,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _SectionTitle('Google Sheets'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_spreadsheetId == null)
                    Text(
                      '아직 시트가 생성되지 않았습니다.\n로그인 + [지금 동기화]를 누르면 자동 생성됩니다.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    )
                  else ...[
                    _KeyValueRow(
                      label: '시트 ID',
                      value: '${_spreadsheetId!.substring(0, 8)}...',
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openSheet,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Sheets에서 보기'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _SectionTitle('무결성'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '저장된 계좌 잔액과 거래 내역으로 재계산한 잔액이 일치하는지 검증합니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _reconciling ? null : _runIntegrityCheck,
                    icon: _reconciling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fact_check),
                    label: const Text('잔액 재계산 검증'),
                  ),
                  if (_reconcileResult != null) ...[
                    const SizedBox(height: 12),
                    _ReconcileResultCard(result: _reconcileResult!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          _SectionTitle('초기화'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '거래 내역, 계좌, 템플릿, 반복 거래, 예산을 모두 삭제합니다. '
                    '기본 카테고리는 다시 생성됩니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _resetting ? null : _confirmReset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).colorScheme.error,
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.error),
                    ),
                    icon: _resetting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_sweep_outlined),
                    label: const Text('전체 데이터 초기화'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _SectionTitle('정보'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Money Tracker'),
              subtitle: const Text('v0.2.0  ·  M1 Personal Build'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReconcileResultCard extends StatelessWidget {
  const _ReconcileResultCard({required this.result});

  final BalanceReconcileResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (result.isClean) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: theme.colorScheme.tertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.backfilledCount > 0
                    ? '계좌 ${result.reports.length}건 검증 완료 — '
                        '${result.backfilledCount}건은 v0.2 이전 생성으로 baseline backfill됨'
                    : '계좌 ${result.reports.length}건 모두 잔액 일치 ✅',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.warning, color: theme.colorScheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${result.driftCount}건의 계좌에서 잔액 불일치 발견',
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...result.reports.where((d) => d.hasDrift).map(
              (d) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(d.accountName),
                subtitle: Text(
                  '저장됨 ${Money.format(d.storedBalance)}  ·  '
                  '재계산 ${Money.format(d.expectedBalance)}  '
                  '(${d.txCount}건)',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: Text(
                  '차이 ${Money.formatSigned(d.drift)}',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 12),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.label,
    required this.value,
    this.valueIsHighlight = false,
  });

  final String label;
  final String value;
  final bool valueIsHighlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueIsHighlight ? theme.colorScheme.error : null,
          ),
        ),
      ],
    );
  }
}

