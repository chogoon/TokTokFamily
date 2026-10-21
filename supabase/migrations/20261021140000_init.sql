-- Family TokTok 초기 스키마 + RLS
--
-- 기획서 7장 데이터 구조를 기반으로 하되, 두 가지를 보완했다:
-- 1. moods를 공개 이모지(moods)와 비공개 이유(mood_notes)로 분리했다.
--    "이모지는 가족 전체, 이유(note)는 본인+보호자만"이라는 규칙은 PostgreSQL
--    컬럼 단위 RLS로 표현할 수 없어 두 테이블로 나눠 행 단위 RLS로 해결한다.
-- 2. qr_login_tokens 테이블을 추가했다 (ADR-003 QR 로그인, backend 전용 — RLS로
--    authenticated/anon 접근을 기본 차단하고 service-role만 사용한다).

create extension if not exists pgcrypto;

-- ============================================================
-- 테이블
-- ============================================================

create table public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table public.members (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  role text not null check (role in ('parent', 'kid')),
  name text not null,
  avatar text,
  color text,
  auth_user_id uuid unique references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index members_family_id_idx on public.members(family_id);

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id) on delete cascade,
  push_token text not null,
  platform text not null check (platform in ('ios', 'android')),
  created_at timestamptz not null default now()
);

create index devices_member_id_idx on public.devices(member_id);

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  type text not null check (type in ('family', 'kid')),
  kid_member_id uuid references public.members(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint kid_room_requires_member check (type <> 'kid' or kid_member_id is not null)
);

create index rooms_family_id_idx on public.rooms(family_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  sender_id uuid not null references public.members(id) on delete cascade,
  kind text not null check (kind in ('text', 'sticker', 'system')),
  body text,
  is_urgent boolean not null default false,
  created_at timestamptz not null default now()
);

create index messages_room_id_idx on public.messages(room_id, created_at);

