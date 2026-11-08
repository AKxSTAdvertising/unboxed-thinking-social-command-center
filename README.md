# UNBOXED THINKING — Social Command Center

Multi-client social operations for Instagram, Facebook and LinkedIn.

## Principles
- Real platform connections only; never fabricate metrics or connection states.
- Official OAuth only. Never request social passwords.
- Separate client workspaces and role-based access.
- Draft → review → approval → schedule/publish workflow.
- Clearly identify metrics unavailable through a platform or permission.

## Stack
Next.js App Router, TypeScript, Tailwind CSS. Supabase is planned for auth, Postgres and media storage. Meta Graph API and LinkedIn APIs provide official social integrations.

## Local setup
1. Install Node.js 20.9+.
2. Run `npm install`.
3. Copy `.env.example` to `.env.local` and configure credentials.
4. Run `npm run dev`.

OAuth credentials, platform permissions, production callback URLs and a Supabase project are required before live publishing and analytics can be enabled.
