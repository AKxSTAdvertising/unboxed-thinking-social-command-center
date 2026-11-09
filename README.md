# UNBOXED THINKING — Social Command Center

Multi-client social operations for Instagram, Facebook and LinkedIn.

## Implemented foundation
- Supabase email/password signup and sign-in with server-managed sessions.
- Email confirmation callback.
- New account automatically receives a private owner workspace.
- PostgreSQL schema for workspaces, members, social accounts, posts, approvals and audit logs.
- Row Level Security policies isolate data by workspace.
- No fake analytics or fabricated social connection states.

## Stack
Next.js App Router, TypeScript, Tailwind CSS, Supabase Auth, PostgreSQL and `@supabase/ssr`.

## Local setup
1. Install Node.js 20.9+.
2. Run `npm install`.
3. Copy `.env.example` to `.env.local`.
4. Set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`.
5. In Supabase SQL Editor, run `supabase/migrations/202611080001_initial_workspace_security.sql`.
6. Then run `supabase/migrations/202611090002_complete_workspace_modules.sql` to create client brands, invitations, internal discussions, private media storage and notifications.
7. In Supabase Authentication → URL Configuration, set Site URL and allow `http://localhost:3000/auth/callback`.
8. For team invitations, set `SUPABASE_SERVICE_ROLE_KEY` as a server-only environment variable. Never prefix it with `NEXT_PUBLIC_` or commit it.
9. Run `npm run dev` and open `http://localhost:3000`.

## Deployment
Set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` in the hosting provider environment. Add `SUPABASE_SERVICE_ROLE_KEY` only as a server-side secret for team invitations. Configure the production Site URL and callback allowlist in Supabase. Never expose or commit the service-role key.

## Integration boundaries
The workspace inbox currently supports internal content discussions; social DMs require Meta/LinkedIn APIs. Analytics currently reports internal workflow counts only; reach, impressions and engagement require official platform APIs. Publishing requires developer apps, approved permissions, server-side token encryption and production callback configuration.
