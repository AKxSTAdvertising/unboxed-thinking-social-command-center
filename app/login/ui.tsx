"use client";
import { useState } from "react";
import { createClient } from "../lib/supabase/client";
import { ArrowRight, Eye, EyeOff, LoaderCircle, Mail, Sparkles, ShieldCheck, Layers3, UserRoundPlus } from "lucide-react";

export default function AuthForm() {
  const [email,setEmail]=useState("");
  const [password,setPassword]=useState("");
  const [showPassword,setShowPassword]=useState(false);
  const [loading,setLoading]=useState(false);
  const [error,setError]=useState("");

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault(); setLoading(true); setError("");
    try {
      const supabase=createClient();
      const {error}=await supabase.auth.signInWithPassword({email:email.trim(),password});
      if(error) throw error;
      window.location.assign("/dashboard");
    } catch(e) {
      setError(e instanceof Error ? e.message : "Unable to sign in. Please check your details and try again.");
    } finally { setLoading(false); }
  }

  function requestAccess() {
    const subject="Access Request – Unboxed Thinking Social Command Center";
    const body=[
      "Hello Shailesh,","",
      "I would like to request access to the Unboxed Thinking Social Command Center.","",
      "Name: [Enter your full name]",
      "Work email: "+(email.trim() || "[Enter your work email]"),
      "Role / Team: [Enter your role]",
      "Reason for access: [Briefly describe why you need access]","",
      "Please review my request and let me know once access has been approved.","",
      "Thank you."
    ].join("\n");
    window.location.href="mailto:itsshailesh0414@gmail.com?subject="+encodeURIComponent(subject)+"&body="+encodeURIComponent(body);
  }

  return <main className="auth-shell auth-shell-animated">
    <div className="auth-ambient auth-ambient-one" /><div className="auth-ambient auth-ambient-two" />
    <section className="auth-showcase">
      <div className="auth-showcase-top"><span className="auth-live-dot" /> SOCIAL COMMAND CENTER <span className="auth-top-line" /> WORKSPACE ACCESS</div>
      <div className="auth-orbit auth-orbit-one" /><div className="auth-orbit auth-orbit-two" />
      <div className="auth-logo-wrap"><div className="auth-logo-glow" /><img className="auth-logo-image" src="/unboxed-thinking-logo.svg" alt="Unboxed Thinking" /></div>
      <div className="auth-showcase-copy">
        <div className="auth-overline"><Sparkles size={13} /> ONE WORKSPACE. EVERY CLIENT.</div>
        <h2>Make every<br/><span>connection count.</span></h2>
        <p>Plan, create, approve and manage social media operations — all from one focused command centre.</p>
      </div>
      <div className="auth-feature-row"><div><Layers3 size={15}/><span>Client workspaces</span></div><div><ShieldCheck size={15}/><span>Secure access</span></div></div>
      <div className="auth-showcase-foot"><span>UT / DIGITAL OPERATIONS</span><span>BUILT FOR BETTER THINKING</span></div>
    </section>
    <section className="auth-panel">
      <div className="auth-panel-inner">
        <div className="auth-mobile-brand"><img src="/unboxed-thinking-logo.svg" alt="Unboxed Thinking"/></div>
        <div className="auth-welcome-label"><span /> AUTHORIZED TEAM ACCESS</div>
        <h1>Welcome back.</h1>
        <p className="auth-intro">Sign in with the account provided by your workspace owner to continue.</p>
        <form onSubmit={submit}>
          <label>Work email<input type="email" autoComplete="username" value={email} onChange={e=>setEmail(e.target.value)} placeholder="you@company.com" required/></label>
          <label>Password<div className="password-wrap"><input type={showPassword?"text":"password"} autoComplete="current-password" value={password} onChange={e=>setPassword(e.target.value)} placeholder="Enter your password" required/><button type="button" aria-label={showPassword?"Hide password":"Show password"} onClick={()=>setShowPassword(!showPassword)}>{showPassword?<EyeOff size={16}/>:<Eye size={16}/>}</button></div></label>
          {error && <div className="auth-error" role="alert">{error}</div>}
          <button className="auth-submit" disabled={loading}>{loading?<LoaderCircle className="spin" size={17}/>:<>Sign in <ArrowRight size={16}/></>}</button>
        </form>
        <div className="auth-request-divider"><span>NEW TO THE WORKSPACE?</span></div>
        <button type="button" className="auth-submit auth-request-button" onClick={requestAccess}><UserRoundPlus size={16}/> Request access <Mail size={15}/></button>
        <p className="auth-legal">New accounts are created only by the Primary Owner. Request access by email; never share your password or verification codes.</p>
        <div className="auth-secure-note"><ShieldCheck size={14}/> Protected workspace access</div>
      </div>
      <div className="auth-panel-footer"><span>© UNBOXED THINKING</span><span>Thoughtful social operations.</span></div>
    </section>
  </main>;
}
