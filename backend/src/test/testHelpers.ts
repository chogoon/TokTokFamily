import { createClient } from "@supabase/supabase-js";
import { randomUUID } from "crypto";
import "./supabaseTestEnv";
import { createSupabaseAdminClient } from "../lib/supabaseAdmin";

export function adminClient() {
  return createSupabaseAdminClient();
}

export function anonClient() {
  return createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_ANON_KEY!,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );
}

/** 테스트용 Supabase Auth 사용자를 만들고 로그인해 access token을 돌려준다. */
export async function createAuthedUser(): Promise<{
  authUserId: string;
  accessToken: string;
}> {
  const admin = adminClient();
  const email = `test-${randomUUID()}@test.local`;
  const password = "test-password-123456";

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });
  if (createError || !created.user) {
    throw createError ?? new Error("failed to create test user");
  }

  const anon = anonClient();
  const { data: signedIn, error: signInError } = await anon.auth.signInWithPassword({
    email,
    password,
  });
  if (signInError || !signedIn.session) {
    throw signInError ?? new Error("failed to sign in test user");
  }

  return {
    authUserId: created.user.id,
    accessToken: signedIn.session.access_token,
  };
}