create table public.reactions (
  message_id uuid not null references public.messages(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  primary key (message_id, member_id, emoji)
);

create table public.reads (
  room_id uuid not null references public.rooms(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (room_id, member_id)
);

create table public.moods (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  date date not null,
  emoji text not null,
  created_at timestamptz not null default now(),
  unique (member_id, date)
);

create index moods_family_id_idx on public.moods(family_id);

create table public.mood_notes (
  mood_id uuid primary key references public.moods(id) on delete cascade,
  note text not null,
  created_at timestamptz not null default now()
);

create table public.praise_boards (
  id uuid primary key default gen_random_uuid(),
  kid_member_id uuid not null references public.members(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  goal_text text not null,
  target_count int not null default 10,
  status text not null default 'active' check (status in ('active', 'done')),
  created_at timestamptz not null default now()
);

create index praise_boards_family_id_idx on public.praise_boards(family_id);

create table public.praises (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.praise_boards(id) on delete cascade,
  giver_id uuid not null references public.members(id) on delete cascade,
  text text,
  created_at timestamptz not null default now()
);

create index praises_board_id_idx on public.praises(board_id);

create table public.daily_questions (
  id uuid primary key default gen_random_uuid(),
  text text not null,
  date date not null unique,
  created_at timestamptz not null default now()
);

create table public.qr_login_tokens (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  kid_member_id uuid not null references public.members(id) on delete cascade,
  issued_by uuid not null references public.members(id) on delete cascade,
  token text not null unique,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

-- ============================================================
-- 헬퍼 함수 (security definer — members 테이블 RLS 재귀 참조를 피한다)
-- ============================================================

create or replace function public.current_member_id()
returns uuid
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select id from public.members where auth_user_id = auth.uid()
$$;

create or replace function public.current_family_id()
returns uuid
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select family_id from public.members where auth_user_id = auth.uid()
$$;

create or replace function public.is_parent()
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.members
    where auth_user_id = auth.uid() and role = 'parent'
  )
$$;

create or replace function public.can_access_room(r_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.rooms r
    where r.id = r_id
      and r.family_id = public.current_family_id()
      and (
        r.type = 'family'
        or r.kid_member_id = public.current_member_id()
        or public.is_parent()
      )
  )
$$;

create or replace function public.can_access_message(m_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.messages msg
    where msg.id = m_id and public.can_access_room(msg.room_id)
  )
$$;

create or replace function public.can_access_board(b_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.praise_boards b
    where b.id = b_id
      and b.family_id = public.current_family_id()
      and (b.kid_member_id = public.current_member_id() or public.is_parent())
  )
$$;

-- ============================================================
-- RLS 활성화 + 정책
-- ============================================================

alter table public.families enable row level security;
alter table public.members enable row level security;
alter table public.devices enable row level security;
alter table public.rooms enable row level security;
alter table public.messages enable row level security;
alter table public.reactions enable row level security;
alter table public.reads enable row level security;
alter table public.moods enable row level security;
alter table public.mood_notes enable row level security;
alter table public.praise_boards enable row level security;
alter table public.praises enable row level security;
alter table public.daily_questions enable row level security;
alter table public.qr_login_tokens enable row level security;

-- families: 같은 가족만 조회, 보호자만 수정 (생성은 backend service-role 전용)
create policy families_select on public.families
  for select using (id = public.current_family_id());

create policy families_update on public.families
  for update using (public.is_parent() and id = public.current_family_id());

-- members: 같은 가족만 조회, 보호자만 추가/수정/삭제 (최초 부트스트랩은 backend 전용)
create policy members_select on public.members
  for select using (family_id = public.current_family_id());

create policy members_insert on public.members
  for insert with check (public.is_parent() and family_id = public.current_family_id());

create policy members_update on public.members
  for update using (public.is_parent() and family_id = public.current_family_id());

create policy members_delete on public.members
  for delete using (public.is_parent() and family_id = public.current_family_id());

-- devices: 본인 기기만 관리 (push 발송은 backend service-role이 처리)
create policy devices_select on public.devices
  for select using (member_id = public.current_member_id());

create policy devices_insert on public.devices
  for insert with check (member_id = public.current_member_id());

create policy devices_update on public.devices
  for update using (member_id = public.current_member_id());

create policy devices_delete on public.devices
  for delete using (member_id = public.current_member_id());

-- rooms: 가족방은 전체, 1:1 방은 해당 아이+보호자만 (생성은 backend 전용)
create policy rooms_select on public.rooms
  for select using (
    family_id = public.current_family_id()
    and (type = 'family' or kid_member_id = public.current_member_id() or public.is_parent())
  );

-- messages: 접근 가능한 방의 메시지만 조회, 본인 명의로만 작성
create policy messages_select on public.messages
  for select using (public.can_access_room(room_id));

create policy messages_insert on public.messages
  for insert with check (public.can_access_room(room_id) and sender_id = public.current_member_id());

-- reactions: 접근 가능한 메시지에 본인 명의로만 반응
create policy reactions_select on public.reactions
  for select using (public.can_access_message(message_id));

create policy reactions_insert on public.reactions
  for insert with check (public.can_access_message(message_id) and member_id = public.current_member_id());

create policy reactions_delete on public.reactions
  for delete using (member_id = public.current_member_id());

-- reads: 접근 가능한 방에서 본인 읽음 상태만 기록
create policy reads_select on public.reads
  for select using (public.can_access_room(room_id));

create policy reads_insert on public.reads
  for insert with check (public.can_access_room(room_id) and member_id = public.current_member_id());

create policy reads_update on public.reads
  for update using (member_id = public.current_member_id());

-- moods (이모지): 같은 가족 전체가 조회 가능, 본인만 작성/수정
create policy moods_select on public.moods
  for select using (family_id = public.current_family_id());

create policy moods_insert on public.moods
  for insert with check (member_id = public.current_member_id() and family_id = public.current_family_id());

create policy moods_update on public.moods
  for update using (member_id = public.current_member_id());

-- mood_notes (기분 이유): 본인과 보호자만 조회, 본인만 작성/수정
create policy mood_notes_select on public.mood_notes
  for select using (
    exists (
      select 1 from public.moods m
      where m.id = mood_id
        and m.family_id = public.current_family_id()
        and (m.member_id = public.current_member_id() or public.is_parent())
    )
  );

create policy mood_notes_insert on public.mood_notes
  for insert with check (
    exists (
      select 1 from public.moods m
      where m.id = mood_id and m.member_id = public.current_member_id()
    )
  );

create policy mood_notes_update on public.mood_notes
  for update using (
    exists (
      select 1 from public.moods m
      where m.id = mood_id and m.member_id = public.current_member_id()
    )
  );

-- praise_boards: 아이는 본인 것만, 보호자는 전체 조회. 수정은 보호자만 (아이는 보기만)
create policy praise_boards_select on public.praise_boards
  for select using (
    family_id = public.current_family_id()
    and (kid_member_id = public.current_member_id() or public.is_parent())
  );

create policy praise_boards_insert on public.praise_boards
  for insert with check (public.is_parent() and family_id = public.current_family_id());

create policy praise_boards_update on public.praise_boards
  for update using (public.is_parent() and family_id = public.current_family_id());

-- praises: 칭찬판에 접근 가능한 사람만 조회, 작성(쓰기)은 보호자만
create policy praises_select on public.praises
  for select using (public.can_access_board(board_id));

create policy praises_insert on public.praises
  for insert with check (
    public.is_parent() and public.can_access_board(board_id) and giver_id = public.current_member_id()
  );

-- daily_questions: 가족 구분 없는 전역 데이터, 인증된 사용자 전체 조회 (작성은 service-role 전용)
create policy daily_questions_select on public.daily_questions
  for select using (auth.uid() is not null);

-- qr_login_tokens: authenticated/anon 정책 없음 (기본 차단) — backend service-role만 사용
