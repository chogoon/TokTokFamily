// 로컬 `supabase start`가 발급하는 고정된 demo 키 — 민감정보가 아니다
// (Supabase CLI가 모든 로컬 프로젝트에 동일하게 발급하는 공개된 값).
const LOCAL_DEFAULTS = {
  SUPABASE_URL: "http://127.0.0.1:54321",
  SUPABASE_ANON_KEY:
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0",
  SUPABASE_SERVICE_ROLE_KEY:
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU",
};

for (const [key, value] of Object.entries(LOCAL_DEFAULTS)) {
  if (!process.env[key]) {
    process.env[key] = value;
  }
}

export async function isLocalSupabaseUp(): Promise<boolean> {
  try {
    const res = await fetch(`${process.env.SUPABASE_URL}/auth/v1/health`);
    return res.ok;
  } catch {
    return false;
  }
}
