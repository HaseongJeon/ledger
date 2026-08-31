// 전표철 — cases/expenses에 새 행이 생기면 "입력한 사람을 뺀 나머지 멤버"의
// 기기(push_tokens)로 FCM 알림을 보내는 Edge Function.
// 배포: supabase functions deploy notify-entry --no-verify-jwt
// 필요한 시크릿: NOTIFY_WEBHOOK_SECRET, FCM_PROJECT_ID, FCM_SERVICE_ACCOUNT(서비스 계정 JSON 문자열)
import { createClient } from "npm:@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9";

const NOTIFY_WEBHOOK_SECRET = Deno.env.get("NOTIFY_WEBHOOK_SECRET") ?? "";
const FCM_PROJECT_ID = Deno.env.get("FCM_PROJECT_ID") ?? "";
const FCM_SERVICE_ACCOUNT = Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "";

const sb = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

function titleAndBody(table: string, record: Record<string, unknown>) {
  if (table === "cases") {
    const price = Number(record.price) || 0;
    return { title: "새 매출 전표", body: `${record.company ?? ""} · ${price.toLocaleString("ko-KR")}원` };
  }
  const amount = Number(record.amount) || 0;
  return { title: "새 지출", body: `${record.category ?? ""} · ${amount.toLocaleString("ko-KR")}원` };
}

async function fcmAccessToken() {
  const auth = new GoogleAuth({
    credentials: JSON.parse(FCM_SERVICE_ACCOUNT),
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"]
  });
  const client = await auth.getClient();
  const { token } = await client.getAccessToken();
  return token as string;
}

Deno.serve(async req => {
  if (req.headers.get("x-webhook-secret") !== NOTIFY_WEBHOOK_SECRET) {
    return new Response("unauthorized", { status: 401 });
  }
  if (!FCM_PROJECT_ID || !FCM_SERVICE_ACCOUNT) {
    return new Response("fcm not configured", { status: 200 });
  }

  const { table, record } = await req.json();
  const createdBy = record?.created_by;
  if (!table || !createdBy) return new Response("bad request", { status: 400 });

  const { data: tokens, error } = await sb
    .from("push_tokens")
    .select("device_id, fcm_token")
    .neq("user_id", createdBy);
  if (error) return new Response(error.message, { status: 500 });
  if (!tokens?.length) return new Response("no recipients", { status: 200 });

  const accessToken = await fcmAccessToken();
  const { title, body } = titleAndBody(table, record);

  await Promise.all(tokens.map(async t => {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${accessToken}` },
      body: JSON.stringify({ message: { token: t.fcm_token, notification: { title, body } } })
    });
    if (res.status === 404 || res.status === 410) {
      await sb.from("push_tokens").delete().eq("device_id", t.device_id).eq("fcm_token", t.fcm_token);
      return;
    }
    if (!res.ok) {
      const errBody = await res.text().catch(() => "");
      if (errBody.includes("UNREGISTERED") || errBody.includes("NOT_FOUND")) {
        await sb.from("push_tokens").delete().eq("device_id", t.device_id).eq("fcm_token", t.fcm_token);
      }
    }
  }));

  return new Response("ok", { status: 200 });
});
