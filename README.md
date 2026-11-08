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
6. In Supabase Authentication → URL Configuration, set Site URL and allow `http://localhost:3000/auth/callback`.
7. Run `npm run dev` and open `http://localhost:3000`.

## Deployment
Set the two public Supabase variables in the hosting provider environment. Configure the production Site URL and callback allowlist in Supabase. The publishable key is intended for client-side use. Never expose a secret/service-role key or commit credentials.

## Not yet enabled
Meta/LinkedIn OAuth, publishing, inbox and platform analytics require separate developer apps, approved platform permissions, server-side token encryption and production callback configuration. The UI must not imply those integrations are live before verification.
