-- Primary owner security model:
-- itsshailesh0414@gmail.com is the only account allowed to hold the owner role.
-- Admins may manage invitations and non-admin roles, but only the owner may
-- change membership rows or remove members. RLS stays enabled.

-- Normalize any legacy owner rows that do not belong to the primary owner account.
update public.workspace_members wm
set role = 'admin'
from auth.users u
where u.id = wm.user_id
  and wm.role = 'owner'
  and lower(coalesce(u.email, '')) <> 'itsshailesh0414@gmail.com';

create unique index if not exists workspace_members_one_owner_per_workspace
  on public.workspace_members(workspace_id)
  where role = 'owner';

create or replace function public.guard_primary_workspace_owner()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  member_email text;
begin
  if tg_op = 'DELETE' then
    if old.role = 'owner' then
      raise exception 'The primary workspace owner cannot be removed.';
    end if;
    return old;
  end if;

  select lower(email) into member_email
  from auth.users
  where id = new.user_id;

  if new.role = 'owner' and member_email is distinct from 'itsshailesh0414@gmail.com' then
    raise exception 'Only itsshailesh0414@gmail.com can be the workspace owner.';
  end if;

  if tg_op = 'UPDATE' and old.role = 'owner'
     and (new.role <> 'owner' or new.user_id <> old.user_id or new.workspace_id <> old.workspace_id) then
    raise exception 'The primary workspace owner cannot be changed or demoted.';
  end if;

  return new;
end;
$$;

drop trigger if exists protect_primary_workspace_owner on public.workspace_members;
create trigger protect_primary_workspace_owner
before insert or update or delete on public.workspace_members
for each row execute function public.guard_primary_workspace_owner();

-- Remove broad owner/admin membership management. Only the owner can mutate membership.
drop policy if exists "Owners and admins can manage membership" on public.workspace_members;
drop policy if exists "Owner manages workspace membership" on public.workspace_members;
create policy "Owner manages workspace membership"
on public.workspace_members
for all
to authenticated
using (public.has_workspace_role(workspace_id, array['owner']))
with check (public.has_workspace_role(workspace_id, array['owner']));

-- Keep member read access unchanged.
drop policy if exists "Members can read workspace membership" on public.workspace_members;
create policy "Members can read workspace membership"
on public.workspace_members
for select
to authenticated
using (public.is_workspace_member(workspace_id));

-- Update signup handling: invitations join the inviter's workspace.
-- Uninvited accounts other than the primary owner get Admin, never Owner.
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
  values (target_workspace_id, new.id, 'admin');

  return new;
end;
$$;

-- Explicit grants are required in addition to RLS policies.
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.workspace_members to authenticated;
revoke all on public.workspace_members from anon;
