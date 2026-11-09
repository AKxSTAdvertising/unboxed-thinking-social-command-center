-- Enforce primary-owner-only membership administration and attach the existing
-- Is(h)ika account to the primary company workspace as Manager.
-- Run after 202611090006_join_primary_workspace_on_signup.sql.

create or replace function public.guard_primary_workspace_owner()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  actor_is_primary boolean := false;
  target_is_primary boolean := false;
  target_email text;
  primary_invitation boolean := false;
begin
  select lower(coalesce(email, '')) = 'itsshailesh0414@gmail.com'
    into actor_is_primary
  from auth.users
  where id = auth.uid();

  if tg_op = 'DELETE' then
    if coalesce(actor_is_primary, false) is not true then
      raise exception 'Only the primary owner can remove workspace members.';
    end if;

    select lower(coalesce(email, '')) = 'itsshailesh0414@gmail.com'
      into target_is_primary
    from auth.users where id = old.user_id;

    if coalesce(target_is_primary, false) then
      raise exception 'The primary owner account cannot be removed.';
    end if;
    return old;
  end if;

  if tg_op = 'UPDATE' then
    select lower(coalesce(email, '')) = 'itsshailesh0414@gmail.com'
      into target_is_primary
    from auth.users where id = old.user_id;

    if coalesce(target_is_primary, false) and (
      new.role is distinct from old.role
      or new.user_id is distinct from old.user_id
      or new.workspace_id is distinct from old.workspace_id
    ) then
      raise exception 'The primary owner cannot be changed or demoted.';
    end if;

    if coalesce(actor_is_primary, false) is not true and (
      new.role is distinct from old.role
      or new.user_id is distinct from old.user_id
      or new.workspace_id is distinct from old.workspace_id
    ) then
      raise exception 'Only the primary owner can change member roles.';
    end if;
    return new;
  end if;

  -- Signup trigger runs as SECURITY DEFINER with no authenticated actor.
  -- Authenticated users may directly add an existing account only if they
  -- are the primary owner. Invitation signup is handled by handle_new_user().
  if auth.uid() is not null and coalesce(actor_is_primary, false) is not true then
    raise exception 'Only the primary owner can add existing workspace members.';
  end if;

  if new.role = 'owner' and coalesce(actor_is_primary, false) is not true then
    select lower(coalesce(u.email, ''))
      into target_email
    from auth.users u
    where u.id = new.user_id;

    select exists (
      select 1
      from public.workspace_invitations wi
      join auth.users inviter on inviter.id = wi.invited_by
      where wi.workspace_id = new.workspace_id
        and lower(wi.email) = lower(coalesce(target_email, ''))
        and wi.role = 'owner'
        and wi.status = 'pending'
        and wi.expires_at > now()
        and lower(inviter.email) = 'itsshailesh0414@gmail.com'
    ) into primary_invitation;

    if coalesce(primary_invitation, false) is not true
       and target_email is distinct from 'itsshailesh0414@gmail.com' then
      raise exception 'Only the primary owner can appoint another Owner.';
    end if;
  end if;

  return new;
end;
$$;

-- Move the already-registered account into the company team. Existing
-- memberships in any previous workspace are left untouched; Team & Access
-- prioritizes the primary owner's workspace.
do $$
declare
  company_workspace_id uuid;
  existing_user_id uuid;
begin
  select wm.workspace_id
    into company_workspace_id
  from public.workspace_members wm
  join auth.users owner_user on owner_user.id = wm.user_id
  where lower(owner_user.email) = 'itsshailesh0414@gmail.com'
    and wm.role = 'owner'
  order by wm.created_at asc
  limit 1;

  select id into existing_user_id
  from auth.users
  where lower(email) = 'tiwariishika773@gmail.com'
  limit 1;

  if company_workspace_id is not null and existing_user_id is not null then
    insert into public.workspace_members(workspace_id, user_id, role)
    values (company_workspace_id, existing_user_id, 'manager')
    on conflict (workspace_id, user_id) do nothing;
  end if;
end;
$$;

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.workspace_members to authenticated;
revoke all on public.workspace_members from anon;
