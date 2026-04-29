// Design Ref: §4.1 — TxTemplate은 Drift @DataClassName('TxTemplate') 자동 생성.
// 별도 도메인 클래스 없이 Drift row를 그대로 사용. 단, FK 유효성 검증을 위한
// helper extension만 정의.

import '../../../core/db/app_database.dart';

extension TxTemplateValidation on TxTemplate {
  /// All referenced FK IDs (account/category) are still valid in the current
  /// DB. UI에서 stale FK가 있는 템플릿에 "유효하지 않음" 경고 표시 + Repository
  /// 사용 시점에 NULL로 fallback.
  bool isResolvableWith({
    required Set<int> validAccountIds,
    required Set<int> validCategoryIds,
  }) {
    if (fromAccountId != null && !validAccountIds.contains(fromAccountId)) {
      return false;
    }
    if (toAccountId != null && !validAccountIds.contains(toAccountId)) {
      return false;
    }
    if (categoryId != null && !validCategoryIds.contains(categoryId)) {
      return false;
    }
    return true;
  }
}
