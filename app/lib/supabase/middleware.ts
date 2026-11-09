import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  if (!url || !key) return response;

  const supabase = createServerClient(url, key, {
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll(
        cookiesToSet: Array<{
          name: string;
          value: string;
          options?: Parameters<typeof response.cookies.set>[2];
        }>
      ) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
      },
    },
  });

  // Refresh the auth session, then enforce server-side workspace approval.
  const { data: { user } } = await supabase.auth.getUser();
  const pathname = request.nextUrl.pathname;
  const publicPaths = ["/login", "/pending-approval", "/auth/callback"];
  if (!user || publicPaths.some((path) => pathname === path || pathname.startsWith(path + "/"))) return response;

  // The permanent Primary Owner must never be blocked by signup approval or membership lookup.
  if (user.email?.toLowerCase() === "itsshailesh0414@gmail.com") return response;

  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!serviceKey) {
    if (pathname.startsWith("/api/")) return NextResponse.json({ error: "Server access verification is not configured." }, { status: 503 });
    return NextResponse.redirect(new URL("/login?error=access-check", request.url));
  }

  const headers = { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` };
  const membershipUrl = `${url}/rest/v1/workspace_members?user_id=eq.${encodeURIComponent(user.id)}&select=user_id&limit=1`;
  const membershipResponse = await fetch(membershipUrl, { headers, cache: "no-store" });
  if (!membershipResponse.ok) {
    if (pathname.startsWith("/api/")) return NextResponse.json({ error: "Could not verify workspace membership." }, { status: 503 });
    return NextResponse.redirect(new URL("/login?error=access-check", request.url));
  }
  const memberships = await membershipResponse.json();
  if (Array.isArray(memberships) && memberships.length > 0) return response;

  const requestUrl = `${url}/rest/v1/workspace_access_requests?user_id=eq.${encodeURIComponent(user.id)}&select=status&limit=1`;
  const accessResponse = await fetch(requestUrl, { headers, cache: "no-store" });
  const accessRows = accessResponse.ok ? await accessResponse.json() : [];
  const status = Array.isArray(accessRows) && accessRows[0]?.status;
  if (pathname.startsWith("/api/")) {
    return NextResponse.json({ error: status === "pending" ? "Your signup is awaiting Primary Owner approval." : "Workspace access is not approved." }, { status: 403 });
  }
  if (status === "pending") return NextResponse.redirect(new URL("/pending-approval", request.url));
  // Do not bounce an authenticated user between /dashboard and /login when no membership exists.
  // The pending page is public to authenticated and unauthenticated users, so this is a terminal route.
  return NextResponse.redirect(new URL("/pending-approval?status=not-approved", request.url));
}
