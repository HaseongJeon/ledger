-- ═══════════════════════════════════════════════════════════════
--  전표철 — Supabase 스키마
--  Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 Run 하세요.
--  계정마다 완전히 분리된 개인 장부입니다 — 자신이 만든 행만 읽고 씁니다.
-- ═══════════════════════════════════════════════════════════════

-- 예전 버전에서 쓰던 "공용 장부(멤버 등록)" 구조는 더 이상 안 씁니다.
-- is_member() 를 쓰던 예전 RLS 정책들은 cascade 로 같이 지워지고, 아래 4번에서 새로 만듭니다.
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.auto_enroll();
drop table if exists public.members cascade;
drop function if exists public.is_member() cascade;

-- ── 2. 매출 전표 ─────────────────────────────────────────────
create table if not exists public.cases (
  id          uuid primary key default gen_random_uuid(),
  date        date not null,
  company     text not null,                       -- 상사명
  dealer      text,                                -- 딜러명
  phone       text,                                -- 연락처
  car_model   text,                                -- 차종
  plate       text,                                -- 차량번호
  items       jsonb not null default '[]'::jsonb,  -- [{type:'전장'|'선팅'|'덴트', price, cost}, ...] 작업내용별 금액
  price       numeric(14,0) not null default 0,    -- 견적가
  pay_method  text not null default '카드' check (pay_method in ('카드','현금','세금계산서')),
  unpaid      numeric(14,0) not null default 0,    -- 미수금
  cost        numeric(14,0) not null default 0,    -- 원가
  note        text,                                -- 비고
  created_at  timestamptz not null default now(),
  created_by  uuid default auth.uid(),
  constraint unpaid_not_over_price check (unpaid <= price)
);

create index if not exists cases_date_idx    on public.cases (date desc);
create index if not exists cases_company_idx on public.cases (company);
create index if not exists cases_dealer_idx  on public.cases (dealer);
create index if not exists cases_plate_idx   on public.cases (plate);

-- ── 3. 지출 ──────────────────────────────────────────────────
create table if not exists public.expenses (
  id            uuid primary key default gen_random_uuid(),
  amount        numeric(14,0) not null default 0,
  category      text not null check (category in (
                  '급여','외주비','복리후생비','통신비','관리비','접대비','지급임차료',
                  '수선비','보험료','차량유지비','소모품비','지급수수료','잡비','잡손실')),
  recurring     boolean not null default false,     -- 정기 지출 여부
  day_of_month  smallint check (day_of_month between 1 and 31),
  date          date,                               -- 1회성 지출 날짜 / 정기 지출 시작일
  note          text,
  created_at    timestamptz not null default now(),
  created_by    uuid default auth.uid(),
  constraint recurring_needs_day check (not recurring or day_of_month is not null)
);

create index if not exists expenses_date_idx on public.expenses (date desc);

-- ── 4. RLS: 자신이 만든 행만 읽고 쓴다 ────────────────────────
alter table public.cases    enable row level security;
alter table public.expenses enable row level security;

drop policy if exists cases_all on public.cases;
create policy cases_all on public.cases
  for all to authenticated using (created_by = auth.uid()) with check (created_by = auth.uid());

drop policy if exists expenses_all on public.expenses;
create policy expenses_all on public.expenses
  for all to authenticated using (created_by = auth.uid()) with check (created_by = auth.uid());

-- ── 5. 실시간: 내 다른 기기 화면에도 바로 반영 ────────────────
do $$
begin
  begin alter publication supabase_realtime add table public.cases; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.expenses; exception when duplicate_object then null; end;
end $$;

-- ═══════════════════════════════════════════════════════════════
--  7. 크로스 기기 알림 — 한 사람이 입력하면 같은 계정의 다른 기기에 푸시
--  아래 SQL 실행 전에 1회 준비할 것:
--    1) Supabase 대시보드 → Edge Functions 에 notify-entry 함수를 배포
--       (supabase/functions/notify-entry, README 의 "직접 해야 하는 일" 참고)
--    2) SQL Editor 에서 아래를 먼저 실행 (임의의 긴 무작위 문자열로 교체):
--         select vault.create_secret('여기에-무작위-긴-문자열', 'notify_webhook_secret');
--       Edge Function 배포 시 같은 값을 NOTIFY_WEBHOOK_SECRET 시크릿으로도 넣어야 함.
-- ═══════════════════════════════════════════════════════════════

