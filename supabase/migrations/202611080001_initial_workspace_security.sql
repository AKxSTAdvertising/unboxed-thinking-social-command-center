-- UNBOXED THINKING Social Command Center
-- Tenant isolation baseline. Apply through Supabase SQL Editor or Supabase CLI.

create extension if not exists pgcrypto;

create table if not exists public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table if not exists public.workspace_members (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'owner' check (role in ('owner','admin','manager','creator','reviewer','client')),
  created_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);

create table if not exists public.social_accounts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  platform text not null check (platform in ('instagram','facebook','linkedin')),
  platform_account_id text not null,
  account_name text not null,
  status text not null default 'connected' check (status in ('connected','expired','revoked','error')),
  token_ciphertext text,
  token_expires_at timestamptz,
  connected_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (workspace_id, platform, platform_account_id)
);

create table if not exists public.content_posts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  caption text not null default '',
  status text not null default 'draft' check (status in ('draft','in_review','approved','scheduled','published','failed','rejected')),
  scheduled_at timestamptz,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.post_channels (
  post_id uuid not null references public.content_posts(id) on delete cascade,
  social_account_id uuid not null references public.social_accounts(id) on delete cascade,
  platform_post_id text,
  publish_status text not null default 'pending' check (publish_status in ('pending','published','failed')),
  primary key (post_id, social_account_id)
);

create table if not exists public.approvals (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.content_posts(id) on delete cascade,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  requested_by uuid references auth.users(id) on delete set null,
  reviewed_by uuid references auth.users(id) on delete set null,
  decision text not null default 'pending' check (decision in ('pending','approved','rejected')),
  note text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  resource_type text,
  resource_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists workspace_members_user_idx on public.workspace_members(user_id);
create index if not exists social_accounts_workspace_idx on public.social_accounts(workspace_id);
create index if not exists content_posts_workspace_created_idx on public.content_posts(workspace_id, created_at desc);
create index if not exists approvals_workspace_idx on public.approvals(workspace_id, created_at desc);
create index if not exists audit_logs_workspace_idx on public.audit_logs(workspace_id, created_at desc);

-- Security-definer helpers avoid recursive RLS lookups on workspace_members.
create or replace function public.is_workspace_member(target_workspace uuid)
returns boolean language sql stable security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from public.workspace_members wm
    where wm.workspace_id = target_workspace and wm.user_id = auth.uid()
  );
$$;

create or replace function public.has_workspace_role(target_workspace uuid, allowed_roles text[])
returns boolean language sql stable security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from public.workspace_members wm
    where wm.workspace_id = target_workspace
      and wm.user_id = auth.uid()
      and wm.role = any(allowed_roles)
  );
$$;

revoke all on function public.is_workspace_member(uuid) from public;
revoke all on function public.has_workspace_role(uuid, text[]) from public;
grant execute on function public.is_workspace_member(uuid) to authenticated;
grant execute on function public.has_workspace_role(uuid, text[]) to authenticated;

-- Create a private default workspace for every newly registered user.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer
set search_path = public, auth
as $$
declare
  new_workspace_id uuid;
  workspace_label text;
begin
  workspace_label := coalesce(nullif(trim(new.raw_user_meta_data->>'workspace_name'), ''), 'My Workspace');
  insert into public.workspaces(name, created_by)
  values (workspace_label, new.id)
  returning id into new_workspace_id;

  insert into public.workspace_members(workspace_id, user_id, role)
  values (new_workspace_id, new.id, 'owner');

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_workspace on auth.users;
create trigger on_auth_user_created_workspace
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.social_accounts enable row level security;
alter table public.content_posts enable row level security;
alter table public.post_channels enable row level security;
alter table public.approvals enable row level security;
alter table public.audit_logs enable row level security;

create policy "Members can read their workspaces" on public.workspaces
for select to authenticated using (public.is_workspace_member(id));
create policy "Owners and admins can update workspaces" on public.workspaces
for update to authenticated using (public.has_workspace_role(id, array['owner','admin']))
with check (public.has_workspace_role(id, array['owner','admin']));

