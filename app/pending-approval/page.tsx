export default function PendingApprovalPage() {
  return (
    <main style={{ minHeight: "100vh", display: "grid", placeItems: "center", padding: 24, background: "#f7f5fb", color: "#171326" }}>
      <section style={{ width: "100%", maxWidth: 520, background: "#fff", border: "1px solid #e9e4f2", borderRadius: 24, padding: 36, boxShadow: "0 24px 70px rgba(40,20,80,.08)" }}>
        <div style={{ fontSize: 12, letterSpacing: ".16em", fontWeight: 700, color: "#7c3aed" }}>UNBOXED THINKING / ACCESS CONTROL</div>
        <h1 style={{ fontSize: 32, lineHeight: 1.15, margin: "18px 0 12px" }}>Approval pending</h1>
        <p style={{ color: "#625d70", lineHeight: 1.7 }}>Your account has been created. The Primary Owner has received your access request. You will be able to open the company workspace after it is approved.</p>
        <div style={{ marginTop: 24, padding: 16, borderRadius: 14, background: "#f4f0fb", color: "#51466a", fontSize: 14 }}>You can safely close this page. Once approved, sign in again to continue.</div>
        <a href="/login" style={{ display: "inline-flex", marginTop: 24, color: "#6d28d9", fontWeight: 700, textDecoration: "none" }}>Back to sign in</a>
      </section>
    </main>
  );
}
