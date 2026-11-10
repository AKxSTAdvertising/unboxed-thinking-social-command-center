"use client";
import { useState } from "react";
import { createClient } from "../lib/supabase/client";
import { ArrowRight, Eye, EyeOff, LoaderCircle, Mail, Sparkles, ShieldCheck, Layers3, UserRoundPlus } from "lucide-react";

export default function AuthForm() {
  const [email,setEmail]=useState("");
  const [password,setPassword]=useState("");
  const [showPassword,setShowPassword]=useState(false);
  const [fullName,setFullName]=useState("");
  const [company,setCompany]=useState("");
  const [role,setRole]=useState("");
  const [reason,setReason]=useState("");
  const [requestOpen,setRequestOpen]=useState(false);
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

  function requestAccess(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const subject="New Workspace Access Request – Unboxed Thinking Social Command Center";
    const body=[
      "Hello Shailesh,","",
      "I would like to request an account for the Unboxed Thinking Social Command Center.","",
      "Full name: "+fullName.trim(),
      "Work email: "+email.trim(),
      "Company: "+(company.trim()||"Not provided"),
      "Role / Team: "+(role.trim()||"Not provided"),
      "Reason for access: "+(reason.trim()||"Not provided"),"",
      "I understand that the account will be created manually by the workspace owner and that login credentials will be shared separately.","",
      "Thank you."
    ].join("\\n");
    window.location.href="mailto:itsshailesh0414@gmail.com?subject="+encodeURIComponent(subject)+"&body="+encodeURIComponent(body);
  }

  return <main className="auth-shell auth-shell-animated">
    <div className="auth-ambient auth-ambient-one" /><div className="auth-ambient auth-ambient-two" />
    <section className="auth-showcase">
      <div className="auth-showcase-top"><span className="auth-live-dot" /> SOCIAL COMMAND CENTER <span className="auth-top-line" /> WORKSPACE ACCESS</div>
      <div className="auth-orbit auth-orbit-one" /><div className="auth-orbit auth-orbit-two" />
      <div className="auth-logo-wrap"><div className="auth-logo-glow" /><img className="auth-logo-image" src="/unboxed-thinking-logo.jpeg" alt="Unboxed Thinking" /></div>
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
        <div className="auth-mobile-brand"><img src="/unboxed-thinking-logo.jpeg" alt="Unboxed Thinking"/></div>
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
        {!requestOpen ? <button type="button" className="auth-submit auth-request-button" onClick={()=>setRequestOpen(true)}><UserRoundPlus size={16}/> Sign up / Request access <ArrowRight size={16}/></button> : <form className="auth-access-form" onSubmit={requestAccess}>
          <div className="auth-access-heading">Request a workspace account</div>
          <label>Full name<input value={fullName} onChange={e=>setFullName(e.target.value)} placeholder="Your full name" required/></label>
          <label>Work email<input type="email" value={email} onChange={e=>setEmail(e.target.value)} placeholder="you@company.com" required/></label>
          <label>Company <span className="auth-optional">(optional)</span><input value={company} onChange={e=>setCompany(e.target.value)} placeholder="Company name"/></label>
          <label>Role / team <span className="auth-optional">(optional)</span><input value={role} onChange={e=>setRole(e.target.value)} placeholder="e.g. Social Media Manager"/></label>
          <label>Reason for access <span className="auth-optional">(optional)</span><textarea value={reason} onChange={e=>setReason(e.target.value)} placeholder="What do you need access for?" rows={2}/></label>
          <button className="auth-submit" type="submit"><Mail size={16}/> Send request by email <ArrowRight size={16}/></button>
          <button type="button" className="auth-cancel-request" onClick={()=>setRequestOpen(false)}>Back to sign in</button>
        </form>}
        <p className="auth-legal">Your request opens an email addressed to the workspace owner. No account is created automatically; the owner will create your login and send credentials separately.</p>
        <div className="auth-secure-note"><ShieldCheck size={14}/> Protected workspace access</div>
      </div>
      <div className="auth-panel-footer"><span>© UNBOXED THINKING</span><span>Thoughtful social operations.</span></div>
    </section>
  </main>;
}