create policy "Members can read workspace membership" on public.workspace_members
for select to authenticated using (public.is_workspace_member(workspace_id));
create policy "Owners and admins can manage membership" on public.workspace_members
for all to authenticated
using (public.has_workspace_role(workspace_id, array['owner','admin']))
with check (public.has_workspace_role(workspace_id, array['owner','admin']));

create policy "Members can read social accounts" on public.social_accounts
for select to authenticated using (public.is_workspace_member(workspace_id));
create policy "Admins can manage social accounts" on public.social_accounts
for all to authenticated
using (public.has_workspace_role(workspace_id, array['owner','admin']))
with check (public.has_workspace_role(workspace_id, array['owner','admin']));

create policy "Members can read posts" on public.content_posts
for select to authenticated using (public.is_workspace_member(workspace_id));
create policy "Creators and admins can create posts" on public.content_posts
for insert to authenticated with check (
  public.has_workspace_role(workspace_id, array['owner','admin','manager','creator'])
  and created_by = auth.uid()
);
create policy "Editors can update posts" on public.content_posts
for update to authenticated
using (public.has_workspace_role(workspace_id, array['owner','admin','manager','creator','reviewer']))
with check (public.is_workspace_member(workspace_id));
create policy "Admins can delete posts" on public.content_posts
for delete to authenticated using (public.has_workspace_role(workspace_id, array['owner','admin']));

create policy "Members can read post channels" on public.post_channels
for select to authenticated using (
  exists (select 1 from public.content_posts p where p.id = post_id and public.is_workspace_member(p.workspace_id))
);
create policy "Admins can manage post channels" on public.post_channels
for all to authenticated using (
  exists (select 1 from public.content_posts p where p.id = post_id and public.has_workspace_role(p.workspace_id, array['owner','admin','manager']))
) with check (
  exists (select 1 from public.content_posts p where p.id = post_id and public.has_workspace_role(p.workspace_id, array['owner','admin','manager']))
);

create policy "Members can read approvals" on public.approvals
for select to authenticated using (public.is_workspace_member(workspace_id));
create policy "Creators can request approval" on public.approvals
for insert to authenticated with check (
  public.has_workspace_role(workspace_id, array['owner','admin','manager','creator'])
  and requested_by = auth.uid()
);
create policy "Reviewers can decide approvals" on public.approvals
for update to authenticated
using (public.has_workspace_role(workspace_id, array['owner','admin','manager','reviewer']))
with check (public.is_workspace_member(workspace_id));

create policy "Admins can read audit logs" on public.audit_logs
for select to authenticated using (public.has_workspace_role(workspace_id, array['owner','admin']));
create policy "Members can write audit logs" on public.audit_logs
for insert to authenticated with check (
  public.is_workspace_member(workspace_id) and actor_id = auth.uid()
);

-- Do not grant anon access. Supabase defaults are intentionally tightened.
revoke all on public.workspaces, public.workspace_members, public.social_accounts,
  public.content_posts, public.post_channels, public.approvals, public.audit_logs from anon;
grant select, update on public.workspaces to authenticated;
grant select, insert, update, delete on public.workspace_members to authenticated;
grant select (id, workspace_id, platform, platform_account_id, account_name, status, token_expires_at, connected_by, created_at, updated_at) on public.social_accounts to authenticated;\ngrant insert (workspace_id, platform, platform_account_id, account_name, status, token_expires_at, connected_by) on public.social_accounts to authenticated;\ngrant update (account_name, status, token_expires_at, updated_at) on public.social_accounts to authenticated;\ngrant delete on public.social_accounts to authenticated;
grant select, insert, update, delete on public.content_posts to authenticated;
grant select, insert, update, delete on public.post_channels to authenticated;
grant select, insert, update on public.approvals to authenticated;
grant select, insert on public.audit_logs to authenticated;
