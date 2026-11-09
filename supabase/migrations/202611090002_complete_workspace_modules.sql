-- Ensure the client-brand schema exists even if the earlier dashboard migration was not applied yet.
create table if not exists public.client_brands (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 name text not null check (char_length(name) between 1 and 120),
 industry text not null default '',
 website text not null default '',
 brand_color text not null default '#ef3328',
 notes text not null default '',
 created_at timestamptz not null default now()
);
create index if not exists client_brands_workspace_idx on public.client_brands(workspace_id);
alter table public.client_brands enable row level security;
drop policy if exists "Members read client brands" on public.client_brands;
create policy "Members read client brands" on public.client_brands for select to authenticated using (public.is_workspace_member(workspace_id));
drop policy if exists "Admins manage client brands" on public.client_brands;
create policy "Admins manage client brands" on public.client_brands for all to authenticated
using (public.has_workspace_role(workspace_id,array['owner','admin','manager']))
with check (public.has_workspace_role(workspace_id,array['owner','admin','manager']));
grant select,insert,update,delete on public.client_brands to authenticated;
revoke all on public.client_brands from anon;

alter table public.content_posts add column if not exists title text not null default '';
alter table public.content_posts add column if not exists platform_targets text[] not null default '{}';
alter table public.content_posts add column if not exists content_type text not null default 'Post';
alter table public.content_posts add column if not exists brand_id uuid references public.client_brands(id) on delete set null;
alter table public.content_posts add column if not exists reviewer_note text not null default '';

-- Complete workspace modules: brands, team invitations, comments, media and notifications.
-- Apply after 202611090001_dashboard_modules.sql in Supabase SQL Editor.

create table if not exists public.workspace_invitations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  email text not null,
  role text not null check (role in ('admin','manager','creator','reviewer','client')),
  invited_by uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','revoked','expired')),
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  unique (workspace_id, email)
);
create index if not exists workspace_invitations_workspace_idx on public.workspace_invitations(workspace_id, created_at desc);
alter table public.workspace_invitations enable row level security;
drop policy if exists "Admins manage workspace invitations" on public.workspace_invitations;
create policy "Admins manage workspace invitations" on public.workspace_invitations
for all to authenticated
using (public.has_workspace_role(workspace_id,array['owner','admin']))
with check (public.has_workspace_role(workspace_id,array['owner','admin']));
grant select, insert, update, delete on public.workspace_invitations to authenticated;
revoke all on public.workspace_invitations from anon;

create table if not exists public.content_comments (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 post_id uuid not null references public.content_posts(id) on delete cascade,
 author_id uuid references auth.users(id) on delete set null,
 body text not null check (char_length(body) between 1 and 5000),
 created_at timestamptz not null default now()
);
create index if not exists content_comments_post_idx on public.content_comments(post_id,created_at);
alter table public.content_comments enable row level security;
drop policy if exists "Workspace members read comments" on public.content_comments;
create policy "Workspace members read comments" on public.content_comments for select to authenticated using (public.is_workspace_member(workspace_id));
drop policy if exists "Workspace members add comments" on public.content_comments;
create policy "Workspace members add comments" on public.content_comments for insert to authenticated with check (public.is_workspace_member(workspace_id) and author_id=auth.uid());
drop policy if exists "Authors and admins delete comments" on public.content_comments;
create policy "Authors and admins delete comments" on public.content_comments for delete to authenticated using (author_id=auth.uid() or public.has_workspace_role(workspace_id,array['owner','admin']));
grant select,insert,delete on public.content_comments to authenticated;
revoke all on public.content_comments from anon;

create table if not exists public.media_assets (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 uploaded_by uuid references auth.users(id) on delete set null,
 file_name text not null,
 storage_path text not null unique,
 mime_type text not null,
 size_bytes bigint not null default 0 check (size_bytes >= 0),
 alt_text text not null default '',
 created_at timestamptz not null default now()
);
create index if not exists media_assets_workspace_idx on public.media_assets(workspace_id,created_at desc);
alter table public.media_assets enable row level security;
drop policy if exists "Members read media assets" on public.media_assets;
create policy "Members read media assets" on public.media_assets for select to authenticated using (public.is_workspace_member(workspace_id));
drop policy if exists "Editors upload media assets" on public.media_assets;
create policy "Editors upload media assets" on public.media_assets for insert to authenticated with check (public.has_workspace_role(workspace_id,array['owner','admin','manager','creator']) and uploaded_by=auth.uid());
drop policy if exists "Editors delete media assets" on public.media_assets;
create policy "Editors delete media assets" on public.media_assets for delete to authenticated using (uploaded_by=auth.uid() or public.has_workspace_role(workspace_id,array['owner','admin']));
grant select,insert,delete on public.media_assets to authenticated;
revoke all on public.media_assets from anon;

