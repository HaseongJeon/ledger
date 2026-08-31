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
| 진짜 `.apk` 파일 | Capacitor 로 감싸 GitHub Actions 가 빌드합니다 — [3번 항목](#3-안드로이드-설치-파일-apk) |

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
globalThis.APP_CONFIG = {
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

## 3. 안드로이드 설치 파일 (APK)

같은 코드를 Capacitor 로 감싸 APK 를 만듭니다. **빌드는 GitHub 가 대신 합니다** —
맥에 Android SDK 를 깔 필요가 없습니다.

### 내려받기

| 상황 | 어디서 |
|---|---|
| 정식 배포판 | 저장소 **Releases** 탭 → 최신 버전의 `.apk` |
| 최신 커밋 빌드 | **Actions** 탭 → 최근 `Android APK` 실행 → 아래 **Artifacts** |

### 새 배포판 내기

```bash
npm version patch -m "전표철 %s"   # package.json 버전 올리고 커밋
git push && git push --tags
```

태그를 밀면 워크플로가 APK 를 빌드해 Releases 에 첨부합니다. `main` 에 그냥 푸시하면
Releases 에는 안 올라가고 Actions 의 Artifacts 로만 남습니다.

### 설치

내려받은 `.apk` 를 안드로이드에서 실행하고, 물어보면 **"출처를 알 수 없는 앱 설치"** 를 허용하세요.
**디버그 서명**이라 Play 스토어에는 올릴 수 없지만 기기에 직접 설치하는 데는 문제가 없습니다.
정식 서명이 필요해지면 keystore 를 만들어 `android/app/build.gradle` 에 `signingConfigs` 를 추가하고
워크플로에서 `assembleRelease` 로 바꾸면 됩니다.

### 맥에서 직접 빌드하려면

JDK 17 과 Android SDK 가 필요합니다 (약 2~3GB).

```bash
npm install
npm run apk          # www 준비 → cap sync → gradlew assembleDebug
```

결과물: `android/app/build/outputs/apk/debug/app-debug.apk`

### 아이콘

`assets/icon.svg` 와 `scripts/icon-foreground.svg` 에서 만듭니다. 아이콘을 고쳤다면
`./scripts/make-icons.sh` 를 실행하세요 (macOS 전용). 생성된 PNG 는 커밋되므로 CI 는 손대지 않습니다.

---

## 4. 크로스 기기 알림 (선택)

한 사람이 전표·지출을 추가하면 **앱이 꺼져 있는** 다른 기기에도 알림이 갑니다.
안 하고 그냥 둬도 나머지 기능은 전부 그대로 동작합니다 — 이 절이 없으면 알림만 안 올 뿐입니다.

| 기기 | 완전 종료 상태에서도 오나요 |
|---|---|
| 안드로이드 APK | 옵니다 (FCM) |
| 데스크톱 브라우저 / PWA | 옵니다 (FCM Web Push) — 브라우저의 "백그라운드 실행" 설정에 따라 다를 수 있음 |
| Windows 데스크톱 앱 ([ledger-windows](https://github.com/HaseongJeon/ledger-windows)) | 창을 닫아도 트레이에 상주하는 동안만 옵니다. 트레이의 **"종료"**로 완전히 끄면 다음 실행 때 최신 내역이 바로 보이는 것으로 대신합니다 (FCM은 안 씀 — 유지보수가 끊긴 라이브러리에 의존해야 해서 일부러 뺐습니다) |

### 준비물

1. [Firebase 콘솔](https://console.firebase.google.com) 에서 프로젝트 생성 (무료 Spark 요금제로 충분).
   * **프로젝트 설정 → 일반** 에서 **웹 앱** 을 하나 등록 → 나오는 값(`apiKey`, `authDomain`, `projectId`,
     `messagingSenderId`, `appId`)을 [`config.js`](config.js) 의 `FIREBASE` 블록에 채웁니다.
   * **프로젝트 설정 → Cloud Messaging** 탭 → **웹 푸시 인증서** 생성 → 나오는 키를 `vapidKey` 에 채웁니다.
   * **프로젝트 설정 → 일반 → 내 앱** 에서 **Android 앱** 도 하나 등록 (패키지 이름 `com.jeonpyo.ledger`) →
     `google-services.json` 을 내려받아 `android/app/google-services.json` 에 둡니다 (커밋하지 않음).
   * **프로젝트 설정 → 서비스 계정** → **새 비공개 키 생성** → JSON 파일을 받아 둡니다 (다음 단계에서 씀).
2. [Supabase CLI](https://supabase.com/docs/guides/cli) 로 Edge Function 배포:
   ```bash
   supabase login
   supabase link --project-ref dotsiylmhwfoadvixnoi
   supabase functions deploy notify-entry --no-verify-jwt
   supabase secrets set \
     NOTIFY_WEBHOOK_SECRET="임의의 긴 무작위 문자열" \
     FCM_PROJECT_ID="Firebase 프로젝트 ID" \
     FCM_SERVICE_ACCOUNT="$(cat 서비스계정.json)"
   ```
3. **SQL Editor** 에서 `NOTIFY_WEBHOOK_SECRET` 과 **똑같은 값**으로 한 번만 실행 (`supabase/schema.sql`
   7번 섹션에 이미 안내되어 있음):
   ```sql
   select vault.create_secret('임의의 긴 무작위 문자열', 'notify_webhook_secret');
   ```
   그 뒤 `supabase/schema.sql` 을 (처음 설정 때처럼) SQL Editor 에 다시 통째로 붙여넣고 Run 하면
   `push_tokens` 테이블과 트리거가 만들어집니다.
4. 안드로이드 APK 를 GitHub Actions 로 계속 빌드한다면, 저장소 **Settings → Secrets and variables →
   Actions** 에 `GOOGLE_SERVICES_JSON` 이름으로 위 JSON 파일의 **내용 전체**를 등록하세요. 안 하면
   알림 기능만 빠진 채 지금처럼 빌드됩니다.

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
assets/push.js        크로스 기기 알림 (Android FCM / 웹 Web Push / Electron 알림)
sw.js                 오프라인 캐시
firebase-messaging-sw.js  브라우저가 꺼져 있어도 알림 받는 별도 서비스워커
supabase/schema.sql   테이블 · RLS · 실시간 · push_tokens · 알림 트리거
supabase/functions/notify-entry  새 전표/지출을 FCM으로 쏘는 Edge Function

capacitor.config.json APK 용 앱 이름 · 패키지 이름
scripts/build-www.mjs 앱 파일만 www/ 로 모으기 (APK 에 node_modules 가 들어가지 않게)
scripts/make-icons.sh SVG → 런처 아이콘 PNG (macOS)
android/              Capacitor 가 만든 네이티브 프로젝트
.github/workflows/android.yml   APK 빌드
```

빌드 도구도 프레임워크도 없습니다. 파일을 열면 바로 돌아갑니다.

## 글꼴

**Pretendard** 한 벌만 씁니다 (jsDelivr CDN, dynamic subset). 숫자용 고정폭 서체를 따로 두지 않고
`font-variant-numeric: tabular-nums`로 자릿수를 맞춥니다 — 한글 글리프가 없는 고정폭 서체에
`합계 · 8건`이나 번호판의 `가·버·도`가 섞이면 그 글자만 시스템 서체로 떨어지기 때문입니다.

오프라인에서도 쓰려면 [Pretendard 릴리스](https://github.com/orioncactus/pretendard/releases)의
`woff2`를 `assets/fonts/`에 넣고 `@font-face`로 직접 선언하면 됩니다. CDN이 막혀도
`-apple-system` / `Malgun Gothic`으로 자연스럽게 떨어집니다.

## 로컬에서 열어 보기

```bash
python3 -m http.server 8080
```

`http://localhost:8080` 에서 **"서버 없이 이 기기에서만 쓰기"** 를 누르면
예시 전표가 들어간 상태로 바로 둘러볼 수 있습니다.
