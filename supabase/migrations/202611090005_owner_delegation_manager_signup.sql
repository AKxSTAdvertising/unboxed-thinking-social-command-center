-- Role hierarchy update:
-- Primary owner is permanently protected; the primary owner may appoint/remove
-- additional owners. New uninvited signups start as Manager.
-- Only the primary owner can create or promote another Owner.

drop index if exists public.workspace_members_one_owner_per_workspace;

create or replace function public.guard_primary_workspace_owner()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  member_email text;
  primary_actor boolean := false;
  primary_invitation boolean := false;
  target_is_primary boolean := false;
begin
  if tg_op = 'DELETE' then
    select lower(email) = 'itsshailesh0414@gmail.com'
      into primary_actor from auth.users where id = auth.uid();
    select lower(email) = 'itsshailesh0414@gmail.com'
      into target_is_primary from auth.users where id = old.user_id;

    if coalesce(target_is_primary, false) then
      raise exception 'The primary owner account cannot be removed.';
    end if;
    if old.role = 'owner' and coalesce(primary_actor, false) is not true then
      raise exception 'Only the primary owner can remove another Owner.';
    end if;
    return old;
  end if;

  select lower(email) = 'itsshailesh0414@gmail.com'
    into primary_actor from auth.users where id = auth.uid();

  select lower(email) into member_email
    from auth.users where id = new.user_id;

  if new.role = 'owner' then
    if coalesce(primary_actor, false) is not true then
      select exists (
        select 1
        from public.workspace_invitations wi
        join auth.users inviter on inviter.id = wi.invited_by
        where wi.workspace_id = new.workspace_id
          and lower(wi.email) = lower(member_email)
          and wi.role = 'owner'
          and wi.status = 'pending'
          and wi.expires_at > now()
          and lower(inviter.email) = 'itsshailesh0414@gmail.com'
      ) into primary_invitation;

      if coalesce(primary_invitation, false) is not true
         and member_email is distinct from 'itsshailesh0414@gmail.com' then
        raise exception 'Only the primary owner can appoint another Owner.';
      end if;
    end if;
  end if;

  if tg_op = 'UPDATE' and old.role = 'owner' then
    select lower(email) = 'itsshailesh0414@gmail.com'
      into target_is_primary from auth.users where id = old.user_id;
    if coalesce(target_is_primary, false) then
      if new.role <> 'owner' or new.user_id <> old.user_id
         or new.workspace_id <> old.workspace_id then
        raise exception 'The primary owner cannot be changed or demoted.';
      end if;
    elsif coalesce(primary_actor, false) is not true then
      raise exception 'Only the primary owner can change another Owner.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists protect_primary_workspace_owner on public.workspace_members;
create trigger protect_primary_workspace_owner
before insert or update or delete on public.workspace_members
for each row execute function public.guard_primary_workspace_owner();

-- Signup behavior: accepted invitations keep their assigned role;
-- uninvited signups get Manager; the protected primary account gets Owner.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  target_workspace_id uuid;
  workspace_label text;
  invitation_role text;
begin
  if lower(coalesce(new.email, '')) = 'itsshailesh0414@gmail.com' then
    workspace_label := coalesce(nullif(trim(new.raw_user_meta_data->>'workspace_name'), ''), 'My Workspace');
    insert into public.workspaces(name, created_by)
    values (workspace_label, new.id)
    returning id into target_workspace_id;

    insert into public.workspace_members(workspace_id, user_id, role)
    values (target_workspace_id, new.id, 'owner');
    return new;
  end if;

  if new.email is not null then
    select wi.workspace_id, wi.role
      into target_workspace_id, invitation_role
    from public.workspace_invitations wi
    where lower(wi.email) = lower(new.email)
      and wi.status = 'pending'
      and wi.expires_at > now()
    order by wi.created_at desc
    limit 1;

    if target_workspace_id is not null then
      insert into public.workspace_members(workspace_id, user_id, role)
      values (target_workspace_id, new.id, invitation_role)
      on conflict (workspace_id, user_id) do nothing;

      update public.workspace_invitations
      set status = 'accepted', accepted_at = now()
      where workspace_id = target_workspace_id
        and lower(email) = lower(new.email)
        and status = 'pending'
        and expires_at > now();
      return new;
    end if;
  end if;

  workspace_label := coalesce(nullif(trim(new.raw_user_meta_data->>'workspace_name'), ''), 'My Workspace');
  insert into public.workspaces(name, created_by)
  values (workspace_label, new.id)
  returning id into target_workspace_id;

  insert into public.workspace_members(workspace_id, user_id, role)
  values (target_workspace_id, new.id, 'manager');

  return new;
end;
$$;

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.workspace_members to authenticated;
revoke all on public.workspace_members from anon;
