// Shared formatting helpers for KRW + dates (M1 Korean only).

import 'package:intl/intl.dart';

class Money {
  const Money._();

  static final _grouping = NumberFormat('#,##0');
  static final _signed = NumberFormat('+#,##0;-#,##0;0');

  /// `12,000` (no symbol — caller adds ₩ where appropriate).
  static String format(int amount) => _grouping.format(amount);

  /// `+12,000` / `-12,000` / `0`. Used when sign matters (income vs expense).
  static String formatSigned(int amount) => _signed.format(amount);

  /// `₩ 12,000` / `-₩ 12,000` (negative sign before symbol).
  static String formatKrw(int amount) {
    if (amount < 0) return '-₩ ${_grouping.format(-amount)}';
    return '₩ ${_grouping.format(amount)}';
  }
}

class DateLabels {
  const DateLabels._();

  static const List<String> _dows = ['월', '화', '수', '목', '금', '토', '일'];

  /// `2026-04-28 (월)`.
  static String dateWithDow(DateTime d) {
    final ymd = '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final dow = _dows[d.weekday - 1];
    return '$ymd ($dow)';
  }

  /// `2026-04-28` only.
  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Relative time for sync status — "2분 전", "3시간 전", "어제", or absolute.
  static String relativeAgo(DateTime? at) {
    if (at == null) return '없음';
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 60) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return ymd(at);
  }
}