create extension if not exists pg_net with schema extensions;

-- ── 기기별 FCM 토큰 ──────────────────────────────────────────
create table if not exists public.push_tokens (
  user_id    uuid not null references auth.users(id) on delete cascade,
  device_id  text not null,
  platform   text not null check (platform in ('web','android')),
  fcm_token  text not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, device_id)
);

alter table public.push_tokens enable row level security;

drop policy if exists push_tokens_own on public.push_tokens;
create policy push_tokens_own on public.push_tokens
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ── 새 전표/지출이 추가되면 Edge Function 호출 ────────────────
create or replace function public.notify_new_entry()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  secret text;
begin
  select decrypted_secret into secret
    from vault.decrypted_secrets where name = 'notify_webhook_secret';
  if secret is null then
    return NEW; -- 아직 시크릿을 안 만들었으면 조용히 건너뜀
  end if;
  perform net.http_post(
    url     := 'https://dotsiylmhwfoadvixnoi.supabase.co/functions/v1/notify-entry',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-webhook-secret', secret),
    body    := jsonb_build_object('table', TG_TABLE_NAME, 'record', to_jsonb(NEW))
  );
  return NEW;
end $$;

drop trigger if exists cases_notify on public.cases;
create trigger cases_notify after insert on public.cases
  for each row execute function public.notify_new_entry();

drop trigger if exists expenses_notify on public.expenses;
create trigger expenses_notify after insert on public.expenses
  for each row execute function public.notify_new_entry();

-- ═══════════════════════════════════════════════════════════════
--  8. 작업 종류 복수 선택 + 예약(달력에 다가올 작업 적어두기)
-- ═══════════════════════════════════════════════════════════════

-- ── 전표 하나에 작업 종류를 여러 개(선팅+전장 등) 담고, 종류별로 금액을 따로 받기 ──
create or replace function public.valid_work_items(items jsonb)
returns boolean language sql immutable as $$
  select items is not null
    and jsonb_typeof(items) = 'array'
    and jsonb_array_length(items) > 0
    and not exists (
      select 1 from jsonb_array_elements(items) e
      where (e->>'type') is null
         or (e->>'type') not in ('전장','선팅','덴트')
         or (e->>'price') is null
    )
$$;

-- items 컬럼이 없는 예전 테이블(work_type 만 있던 시절)에도 추가해 둔다 —
-- 이미 있으면(최신 설치) 조용히 건너뜀
alter table public.cases add column if not exists items jsonb not null default '[]'::jsonb;

-- 기존 DB에 남아 있던 work_type 컬럼을 items 로 옮기고 지운다 (처음 실행할 때만 동작,
-- 그 다음부터는 work_type 컬럼이 이미 없으므로 조용히 건너뜀 — 재실행 안전)
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'cases' and column_name = 'work_type') then
    update public.cases set items = jsonb_build_array(jsonb_build_object('type', work_type, 'price', price, 'cost', cost))
      where jsonb_array_length(items) = 0;
    alter table public.cases drop constraint if exists cases_work_type_check;
    alter table public.cases drop column work_type;
  end if;
end $$;

alter table public.cases drop constraint if exists items_valid;
alter table public.cases add constraint items_valid check (public.valid_work_items(items));

-- ── 예약: 달력에 다가올 작업을 미리 적어 둡니다 (금액 없음 — 실제 작업이 끝나면 전표로 새로 입력) ──
create table if not exists public.reservations (
  id         uuid primary key default gen_random_uuid(),
  date       date not null,
  company    text,
  dealer     text,
  phone      text,
  car_model  text,
  plate      text,
  types      text[] not null default '{}' check (types <@ array['전장','선팅','덴트']),
  note       text,
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid()
);
create index if not exists reservations_date_idx on public.reservations (date);

alter table public.reservations enable row level security;
drop policy if exists reservations_all on public.reservations;
create policy reservations_all on public.reservations
  for all to authenticated using (created_by = auth.uid()) with check (created_by = auth.uid());

do $$
begin
  begin alter publication supabase_realtime add table public.reservations; exception when duplicate_object then null; end;
end $$;
