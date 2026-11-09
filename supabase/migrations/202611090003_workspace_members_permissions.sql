-- Repair authenticated table privileges for workspace membership.
-- RLS remains enabled; these grants do not bypass row-level policies.

grant usage on schema public to authenticated;
grant select, insert, update, delete on table public.workspace_members to authenticated;
revoke all on table public.workspace_members from anon;

alter table public.workspace_members enable row level security;

drop policy if exists "Members can read workspace membership" on public.workspace_members;
create policy "Members can read workspace membership"
on public.workspace_members
for select
to authenticated
using (public.is_workspace_member(workspace_id));

drop policy if exists "Owners and admins can manage membership" on public.workspace_members;
create policy "Owners and admins can manage membership"
on public.workspace_members
for all
to authenticated
using (public.has_workspace_role(workspace_id, array['owner','admin']))
with check (public.has_workspace_role(workspace_id, array['owner','admin']));
