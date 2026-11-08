"use client";

import { useState } from "react";
import { createClient } from "../lib/supabase/client";
import { ArrowRight, Eye, EyeOff, LoaderCircle, Mail } from "lucide-react";

const AUTH_CALLBACK = "https://unboxed-thinking-social-command-center-akxstadvertising.vercel.app/auth/callback?next=/dashboard";

export default function AuthForm() {
  const [mode, setMode] = useState<"signin" | "signup">("signup");
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [canResend, setCanResend] = useState(false);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setLoading(true); setError(""); setMessage(""); setCanResend(false);
    try {
      const supabase = createClient();
      if (mode === "signup") {
        const { data, error } = await supabase.auth.signUp({
          email, password,
          options: {
            data: { full_name: name.trim(), workspace_name: name.trim() ? name.trim() + "'s Workspace" : "My Workspace" },
            emailRedirectTo: AUTH_CALLBACK,
          },
        });
        if (error) throw error;
        if (data.session) window.location.assign("/dashboard");
        else if (data.user && data.user.identities?.length === 0) {
          setMessage("This email is already registered. If it is not confirmed yet, resend the confirmation email below. If it is already confirmed, sign in instead.");
          setCanResend(true);
        } else {
          setMessage("Account created. Check your inbox and spam folder for the confirmation email.");
          setCanResend(true);
        }
      } else {
        const { error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) throw error;
        window.location.assign("/dashboard");
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "Something went wrong. Please try again.");
    } finally { setLoading(false); }
  }

  async function resendConfirmation() {
    setLoading(true); setError("");
    try {
      const supabase = createClient();
      const { error } = await supabase.auth.resend({
        type: "signup",
        email,
        options: { emailRedirectTo: AUTH_CALLBACK },
      });
      if (error) throw error;
      setMessage("If this account is still awaiting confirmation, a fresh confirmation email has been requested. Check your inbox and spam folder.");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not resend the confirmation email.");
    } finally { setLoading(false); }
  }

  return <main className="auth-shell">
    <div className="auth-brand"><div className="auth-mark">U<span>T</span></div><div>UNBOXED<br/><b>THINKING</b></div></div>
    <section className="auth-card">
      <div className="auth-kicker">SOCIAL OPERATIONS / COMMAND CENTRE</div>
      <h1>{mode === "signup" ? "Build your command centre." : "Welcome back."}</h1>
      <p className="auth-intro">{mode === "signup" ? "Create your agency workspace and keep every client operation in one place." : "Sign in to continue to your workspace."}</p>
      <div className="auth-tabs"><button className={mode === "signup" ? "selected" : ""} onClick={() => {setMode("signup");setError("");setMessage("");setCanResend(false);}}>Create account</button><button className={mode === "signin" ? "selected" : ""} onClick={() => {setMode("signin");setError("");setMessage("");setCanResend(false);}}>Sign in</button></div>
      <form onSubmit={submit}>
        {mode === "signup" && <label>Your name<input autoComplete="name" value={name} onChange={e=>setName(e.target.value)} placeholder="Full name" required maxLength={80}/></label>}
        <label>Work email<input type="email" autoComplete="email" value={email} onChange={e=>setEmail(e.target.value)} placeholder="you@company.com" required/></label>
        <label>Password<div className="password-wrap"><input type={showPassword ? "text" : "password"} autoComplete={mode === "signup" ? "new-password" : "current-password"} value={password} onChange={e=>setPassword(e.target.value)} placeholder="At least 8 characters" minLength={8} required/><button type="button" aria-label={showPassword ? "Hide password" : "Show password"} onClick={()=>setShowPassword(!showPassword)}>{showPassword ? <EyeOff size={16}/> : <Eye size={16}/>}</button></div></label>
        {error && <div className="auth-error" role="alert">{error}</div>}
        {message && <div className="auth-message" role="status">{message}</div>}
        {canResend && mode === "signup" && <button type="button" className="auth-submit" disabled={loading || !email} onClick={resendConfirmation}><Mail size={16}/> Resend confirmation email</button>}
        <button className="auth-submit" disabled={loading}>{loading ? <LoaderCircle className="spin" size={17}/> : <>{mode === "signup" ? "Create workspace" : "Sign in"} <ArrowRight size={16}/></>}</button>
      </form>
      <p className="auth-legal">By continuing, you agree to use official platform connections. We never ask for your social media passwords.</p>
    </section>
    <div className="auth-footer"><span>UT / SOCIAL COMMAND CENTER</span><span>Thoughtful social operations.</span></div>
  </main>;
}
