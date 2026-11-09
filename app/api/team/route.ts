import { NextRequest, NextResponse } from "next/server";
import { createClient as createSupabaseClient } from "@supabase/supabase-js";
import { createClient } from "../../lib/supabase/server";

export const runtime = "nodejs";

const adminClient = () => {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("SUPABASE_SERVICE_ROLE_KEY is not configured in the server environment.");
  return createSupabaseClient(url, key, { auth: { autoRefreshToken: false, persistSession: false } });
};

async function context() {
  const supabase = await createClient();
  const { data: { user }, error } = await supabase.auth.getUser();
  if (error || !user) return { response: NextResponse.json({ error: "Authentication required." }, { status: 401 }) };
  const { data: member } = await supabase.from("workspace_members")
    .select("workspace_id,role,workspaces(name)").eq("user_id", user.id).limit(1).single();
  if (!member) return { response: NextResponse.json({ error: "Workspace membership not found." }, { status: 403 }) };
  if (!["owner", "admin"].includes(member.role)) return { response: NextResponse.json({ error: "Only workspace owners and admins can manage team access." }, { status: 403 }) };
  return { supabase, user, member };
}

export async function GET() {
  try {
    const ctx = await context();
    if ("response" in ctx) return ctx.response;
    const admin = adminClient();
    const { data: members, error } = await ctx.supabase.from("workspace_members")
      .select("user_id,role,created_at").eq("workspace_id", ctx.member.workspace_id).order("created_at");
    if (error) return NextResponse.json({ error: error.message }, { status: 400 });
    const userResults = await Promise.all((members || []).map(async (m) => {
      const { data } = await admin.auth.admin.getUserById(m.user_id);
      return { user_id: m.user_id, role: m.role, created_at: m.created_at, email: data.user?.email || "", name: data.user?.user_metadata?.full_name || data.user?.user_metadata?.name || "" };
    }));
    const { data: invitations, error: inviteError } = await ctx.supabase.from("workspace_invitations")
      .select("id,email,role,status,expires_at,created_at").eq("workspace_id", ctx.member.workspace_id).order("created_at", { ascending: false });
    if (inviteError) return NextResponse.json({ error: inviteError.message }, { status: 400 });
    return NextResponse.json({ members: userResults, invitations: invitations || [], workspace_id: ctx.member.workspace_id, current_role: ctx.member.role });
  } catch (e) {
    return NextResponse.json({ error: e instanceof Error ? e.message : "Could not load team." }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    const ctx = await context();
    if ("response" in ctx) return ctx.response;
    const body = await request.json();
    const email = String(body.email || "").trim().toLowerCase();
    const role = String(body.role || "creator");
    const allowed = ["admin", "manager", "creator", "reviewer", "client"];
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return NextResponse.json({ error: "Enter a valid email address." }, { status: 400 });
    if (!allowed.includes(role)) return NextResponse.json({ error: "Invalid role." }, { status: 400 });
    if (role === "admin" && ctx.member.role !== "owner") return NextResponse.json({ error: "Only the owner can assign Admin access." }, { status: 403 });
    const admin = adminClient();
    const { data: userPage, error: userLookupError } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
    if (userLookupError) return NextResponse.json({ error: userLookupError.message }, { status: 400 });
    const alreadyRegistered = userPage.users.find((u) => u.email?.toLowerCase() === email);
    if (alreadyRegistered) {
      const { data: existingMember, error: memberLookupError } = await ctx.supabase.from("workspace_members").select("user_id").eq("workspace_id", ctx.member.workspace_id).eq("user_id", alreadyRegistered.id).maybeSingle();
      if (memberLookupError) return NextResponse.json({ error: memberLookupError.message }, { status: 400 });
      if (existingMember) return NextResponse.json({ error: "This person is already a workspace member." }, { status: 409 });
      if (ctx.member.role !== "owner") return NextResponse.json({ error: "This email already has a Supabase account. Only the workspace owner can add an existing account directly. Ask the owner to add this person." }, { status: 403 });
      const { error: addError } = await ctx.supabase.from("workspace_members").insert({ workspace_id: ctx.member.workspace_id, user_id: alreadyRegistered.id, role });
      if (addError) return NextResponse.json({ error: addError.message }, { status: 400 });
      return NextResponse.json({ ok: true, message: "Existing account added to the workspace. Let them know they can sign in to access it." });
    }
    const { data: existing, error: existingError } = await ctx.supabase.from("workspace_members").select("user_id").eq("workspace_id", ctx.member.workspace_id).limit(1000);
    if (existingError) return NextResponse.json({ error: existingError.message }, { status: 400 });
    if (existing?.length) {
      for (const item of existing) {
        const { data } = await admin.auth.admin.getUserById(item.user_id);
        if (data.user?.email?.toLowerCase() === email) return NextResponse.json({ error: "This person is already a workspace member." }, { status: 409 });
      }
    }
    const { error: insertError } = await admin.from("workspace_invitations").upsert({
      workspace_id: ctx.member.workspace_id, email, role, invited_by: ctx.user.id,
      status: "pending", expires_at: new Date(Date.now() + 7 * 86400000).toISOString()
    }, { onConflict: "workspace_id,email" });
    if (insertError) return NextResponse.json({ error: insertError.message }, { status: 400 });
    const origin = (process.env.NEXT_PUBLIC_SITE_URL || request.nextUrl.origin).replace(/\/$/, "");
    const { error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
      redirectTo: `${origin}/auth/callback?next=/dashboard`,
      data: { invited_workspace_id: ctx.member.workspace_id, invited_role: role }
    });
    if (inviteError) {
      await admin.from("workspace_invitations").update({ status: "revoked" }).eq("workspace_id", ctx.member.workspace_id).eq("email", email);
      return NextResponse.json({ error: inviteError.message }, { status: 400 });
    }
    return NextResponse.json({ ok: true, message: "Invitation email sent. Membership activates when the invited person accepts and signs in." });
  } catch (e) {
    return NextResponse.json({ error: e instanceof Error ? e.message : "Could not send invitation." }, { status: 500 });
  }
}

