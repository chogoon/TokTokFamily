-- 초대 코드 테이블 + backend가 호출하는 원자적 부트스트랩 함수
--
-- 가족 생성과 초대 redeem은 "멤버십 행이 아직 없는 상태에서 자기 자신을 만드는"
-- 부트스트랩 문제라 RLS insert 정책으로 안전하게 표현할 수 없다. backend가
-- service-role로 아래 함수를 RPC 호출해 family+member 생성을 한 트랜잭션으로 묶는다.
-- 함수는 SECURITY INVOKER(기본값)로 두어도 된다 — 호출자가 이미 service_role이라
-- RLS를 우회하기 때문이다.

create table public.invites (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  code text not null unique,
  created_by uuid not null references public.members(id) on delete cascade,
  expires_at timestamptz not null,
  used_at timestamptz,
  used_by uuid references public.members(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.invites enable row level security;
-- authenticated/anon 정책 없음 (기본 차단) — backend service-role만 발급/redeem 처리

create or replace function public.create_family_with_parent(
  p_auth_user_id uuid,
  p_family_name text,
  p_parent_name text
)
returns table (family_id uuid, member_id uuid)
language plpgsql
as $$
declare
  v_family_id uuid;
  v_member_id uuid;
begin
  if exists (select 1 from public.members where auth_user_id = p_auth_user_id) then
    raise exception 'ALREADY_MEMBER' using errcode = 'P0001';
  end if;

  insert into public.families (name) values (p_family_name)
    returning id into v_family_id;

  insert into public.members (family_id, role, name, auth_user_id)
    values (v_family_id, 'parent', p_parent_name, p_auth_user_id)
    returning id into v_member_id;

  return query select v_family_id, v_member_id;
end;
$$;

create or replace function public.redeem_invite(
  p_code text,
  p_auth_user_id uuid,
  p_name text
)
returns table (family_id uuid, member_id uuid)
language plpgsql
as $$
declare
  v_invite public.invites;
  v_member_id uuid;
begin
  select * into v_invite from public.invites where code = p_code for update;

  if v_invite.id is null then
    raise exception 'INVITE_NOT_FOUND' using errcode = 'P0001';
  end if;

  if v_invite.used_at is not null then
    raise exception 'INVITE_ALREADY_USED' using errcode = 'P0001';
  end if;

  if v_invite.expires_at < now() then
    raise exception 'INVITE_EXPIRED' using errcode = 'P0001';
  end if;

  if exists (select 1 from public.members where auth_user_id = p_auth_user_id) then
    raise exception 'ALREADY_MEMBER' using errcode = 'P0001';
  end if;

  insert into public.members (family_id, role, name, auth_user_id)
    values (v_invite.family_id, 'parent', p_name, p_auth_user_id)
    returning id into v_member_id;

  update public.invites set used_at = now(), used_by = v_member_id where id = v_invite.id;

  return query select v_invite.family_id, v_member_id;
end;
$$;
