# 전표철

전장 · 선팅 · 덴트 시공 매출 전표와 지출을 **두 사람이 같이 쓰는 장부**입니다.
GitHub Pages 로 배포하고, 안드로이드 폰에서 앱처럼 씁니다.

---

## 먼저 알아 둘 것 — "안드로이드 앱"과 GitHub Pages

GitHub Pages 는 정적 파일만 서빙합니다. 그래서 **네이티브 APK 를 GitHub Pages 에 올려
앱스토어처럼 배포·실행할 수는 없습니다.** 대신 이 프로젝트는 **PWA(설치형 웹앱)** 입니다.

| 하고 싶은 것 | 이 프로젝트에서 되는 방식 |
|---|---|
| 안드로이드 홈 화면에 아이콘 | 크롬에서 열고 **⋮ → 홈 화면에 추가**. 전체화면·아이콘·스플래시 모두 네이티브와 동일 |
| 오프라인 실행 | Service Worker 로 앱 껍데기 캐시 |
| 두 사람이 같은 자료 | Supabase Postgres + Realtime |
| 로그인 | Supabase Auth (이메일 / 비밀번호) |
| 진짜 `.apk` 파일 | 아래 **Capacitor** 항목 참고 (같은 코드 그대로 감쌈) |

---

## 1. Supabase 준비 (5분)

1. [supabase.com](https://supabase.com) 에서 프로젝트를 만듭니다.
2. **SQL Editor** 에 [`supabase/schema.sql`](supabase/schema.sql) 을 통째로 붙여넣고 **Run**.
   테이블 · 인덱스 · RLS 정책 · 실시간 구독이 한 번에 만들어집니다.
3. **Authentication → Users → Add user** 로 쓸 사람 2명을 만듭니다.
   (Auto Confirm User 를 켜면 이메일 인증 없이 바로 로그인됩니다.)
4. **Authentication → Providers → Email** 에서 **Enable sign-ups** 를 **끕니다.**
   두 사람 계정을 만든 뒤 꺼야 아무나 가입하지 못합니다.
5. **Project Settings → API** 에서 `Project URL` 과 `anon public` 키를 복사합니다.
6. [`config.js`](config.js) 에 붙여넣습니다.

```js
window.APP_CONFIG = {
  SUPABASE_URL: "https://xxxxxxxx.supabase.co",
  SUPABASE_ANON_KEY: "eyJhbGciOi..."
};
```

> `anon` 키는 공개 저장소에 올라가도 됩니다. 실제 보호는 `schema.sql` 의 RLS 정책이
> 합니다 — `members` 테이블에 등록된 두 사람만 읽고 쓸 수 있습니다.
> 앱 안 **설정 → Supabase 연결 설정** 에서 넣으면 `config.js` 를 안 고쳐도 됩니다.

---

## 2. GitHub Pages 배포

```bash
git init && git add -A && git commit -m "전표철"
git branch -M main
git remote add origin https://github.com/<사용자명>/<저장소명>.git
git push -u origin main
```

저장소 **Settings → Pages → Build and deployment**
→ Source `Deploy from a branch`, Branch `main` / `/ (root)` → **Save**.

1~2분 뒤 `https://<사용자명>.github.io/<저장소명>/` 에서 열립니다.
빌드 과정이 없으므로 파일을 push 하면 그대로 반영됩니다.

마지막으로 Supabase **Authentication → URL Configuration → Site URL** 에
그 주소를 넣어 주세요.

### 안드로이드에 설치

크롬으로 주소를 열고 **⋮ → 앱 설치 / 홈 화면에 추가**.
이후에는 주소창 없이 전체화면으로 뜹니다.

---

## 3. 진짜 APK 가 필요하면 (선택)

같은 코드를 그대로 감싸서 네이티브 패키지로 만듭니다.

```bash
npm init -y
npm i -D @capacitor/cli @capacitor/core @capacitor/android
npx cap init 전표철 com.example.jeonpyo --web-dir=.
npx cap add android
npx cap sync
npx cap open android    # Android Studio 에서 Build > Build APK
```

`capacitor.config.json` 의 `server.url` 을 GitHub Pages 주소로 두면
APK 를 다시 만들지 않아도 웹만 push 해서 업데이트할 수 있습니다.

---

## 화면

| 탭 | 하는 일 |
|---|---|
| **매출 전표** | 기간 + 상사명·딜러명·차량번호를 각각 따로 검색, 작업 종류 / 미수금 필터, 카드↔표 전환, 하단 고정 합계 |
| **거래처** | 상사별 집계와 작업 구성, 클릭하면 그 거래처 전표 전부 + 총계 |
| **지출** | 내역 · 그래프(세금 포함) · 세금 계산 · 통합 정리 |
| **달력** | 날짜별로 들어온 돈 / 나간 돈. 날짜를 누르면 그날 전표와 지출이 펼쳐지고, 거기서 바로 입력도 됩니다. 정기 지출은 매달 자동으로 찍힙니다 |
| **매출 분석** | 전장 / 선팅 / 덴트 매출 구성과 마진율 |

**달력 탭의 계산 기준** — "들어온 돈"은 전표 날짜의 `견적가 − 미수금`(그날 실제로 받은 돈), "나간 돈"은 그날 지출입니다.
미수금이 있는 날은 칸 오른쪽 위에 노란 점이 찍힙니다. 정기 지출은 등록한 달부터 잡히므로 그 전 달로 소급되지 않습니다.

모든 화면에 **엑셀 내보내기** 가 있습니다. `.xlsx` 로 받고, 네트워크가 막혀 있으면
Excel 이 바로 여는 UTF-8 CSV 로 대체됩니다.

### 세금 계산

* **부가세** = (매출액 − 원가) × 10% — 요청하신 산식 그대로입니다.
* **종합소득세** = 사업소득금액(매출 − 원가 − 지출)에서 인적공제를 뺀 과세표준에
  2026년 기준 8단계 누진세율표를 적용하고, 산출세액에 지방소득세 10% 를 더합니다.
  인적공제 인원과 세액공제는 화면에서 바로 바꿀 수 있습니다.
  실제 신고 시에는 노란우산·연금·의료비 등 추가 공제로 달라지므로 **추정치**입니다.

---

## 파일

```
index.html            화면 구조
config.js             Supabase 연결 정보 (여기만 채우면 됨)
assets/styles.css     디자인 토큰과 전체 스타일
assets/app.js         화면 · 폼 · 이벤트
assets/store.js       Supabase / localStorage 데이터 계층 + 실시간 동기화
assets/calc.js         집계 · 세금 · 포맷
assets/charts.js      의존성 없는 SVG 도넛 차트
assets/xlsx.js        엑셀 내보내기 (SheetJS, CSV 대체)
sw.js                 오프라인 캐시
supabase/schema.sql   테이블 · RLS · 실시간
```

빌드 도구도 프레임워크도 없습니다. 파일을 열면 바로 돌아갑니다.

## 로컬에서 열어 보기

```bash
python3 -m http.server 8080
```

`http://localhost:8080` 에서 **"서버 없이 이 기기에서만 쓰기"** 를 누르면
예시 전표가 들어간 상태로 바로 둘러볼 수 있습니다.
