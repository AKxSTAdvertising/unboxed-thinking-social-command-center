import { redirect } from "next/navigation";
import { createClient } from "../lib/supabase/server";
import AuthForm from "./ui";

export default async function LoginPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (user) redirect("/dashboard");
  return <AuthForm />;
}