export async function PATCH(request: NextRequest) {
  try {
    const ctx = await context();
    if ("response" in ctx) return ctx.response;
    const body = await request.json();
    const action = String(body.action || "");
    const id = String(body.id || "");
    if (action === "revoke") {
      const { error } = await ctx.supabase.from("workspace_invitations").update({ status: "revoked" })
        .eq("id", id).eq("workspace_id", ctx.member.workspace_id).eq("status", "pending");
      if (error) return NextResponse.json({ error: error.message }, { status: 400 });
      return NextResponse.json({ ok: true });
    }
    if (action === "role") {
      const role = String(body.role || "");
      const userId = String(body.user_id || "");
      if (!["admin", "manager", "creator", "reviewer", "client"].includes(role)) return NextResponse.json({ error: "Invalid role." }, { status: 400 });
      if (role === "admin" && ctx.member.role !== "owner") return NextResponse.json({ error: "Only the owner can assign Admin access." }, { status: 403 });
      const { data: target, error: targetError } = await ctx.supabase.from("workspace_members").select("role").eq("workspace_id", ctx.member.workspace_id).eq("user_id", userId).single();
      if (targetError) return NextResponse.json({ error: targetError.message }, { status: 400 });
      if (!target || target.role === "owner" || (target.role === "admin" && ctx.member.role !== "owner")) return NextResponse.json({ error: "Only the owner can change an Admin, and nobody can change the Owner." }, { status: 403 });
      const { error } = await ctx.supabase.from("workspace_members").update({ role }).eq("workspace_id", ctx.member.workspace_id).eq("user_id", userId);
      if (error) return NextResponse.json({ error: error.message }, { status: 400 });
      return NextResponse.json({ ok: true });
    }
    if (action === "remove") {
      const userId = String(body.user_id || "");
      if (ctx.member.role !== "owner" || ctx.user.email?.toLowerCase() !== "itsshailesh0414@gmail.com") return NextResponse.json({ error: "Only the primary owner can remove workspace members." }, { status: 403 });
      const { data: target, error: targetError } = await ctx.supabase.from("workspace_members").select("role").eq("workspace_id", ctx.member.workspace_id).eq("user_id", userId).single();
      if (targetError) return NextResponse.json({ error: targetError.message }, { status: 400 });
      if (!target || target.role === "owner" || userId === ctx.user.id) return NextResponse.json({ error: "The primary owner cannot be removed." }, { status: 403 });
      const { error } = await ctx.supabase.from("workspace_members").delete().eq("workspace_id", ctx.member.workspace_id).eq("user_id", userId);
      if (error) return NextResponse.json({ error: error.message }, { status: 400 });
      return NextResponse.json({ ok: true });
    }
    return NextResponse.json({ error: "Unknown team action." }, { status: 400 });
  } catch (e) {
    return NextResponse.json({ error: e instanceof Error ? e.message : "Could not update team." }, { status: 500 });
  }
}
