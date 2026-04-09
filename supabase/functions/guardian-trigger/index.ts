import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Generate a short-lived OAuth2 access token from a Firebase service account.
// Uses Deno's built-in Web Crypto API — no extra dependencies needed.
async function getFcmAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const b64url = (obj: object) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");

  const header = b64url({ alg: "RS256", typ: "JWT" });
  const claims = b64url({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  });

  const signingInput = `${header}.${claims}`;

  // Import the private key from the service account JSON
  const pemBody = serviceAccount.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\n/g, "");

  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const rawSig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  const sig = btoa(String.fromCharCode(...new Uint8Array(rawSig)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  const jwt = `${signingInput}.${sig}`;

  // Exchange the JWT for a Google OAuth2 access token
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const { access_token } = await res.json();
  return access_token;
}

serve(async (req) => {
  const payload = await req.json();
  const record = payload.record; // new row inserted into triggers table

  if (record.type !== "guardian_trigger") {
    return new Response("ignored", { status: 200 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // Look up the target user's FCM token
  const { data: user, error } = await supabase
    .from("users")
    .select("fcm_token")
    .eq("user_id", record.target_user_id)
    .single();

  if (error || !user?.fcm_token) {
    console.error("No FCM token for user:", record.target_user_id);
    return new Response("no token", { status: 404 });
  }

  // Get the service account JSON stored as a Supabase secret
  const serviceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);
  const accessToken = await getFcmAccessToken(serviceAccount);

  // Send via FCM HTTP v1 API
  const fcmRes = await fetch(
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: user.fcm_token,
          data: { type: "guardian_trigger" },
          android: { priority: "high" },
        },
      }),
    }
  );

  const result = await fcmRes.json();
  console.log("FCM v1 result:", JSON.stringify(result));

  return new Response(JSON.stringify(result), { status: 200 });
});
