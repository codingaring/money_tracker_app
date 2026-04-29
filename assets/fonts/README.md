# Pretendard Fonts

Pretendard는 한국어/영문 통합 sans-serif 폰트 (OFL 라이선스).

## 다운로드

1. https://github.com/orioncactus/pretendard/releases 에서 최신 release 다운로드
2. zip 압축 풀고 `public/static/` 안에서 4개 파일을 이 디렉터리(`assets/fonts/`)로 복사:
   - `Pretendard-Regular.otf` (weight 400)
   - `Pretendard-Medium.otf` (weight 500)
   - `Pretendard-SemiBold.otf` (weight 600)
   - `Pretendard-Bold.otf` (weight 700)

또는 단일 명령:

```bash
# (수동) Windows 기준
# 1) https://github.com/orioncactus/pretendard/releases/download/v1.3.9/Pretendard-1.3.9.zip 에서 zip 받기
# 2) 압축풀기 후 /public/static/Pretendard-Regular.otf 등 4개 파일을 여기로 복사
```

## Fallback 동작

폰트 파일이 없으면 Flutter가 자동으로 시스템 폰트(Roboto/SF/Noto)로 fallback. 앱은 정상 작동하지만 reference 톤은 살지 않음.

## 라이선스

Pretendard는 SIL Open Font License 1.1 — 상업적 사용 가능, 재배포 가능, 수정 가능. 이 디렉터리에 LICENSE 파일을 함께 두는 게 좋음 (release 배포 시).