create table if not exists public.workspace_notifications (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 user_id uuid references auth.users(id) on delete cascade,
 title text not null,
 body text not null default '',
 kind text not null default 'info',
 read_at timestamptz,
 created_at timestamptz not null default now()
);
create index if not exists workspace_notifications_user_idx on public.workspace_notifications(user_id,created_at desc);
alter table public.workspace_notifications enable row level security;
drop policy if exists "Users read own notifications" on public.workspace_notifications;
create policy "Users read own notifications" on public.workspace_notifications for select to authenticated using (user_id=auth.uid() and public.is_workspace_member(workspace_id));
drop policy if exists "Users update own notifications" on public.workspace_notifications;
create policy "Users update own notifications" on public.workspace_notifications for update to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
grant select,update on public.workspace_notifications to authenticated;
revoke all on public.workspace_notifications from anon;

-- Create a private workspace media bucket. Objects are stored under {workspace_id}/{uuid}-{filename}.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('workspace-media','workspace-media',false,52428800,array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/quicktime','application/pdf'])
on conflict (id) do update set public=false,file_size_limit=52428800,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "Workspace members read media objects" on storage.objects;
create policy "Workspace members read media objects" on storage.objects for select to authenticated using (
 bucket_id='workspace-media' and public.is_workspace_member((split_part(name,'/',1))::uuid)
);
drop policy if exists "Workspace editors upload media objects" on storage.objects;
create policy "Workspace editors upload media objects" on storage.objects for insert to authenticated with check (
 bucket_id='workspace-media'
 and public.has_workspace_role((split_part(name,'/',1))::uuid,array['owner','admin','manager','creator'])
);
drop policy if exists "Workspace editors delete media objects" on storage.objects;
create policy "Workspace editors delete media objects" on storage.objects for delete to authenticated using (
 bucket_id='workspace-media'
 and (owner_id=auth.uid()::text or public.has_workspace_role((split_part(name,'/',1))::uuid,array['owner','admin']))
);

-- When an invited user first signs up, attach them to the inviter's workspace and mark invite accepted.
create or replace function public.accept_workspace_invites_for_new_user()
returns trigger language plpgsql security definer set search_path=public,auth
as $$
begin
 if new.email is not null then
   insert into public.workspace_members(workspace_id,user_id,role)
   select wi.workspace_id,new.id,wi.role
   from public.workspace_invitations wi
   where lower(wi.email)=lower(new.email)
     and wi.status='pending'
     and wi.expires_at>now()
   on conflict (workspace_id,user_id) do nothing;

   update public.workspace_invitations
   set status='accepted',accepted_at=now()
   where lower(email)=lower(new.email) and status='pending' and expires_at>now();
 end if;
 return new;
end;
$$;
drop trigger if exists on_auth_user_created_accept_workspace_invites on auth.users;
create trigger on_auth_user_created_accept_workspace_invites after insert on auth.users
for each row execute procedure public.accept_workspace_invites_for_new_user();

-- Keep role checks strict: client role is read-only and reviewers can review, not create content.
drop policy if exists "Editors can update posts" on public.content_posts;
create policy "Editors can update posts" on public.content_posts for update to authenticated
using (public.has_workspace_role(workspace_id,array['owner','admin','manager','creator','reviewer']))
with check (public.is_workspace_member(workspace_id));
drop policy if exists "Reviewers can decide approvals" on public.approvals;
create policy "Reviewers can decide approvals" on public.approvals for update to authenticated
using (public.has_workspace_role(workspace_id,array['owner','admin','manager','reviewer']))
with check (public.is_workspace_member(workspace_id));
