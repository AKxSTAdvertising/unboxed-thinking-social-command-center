import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = { title: "Social Command Center | UNBOXED THINKING", description: "A focused workspace for managing social content, approvals and performance across every client.", applicationName: "UNBOXED THINKING Social Command Center" };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="en"><body>{children}</body></html>; }
