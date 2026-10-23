-- 아이 추가 부트스트랩 함수
--
-- 아이를 추가하면 가족방(이미 존재, 최초 1개)에 더해 그 아이 전용 1:1 방과
-- 빈 칭찬판이 함께 생겨야 한다 (family-sns.html 프로토타입의 "아이 추가하기" 설명과
-- 동일한 원칙). rooms insert 정책이 없으므로(backend 전용), 아이 멤버 생성과
-- 1:1 방·칭찬판 생성을 backend가 service-role로 한 트랜잭션에서 처리한다.
--
-- 가족방은 가족 생성 시점에는 아직 없었다 — 이 마이그레이션에서 최초 가족방이
-- 없는 기존 가족을 위해 보정하고, 이후 add_kid_member가 멱등하게 보장한다.

create or replace function public.ensure_family_room(p_family_id uuid)
returns uuid
language plpgsql
as $$
declare
  v_room_id uuid;
begin
  select id into v_room_id from public.rooms
    where family_id = p_family_id and type = 'family';

  if v_room_id is null then
    insert into public.rooms (family_id, type) values (p_family_id, 'family')
      returning id into v_room_id;
  end if;

  return v_room_id;
end;
$$;

-- 가족 생성 시점에도 가족방이 바로 생기도록 보강한다 (원본은 families+members만 생성).
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

  perform public.ensure_family_room(v_family_id);

  return query select v_family_id, v_member_id;
end;
$$;

-- redeem_invite는 이미 존재하는 가족에 합류하는 경로이므로 가족방이 이미 있어야
-- 하지만, 방어적으로 ensure_family_room을 호출해 누락을 보정한다.
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

  perform public.ensure_family_room(v_invite.family_id);

  update public.invites set used_at = now(), used_by = v_member_id where id = v_invite.id;

  return query select v_invite.family_id, v_member_id;
end;
$$;

create or replace function public.add_kid_member(
  p_family_id uuid,
  p_requester_auth_user_id uuid,
  p_name text,
  p_avatar text,
  p_color text
)
returns table (member_id uuid, kid_room_id uuid)
language plpgsql
as $$
declare
  v_requester public.members;
  v_member_id uuid;
  v_kid_room_id uuid;
begin
  select * into v_requester from public.members
    where auth_user_id = p_requester_auth_user_id and family_id = p_family_id;

  if v_requester.id is null then
    raise exception 'NOT_A_FAMILY_MEMBER' using errcode = 'P0001';
  end if;

  if v_requester.role <> 'parent' then
    raise exception 'ONLY_PARENT_CAN_ADD_KID' using errcode = 'P0001';
  end if;

  perform public.ensure_family_room(p_family_id);

  insert into public.members (family_id, role, name, avatar, color)
    values (p_family_id, 'kid', p_name, p_avatar, p_color)
    returning id into v_member_id;

  insert into public.rooms (family_id, type, kid_member_id)
    values (p_family_id, 'kid', v_member_id)
    returning id into v_kid_room_id;

  insert into public.praise_boards (kid_member_id, family_id, goal_text)
    values (v_member_id, p_family_id, '목표를 정해주세요');

  return query select v_member_id, v_kid_room_id;
end;
$$;
