-- ============================================================
-- 모여라 · Supabase 설정 SQL
-- Supabase 대시보드 → SQL Editor 에 붙여넣고 "Run" 하세요.
-- ============================================================

-- 1) 일정 테이블
create table if not exists public.events (
  id         uuid primary key default gen_random_uuid(),
  owner      uuid not null references auth.users(id) on delete cascade,
  title      text not null default '',
  config     jsonb not null default '{}',
  created_at timestamptz not null default now()
);

-- 2) 참여자 테이블 (한 사람당 일정별 1행)
create table if not exists public.participants (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references public.events(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  name       text not null default '',
  dept_id    text,
  avail      jsonb not null default '{}',
  updated_at timestamptz not null default now(),
  unique (event_id, user_id)
);

create index if not exists participants_event_idx on public.participants(event_id);

-- 3) RLS (행 수준 보안) 켜기
alter table public.events       enable row level security;
alter table public.participants enable row level security;

-- 4) 정책: 로그인한 사용자는 일정을 조회할 수 있고(링크의 uuid가 곧 접근 권한),
--    생성/수정/삭제는 주최자 본인만.
drop policy if exists events_select on public.events;
drop policy if exists events_insert on public.events;
drop policy if exists events_update on public.events;
drop policy if exists events_delete on public.events;

create policy events_select on public.events
  for select using (auth.uid() is not null);
create policy events_insert on public.events
  for insert with check (owner = auth.uid());
create policy events_update on public.events
  for update using (owner = auth.uid());
create policy events_delete on public.events
  for delete using (owner = auth.uid());

-- 5) 정책: 참여자 행은 로그인 사용자 모두 조회 가능(서로의 가능 시간을 봐야 하므로),
--    추가/수정/삭제는 자기 행만.
drop policy if exists participants_select on public.participants;
drop policy if exists participants_insert on public.participants;
drop policy if exists participants_update on public.participants;
drop policy if exists participants_delete on public.participants;

create policy participants_select on public.participants
  for select using (auth.uid() is not null);
create policy participants_insert on public.participants
  for insert with check (user_id = auth.uid());
create policy participants_update on public.participants
  for update using (user_id = auth.uid());
create policy participants_delete on public.participants
  for delete using (user_id = auth.uid());

-- 6) 실시간(Realtime) 발행 등록
alter publication supabase_realtime add table public.events;
alter publication supabase_realtime add table public.participants;

-- 완료! 이제 앱에 Project URL 과 anon key 를 넣으면 동작합니다.
