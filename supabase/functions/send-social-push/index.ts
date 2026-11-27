import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

interface PushEventPayload {
  event: "friend_throne" | "friend_comment" | "friend_reaction";
  actor_id: string;
  log_id: string;
  location_kind?: string;
  comment_id?: string;
  comment_body?: string;
  reaction_emoji?: string;
}

interface PushTokenRow {
  id: string;
  user_id: string;
  token: string;
  locale: string;
  notify_friend_thrones: boolean;
  notify_friend_comments: boolean;
  notify_friend_reactions: boolean;
}

interface FirebaseServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

const CHANNEL_BY_EVENT: Record<PushEventPayload["event"], string> = {
  friend_throne: "trono_friend_thrones",
  friend_comment: "trono_friend_comments",
  friend_reaction: "trono_friend_reactions",
};

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

function base64UrlEncode(input: Uint8Array | string): string {
  const bytes =
    typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const clean = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

async function getFcmAccessToken(sa: FirebaseServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = base64UrlEncode(
    JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );
  const unsigned = `${header}.${claim}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64UrlEncode(new Uint8Array(sig))}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!tokenRes.ok) {
    throw new Error(`OAuth token exchange failed: ${tokenRes.status}`);
  }
  const tokenJson = (await tokenRes.json()) as { access_token?: string };
  if (!tokenJson.access_token) {
    throw new Error("Missing access_token in Google OAuth response");
  }
  return tokenJson.access_token;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const expectedSecret = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";
  const providedSecret = req.headers.get("x-trono-webhook-secret") ?? "";
  if (!expectedSecret || !timingSafeEqual(providedSecret, expectedSecret)) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  let payload: PushEventPayload;
  try {
    payload = (await req.json()) as PushEventPayload;
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (
    !payload?.event ||
    !CHANNEL_BY_EVENT[payload.event] ||
    !payload.actor_id ||
    !payload.log_id
  ) {
    return new Response(JSON.stringify({ error: "Missing fields" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // 1. Fetch actor display info
  const { data: actor } = await admin
    .from("profiles")
    .select("display_name, avatar_emoji")
    .eq("id", payload.actor_id)
    .maybeSingle();

  const actorName = actor?.display_name?.trim() || "Trono";
  const actorEmoji = actor?.avatar_emoji?.trim() || "👑";

  // 2. Determine recipient user IDs (strictly excluding actor)
  const recipientUserIds = new Set<string>();

  if (payload.event === "friend_throne") {
    const { data: myGroups } = await admin
      .from("group_members")
      .select("group_id")
      .eq("user_id", payload.actor_id);

    const groupIds = (myGroups ?? []).map((g) => g.group_id as string);
    if (groupIds.length > 0) {
      const { data: peers } = await admin
        .from("group_members")
        .select("user_id")
        .in("group_id", groupIds)
        .neq("user_id", payload.actor_id);

      for (const peer of peers ?? []) {
        recipientUserIds.add(peer.user_id as string);
      }
    }
  } else {
    // Comment or reaction: look up the shared log owner
    const { data: sharedLog } = await admin
      .from("shared_logs")
      .select("user_id")
      .eq("log_id", payload.log_id)
      .maybeSingle();

    const logOwnerId = sharedLog?.user_id as string | undefined;
    if (logOwnerId && logOwnerId !== payload.actor_id) {
      recipientUserIds.add(logOwnerId);
    }

    // For comments, also notify other commenters on the same thread
    if (payload.event === "friend_comment") {
      const { data: threadComments } = await admin
        .from("log_comments")
        .select("user_id")
        .eq("log_id", payload.log_id)
        .neq("user_id", payload.actor_id);

      for (const c of threadComments ?? []) {
        recipientUserIds.add(c.user_id as string);
      }
    }
  }

  if (recipientUserIds.size === 0) {
    return new Response(
      JSON.stringify({ ok: true, sent: 0, reason: "no_recipients" }),
      { headers: { "Content-Type": "application/json" } },
    );
  }

  // 3. Query enabled device tokens for recipients
  const prefColumn =
    payload.event === "friend_throne"
      ? "notify_friend_thrones"
      : payload.event === "friend_comment"
        ? "notify_friend_comments"
        : "notify_friend_reactions";

  const { data: tokens } = await admin
    .from("push_tokens")
    .select(
      "id, user_id, token, locale, notify_friend_thrones, notify_friend_comments, notify_friend_reactions",
    )
    .in("user_id", Array.from(recipientUserIds))
    .eq(prefColumn, true);

  const tokenRows = (tokens ?? []) as PushTokenRow[];
  if (tokenRows.length === 0) {
    return new Response(
      JSON.stringify({ ok: true, sent: 0, reason: "no_enabled_tokens" }),
      { headers: { "Content-Type": "application/json" } },
    );
  }

  // 4. Read Firebase Service Account JSON from secret
  const rawServiceAccount = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";
  if (!rawServiceAccount.trim()) {
    return new Response(
      JSON.stringify({
        ok: true,
        skipped: "FIREBASE_SERVICE_ACCOUNT_JSON_NOT_CONFIGURED",
        recipientTokens: tokenRows.length,
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  }

  const serviceAccount = JSON.parse(rawServiceAccount) as FirebaseServiceAccount;
  const accessToken = await getFcmAccessToken(serviceAccount);
  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;
  const channelId = CHANNEL_BY_EVENT[payload.event];

  let sent = 0;
  const staleIds: string[] = [];

  // Send data-only high-priority FCM messages so Android renders localized copy
  // directly onto the matching native NotificationChannel even when killed.
  await Promise.all(
    tokenRows.map(async (row) => {
      const fcmBody = {
        message: {
          token: row.token,
          android: {
            priority: "high",
            ttl: "1800s",
          },
          data: {
            event: payload.event,
            channel_id: channelId,
            actor_name: actorName,
            actor_emoji: actorEmoji,
            log_id: payload.log_id,
            location_kind: payload.location_kind ?? "",
            comment_body: (payload.comment_body ?? "").slice(0, 140),
            reaction_emoji: payload.reaction_emoji ?? "",
          },
        },
      };

      const res = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(fcmBody),
      });

      if (res.ok) {
        sent++;
      } else {
        const errText = await res.text();
        if (
          res.status === 404 ||
          errText.includes("UNREGISTERED") ||
          errText.includes("INVALID_ARGUMENT")
        ) {
          staleIds.push(row.id);
        }
      }
    }),
  );

  if (staleIds.length > 0) {
    await admin.from("push_tokens").delete().in("id", staleIds);
  }

  return new Response(
    JSON.stringify({ ok: true, sent, pruned: staleIds.length }),
    { headers: { "Content-Type": "application/json" } },
  );
});
