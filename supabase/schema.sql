-- ═══════════════════════════════════════════════════════════════
--  전표철 — Supabase 스키마
--  Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 Run 하세요.
--  두 사람만 쓰는 공용 장부라, members 에 등록된 사람만 읽고 씁니다.
-- ═══════════════════════════════════════════════════════════════

-- ── 1. 이 장부를 쓸 사람 ──────────────────────────────────────
create table if not exists public.members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email   text,
  name    text,
  added_at timestamptz not null default now()
);

-- 로그인한 사람이 멤버인지 확인하는 함수 (RLS 안에서 재귀 없이 쓰려고 security definer)
create or replace function public.is_member()
returns boolean
language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.members m where m.user_id = auth.uid()) $$;

-- 처음 로그인하는 사람을 자동으로 멤버에 넣습니다.
-- 두 사람만 쓸 것이므로, 2명이 등록된 뒤에는 더 이상 들어오지 못합니다.
create or replace function public.auto_enroll()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if (select count(*) from public.members) < 2 then
    insert into public.members (user_id, email) values (new.id, new.email)
    on conflict (user_id) do nothing;
  end if;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.auto_enroll();

-- ── 2. 매출 전표 ─────────────────────────────────────────────
create table if not exists public.cases (
  id          uuid primary key default gen_random_uuid(),
  date        date not null,
  company     text not null,                       -- 상사명
  dealer      text,                                -- 딜러명
  phone       text,                                -- 연락처
  car_model   text,                                -- 차종
  plate       text,                                -- 차량번호
  work_type   text not null check (work_type in ('전장','선팅','덴트')),
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

-- ── 4. RLS: 멤버만 전부 읽고 쓴다 ────────────────────────────
alter table public.members  enable row level security;
alter table public.cases    enable row level security;
alter table public.expenses enable row level security;

drop policy if exists members_read on public.members;
create policy members_read on public.members
  for select to authenticated using (user_id = auth.uid() or public.is_member());

drop policy if exists cases_all on public.cases;
create policy cases_all on public.cases
  for all to authenticated using (public.is_member()) with check (public.is_member());

drop policy if exists expenses_all on public.expenses;
create policy expenses_all on public.expenses
  for all to authenticated using (public.is_member()) with check (public.is_member());

-- ── 5. 실시간: 상대가 입력하면 내 화면에 바로 뜨게 ───────────
do $$
begin
  begin alter publication supabase_realtime add table public.cases; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.expenses; exception when duplicate_object then null; end;
end $$;

-- ── 6. 이미 만들어 둔 계정이 있다면 손으로 멤버에 넣어 주세요 ─
--    (트리거는 "앞으로 새로 생기는" 계정에만 걸립니다)
-- insert into public.members (user_id, email)
-- select id, email from auth.users
-- on conflict (user_id) do nothing;
