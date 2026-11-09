-- Owner approval gate for every self-signup. Invitations keep their assigned roles.
create table if not exists public.workspace_access_requests (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null unique references auth.users(id) on delete cascade,
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 email text not null,
 full_name text not null default '',
 requested_role text not null default 'manager' check (requested_role in ('owner','admin','manager','creator','reviewer','client')),
 status text not null default 'pending' check (status in ('pending','approved','rejected')),
 requested_at timestamptz not null default now(),
 reviewed_at timestamptz,
 reviewed_by uuid references auth.users(id) on delete set null,
 review_note text
);
alter table public.workspace_access_requests add column if not exists requested_role text not null default 'manager' check (requested_role in ('owner','admin','manager','creator','reviewer','client'));
create index if not exists workspace_access_requests_workspace_status_idx
 on public.workspace_access_requests(workspace_id,status,requested_at desc);
alter table public.workspace_access_requests enable row level security;
drop policy if exists "Primary owner reads access requests" on public.workspace_access_requests;
create policy "Primary owner reads access requests" on public.workspace_access_requests
 for select to authenticated using (lower(coalesce(auth.jwt()->>'email',''))='itsshailesh0414@gmail.com');
revoke all on public.workspace_access_requests from anon, authenticated;
grant select on public.workspace_access_requests to authenticated;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer
set search_path=public,auth
as $$
declare
 target_workspace_id uuid;
 invitation_role text;
 workspace_label text;
begin
 if lower(coalesce(new.email,''))='itsshailesh0414@gmail.com' then
  select wm.workspace_id into target_workspace_id
  from public.workspace_members wm where wm.user_id=new.id and wm.role='owner' limit 1;
  if target_workspace_id is null then
   workspace_label:=coalesce(nullif(trim(new.raw_user_meta_data->>'workspace_name'),''),'Unboxed Thinking');
   insert into public.workspaces(name,created_by) values(workspace_label,new.id) returning id into target_workspace_id;
   insert into public.workspace_members(workspace_id,user_id,role) values(target_workspace_id,new.id,'owner')
    on conflict(workspace_id,user_id) do nothing;
  end if;
  return new;
 end if;

 if new.email is not null then
  select wi.workspace_id,wi.role into target_workspace_id,invitation_role
  from public.workspace_invitations wi
  where lower(wi.email)=lower(new.email) and wi.status='pending' and wi.expires_at>now()
  order by wi.created_at desc limit 1;
  if target_workspace_id is not null then
   insert into public.workspace_access_requests(user_id,workspace_id,email,full_name,requested_role,status)
   values(new.id,target_workspace_id,lower(new.email),coalesce(new.raw_user_meta_data->>'full_name',''),invitation_role,'pending')
   on conflict(user_id) do update set workspace_id=excluded.workspace_id,requested_role=excluded.requested_role,status='pending',requested_at=now(),reviewed_at=null,reviewed_by=null;
   insert into public.workspace_notifications(workspace_id,user_id,title,body,kind)
   select target_workspace_id,wm.user_id,'New signup approval request',
    coalesce(new.raw_user_meta_data->>'full_name',new.email)||' ('||new.email||') signed up from an invitation and is waiting for approval.',
    'signup_approval'
   from public.workspace_members wm join auth.users owner_user on owner_user.id=wm.user_id
   where wm.workspace_id=target_workspace_id and lower(owner_user.email)='itsshailesh0414@gmail.com'
   on conflict do nothing;
   return new;
  end if;
 end if;

 select wm.workspace_id into target_workspace_id
 from public.workspace_members wm join auth.users owner_user on owner_user.id=wm.user_id
 where lower(owner_user.email)='itsshailesh0414@gmail.com' and wm.role='owner'
 order by wm.created_at asc limit 1;
 if target_workspace_id is null then
  raise exception 'Primary company workspace is not configured. Contact the primary owner.';
 end if;

 insert into public.workspace_access_requests(user_id,workspace_id,email,full_name,requested_role,status)
 values(new.id,target_workspace_id,lower(new.email),coalesce(new.raw_user_meta_data->>'full_name',''),'manager','pending')
 on conflict(user_id) do update set status='pending',requested_at=now(),reviewed_at=null,reviewed_by=null;

 insert into public.workspace_notifications(workspace_id,user_id,title,body,kind)
 select target_workspace_id,wm.user_id,'New signup approval request',
  coalesce(new.raw_user_meta_data->>'full_name',new.email)||' ('||new.email||') is waiting for workspace access approval.',
  'signup_approval'
 from public.workspace_members wm join auth.users owner_user on owner_user.id=wm.user_id
 where wm.workspace_id=target_workspace_id and lower(owner_user.email)='itsshailesh0414@gmail.com'
 on conflict do nothing;

 return new;
end;
$$;

-- Allow Supabase service-role auth deletion to cascade memberships. Primary owner remains protected.
create or replace function public.guard_primary_workspace_owner()
returns trigger language plpgsql security definer
set search_path=public,auth
as $$
declare
 actor_is_primary boolean:=false;
 target_is_primary boolean:=false;
 target_email text;
 primary_invitation boolean:=false;
begin
 select lower(coalesce(email,''))='itsshailesh0414@gmail.com' into actor_is_primary
 from auth.users where id=auth.uid();

 if tg_op='DELETE' then
  select lower(coalesce(email,''))='itsshailesh0414@gmail.com' into target_is_primary
  from auth.users where id=old.user_id;
  if coalesce(target_is_primary,false) then
   raise exception 'The primary owner account cannot be removed.';
  end if;
  if auth.uid() is not null and coalesce(actor_is_primary,false) is not true then
   raise exception 'Only the primary owner can remove workspace members.';
  end if;
  return old;
 end if;

 if tg_op='UPDATE' then
  select lower(coalesce(email,''))='itsshailesh0414@gmail.com' into target_is_primary
  from auth.users where id=old.user_id;
  if coalesce(target_is_primary,false) and (new.role is distinct from old.role or new.user_id is distinct from old.user_id or new.workspace_id is distinct from old.workspace_id) then
   raise exception 'The primary owner cannot be changed or demoted.';
  end if;
  if coalesce(actor_is_primary,false) is not true and auth.role() is distinct from 'service_role'
   and (new.role is distinct from old.role or new.user_id is distinct from old.user_id or new.workspace_id is distinct from old.workspace_id) then
   raise exception 'Only the primary owner can change member roles.';
  end if;
  return new;
 end if;

 if auth.uid() is not null and coalesce(actor_is_primary,false) is not true then
  raise exception 'Only the primary owner can add existing workspace members.';
 end if;
 if new.role='owner' and coalesce(actor_is_primary,false) is not true then
  select lower(coalesce(u.email,'')) into target_email from auth.users u where u.id=new.user_id;
  select exists(
   select 1 from public.workspace_invitations wi join auth.users inviter on inviter.id=wi.invited_by
   where wi.workspace_id=new.workspace_id and lower(wi.email)=lower(coalesce(target_email,''))
    and wi.role='owner' and wi.status='pending' and wi.expires_at>now()
    and lower(inviter.email)='itsshailesh0414@gmail.com'
  ) into primary_invitation;
  if coalesce(primary_invitation,false) is not true and target_email is distinct from 'itsshailesh0414@gmail.com' then
   raise exception 'Only the primary owner can appoint another Owner.';
  end if;
 end if;
 return new;
end;
$$;

grant select on public.workspace_access_requests to authenticated;
grant all on public.workspace_access_requests to service_role;
revoke all on public.workspace_access_requests from anon;
