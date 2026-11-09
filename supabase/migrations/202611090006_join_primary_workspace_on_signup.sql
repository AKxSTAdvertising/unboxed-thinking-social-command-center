-- Route every uninvited signup into the primary owner's existing workspace.
-- Accepted invitations continue to use their explicitly assigned workspace and role.

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
  -- Create the company workspace only for the designated primary owner.
  if lower(coalesce(new.email, '')) = 'itsshailesh0414@gmail.com' then
    workspace_label := coalesce(nullif(trim(new.raw_user_meta_data->>'workspace_name'), ''), 'My Workspace');
    insert into public.workspaces(name, created_by)
    values (workspace_label, new.id)
    returning id into target_workspace_id;

    insert into public.workspace_members(workspace_id, user_id, role)
    values (target_workspace_id, new.id, 'owner');
    return new;
  end if;

  -- Invitations take priority and preserve the invited role.
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

  -- Any signup without an invitation joins the primary owner's company workspace.
  select wm.workspace_id
    into target_workspace_id
  from public.workspace_members wm
  join auth.users primary_user on primary_user.id = wm.user_id
  where lower(primary_user.email) = 'itsshailesh0414@gmail.com'
    and wm.role = 'owner'
  order by wm.created_at asc
  limit 1;

  if target_workspace_id is null then
    raise exception 'Primary company workspace is not configured. Contact the primary owner.';
  end if;

  insert into public.workspace_members(workspace_id, user_id, role)
  values (target_workspace_id, new.id, 'manager')
  on conflict (workspace_id, user_id) do nothing;

  return new;
end;
$$;
