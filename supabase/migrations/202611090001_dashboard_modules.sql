-- Client brands and content metadata for the Social Command Center
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
create policy "Members read client brands" on public.client_brands for select to authenticated using (public.is_workspace_member(workspace_id));
create policy "Admins manage client brands" on public.client_brands for all to authenticated using (public.has_workspace_role(workspace_id,array['owner','admin','manager'])) with check (public.has_workspace_role(workspace_id,array['owner','admin','manager']));
grant select,insert,update,delete on public.client_brands to authenticated;

alter table public.content_posts add column if not exists title text not null default '';
alter table public.content_posts add column if not exists platform_targets text[] not null default '{}';
alter table public.content_posts add column if not exists content_type text not null default 'Post';
alter table public.content_posts add column if not exists brand_id uuid references public.client_brands(id) on delete set null;
alter table public.content_posts add column if not exists reviewer_note text not null default '';
