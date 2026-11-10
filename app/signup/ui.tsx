"use client";
import { useState } from "react";
import Link from "next/link";
import { ArrowLeft, ArrowRight, Mail, ShieldCheck, UserRoundPlus } from "lucide-react";

export default function SignupForm() {
  const [fullName,setFullName]=useState("");
  const [email,setEmail]=useState("");
  const [company,setCompany]=useState("");
  const [role,setRole]=useState("");
  const [reason,setReason]=useState("");

  function requestAccess(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const subject="New Workspace Access Request – Unboxed Thinking Social Command Center";
    const body=[
      "Hello,","",
      "I would like to request an account for the Unboxed Thinking Social Command Center.","",
      "Full name: "+fullName.trim(),
      "Work email: "+email.trim(),
      "Company: "+(company.trim()||"Not provided"),
      "Role / Team: "+(role.trim()||"Not provided"),
      "Reason for access: "+(reason.trim()||"Not provided"),"",
      "I understand that my account will be created manually by the workspace owner and that login credentials will be shared separately.","",
      "Thank you."
    ].join("\\n");
    window.location.href="mailto:itsshailesh0414@gmail.com?subject="+encodeURIComponent(subject)+"&body="+encodeURIComponent(body);
  }

  return <main className="auth-shell auth-shell-animated">
    <div className="auth-ambient auth-ambient-one" /><div className="auth-ambient auth-ambient-two" />
    <section className="auth-showcase">
      <div className="auth-showcase-top"><span className="auth-live-dot" /> SOCIAL COMMAND CENTER <span className="auth-top-line" /> REQUEST ACCESS</div>
      <div className="auth-orbit auth-orbit-one" /><div className="auth-orbit auth-orbit-two" />
      <div className="auth-logo-wrap"><div className="auth-logo-glow" /><img className="auth-logo-image" src="/unboxed-thinking-logo.jpeg" alt="Unboxed Thinking" /></div>
      <div className="auth-showcase-copy">
        <div className="auth-overline"><UserRoundPlus size={13} /> YOUR WORKSPACE STARTS HERE</div>
        <h2>Good work<br/><span>works better together.</span></h2>
        <p>Tell us a little about yourself and your team. Workspace access is reviewed and provisioned by an administrator.</p>
      </div>
      <div className="auth-feature-row"><div><ShieldCheck size={15}/><span>Manually approved access</span></div><div><Mail size={15}/><span>Direct email request</span></div></div>
      <div className="auth-showcase-foot"><span>UT / DIGITAL OPERATIONS</span><span>BUILT FOR BETTER THINKING</span></div>
    </section>
    <section className="auth-panel">
      <div className="auth-panel-inner">
        <div className="auth-mobile-brand"><img src="/unboxed-thinking-logo.jpeg" alt="Unboxed Thinking"/></div>
        <div className="auth-welcome-label"><span /> WORKSPACE REGISTRATION</div>
        <h1>Request access.</h1>
        <p className="auth-intro">Share your details below. We’ll review your request and create your login separately.</p>
        <form className="auth-access-form" onSubmit={requestAccess}>
          <label>Full name<input value={fullName} onChange={e=>setFullName(e.target.value)} placeholder="Your full name" autoComplete="name" required/></label>
          <label>Work email<input type="email" value={email} onChange={e=>setEmail(e.target.value)} placeholder="you@company.com" autoComplete="email" required/></label>
          <label>Company <span className="auth-optional">(optional)</span><input value={company} onChange={e=>setCompany(e.target.value)} placeholder="Company name" autoComplete="organization"/></label>
          <label>Role / team <span className="auth-optional">(optional)</span><input value={role} onChange={e=>setRole(e.target.value)} placeholder="e.g. Social Media Manager"/></label>
          <label>Reason for access <span className="auth-optional">(optional)</span><textarea value={reason} onChange={e=>setReason(e.target.value)} placeholder="What do you need access for?" rows={3}/></label>
          <button className="auth-submit" type="submit"><Mail size={16}/> Send access request <ArrowRight size={16}/></button>
        </form>
        <Link href="/login" className="auth-cancel-request auth-back-login"><ArrowLeft size={14}/> Back to sign in</Link>
        <p className="auth-legal">This opens an email addressed to the workspace owner. No account is created automatically. Login credentials will be created and shared separately after approval.</p>
        <div className="auth-secure-note"><ShieldCheck size={14}/> Protected workspace access</div>
      </div>
      <div className="auth-panel-footer"><span>© UNBOXED THINKING</span><span>Thoughtful social operations.</span></div>
    </section>
  </main>;
}
