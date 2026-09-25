// SAMEPACE push notifications (Supabase Edge Function "push").
//
// Called by the database (migration 0050) whenever something happens that
// should reach a phone: a new chat message, a new Sportbuddy, a chat
// request. Looks up who should get it and sends a Web Push to each of their
// devices. Everything is plain Web Crypto — no npm packages — so the whole
// function is this one file and can be pasted into the Supabase dashboard.
//
// The VAPID key pair is created on first use and stored in the push_config
// table (only readable with the service role), so there are no keys to copy
// around by hand.
//
// Deploy with "Enforce JWT verification" OFF: the database calls it without
// a user token and proves itself with push_config.webhook_secret instead.

const CONTACT = "mailto:samepace@outlook.de";

// ---------------------------------------------------------------- helpers

const enc = new TextEncoder();

export function b64url(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function fromB64url(s: string): Uint8Array {
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/") +
    "===".slice((s.length + 3) % 4);
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function concat(...parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let o = 0;
  for (const p of parts) {
    out.set(p, o);
    o += p.length;
  }
  return out;
}

async function hmac(key: Uint8Array, data: Uint8Array): Promise<Uint8Array> {
  const k = await crypto.subtle.importKey(
    "raw",
    key as BufferSource,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(await crypto.subtle.sign("HMAC", k, data as BufferSource));
}

// ------------------------------------------------------------ VAPID keys

export interface VapidKeys {
  publicKey: string; // raw P-256 point, base64url — the app's applicationServerKey
  privateJwk: JsonWebKey;
}

export async function generateVapidKeys(): Promise<VapidKeys> {
  const pair = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  ) as CryptoKeyPair;
  const raw = new Uint8Array(
    await crypto.subtle.exportKey("raw", pair.publicKey),
  );
  return {
    publicKey: b64url(raw),
    privateJwk: await crypto.subtle.exportKey("jwk", pair.privateKey),
  };
}

async function vapidAuthHeader(
  endpoint: string,
  keys: VapidKeys,
): Promise<string> {
  const header = b64url(enc.encode(JSON.stringify({ typ: "JWT", alg: "ES256" })));
  const claims = b64url(enc.encode(JSON.stringify({
    aud: new URL(endpoint).origin,
    exp: Math.floor(Date.now() / 1000) + 12 * 60 * 60,
    sub: CONTACT,
  })));
  const key = await crypto.subtle.importKey(
    "jwk",
    keys.privateJwk,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      enc.encode(`${header}.${claims}`),
    ),
  );
  return `vapid t=${header}.${claims}.${b64url(signature)}, k=${keys.publicKey}`;
}

// ------------------------------------------- payload encryption (RFC 8291)

export async function encryptPayload(
  plaintext: Uint8Array,
  p256dh: string,
  authSecret: string,
  salt: Uint8Array = crypto.getRandomValues(new Uint8Array(16)),
): Promise<Uint8Array> {
  const uaPublic = fromB64url(p256dh);
  const auth = fromB64url(authSecret);

  const local = await crypto.subtle.generateKey(
    { name: "ECDH", namedCurve: "P-256" },
    true,
    ["deriveBits"],
  ) as CryptoKeyPair;
  const asPublic = new Uint8Array(
    await crypto.subtle.exportKey("raw", local.publicKey),
  );
  const uaKey = await crypto.subtle.importKey(
    "raw",
    uaPublic as BufferSource,
    { name: "ECDH", namedCurve: "P-256" },
    false,
    [],
  );
  const ecdhSecret = new Uint8Array(
    await crypto.subtle.deriveBits(
      { name: "ECDH", public: uaKey },
      local.privateKey,
      256,
    ),
  );

  // HKDF steps from RFC 8291 §3.4 / RFC 8188 §2.2, each output fits in one
  // SHA-256 block so Expand is a single HMAC over info || 0x01.
  const prkKey = await hmac(auth, ecdhSecret);
  const keyInfo = concat(
    enc.encode("WebPush: info\0"),
    uaPublic,
    asPublic,
    new Uint8Array([1]),
  );
  const ikm = await hmac(prkKey, keyInfo);
  const prk = await hmac(salt, ikm);
  const cek = (await hmac(
    prk,
    concat(enc.encode("Content-Encoding: aes128gcm\0"), new Uint8Array([1])),
  )).slice(0, 16);
  const nonce = (await hmac(
    prk,
    concat(enc.encode("Content-Encoding: nonce\0"), new Uint8Array([1])),
  )).slice(0, 12);

  const aesKey = await crypto.subtle.importKey(
    "raw",
    cek,
    { name: "AES-GCM" },
    false,
    ["encrypt"],
  );
  // One record: the payload plus the 0x02 "last record" delimiter.
  const ciphertext = new Uint8Array(
    await crypto.subtle.encrypt(
      { name: "AES-GCM", iv: nonce },
      aesKey,
      concat(plaintext, new Uint8Array([2])) as BufferSource,
    ),
  );

  const recordSize = new Uint8Array([0, 0, 0x10, 0]); // 4096
  return concat(
    salt,
    recordSize,
    new Uint8Array([asPublic.length]),
    asPublic,
    ciphertext,
  );
}

export interface PushSubscriptionRow {
  endpoint: string;
  user_id: string;
  p256dh: string;
  auth: string;
}

/// Returns the push service's HTTP status (201 = delivered to the service,
/// 404/410 = subscription is gone).
export async function sendPush(
  sub: PushSubscriptionRow,
  payload: unknown,
  keys: VapidKeys,
): Promise<number> {
  const body = await encryptPayload(
    enc.encode(JSON.stringify(payload)),
    sub.p256dh,
    sub.auth,
  );
  const res = await fetch(sub.endpoint, {
    method: "POST",
    headers: {
      Authorization: await vapidAuthHeader(sub.endpoint, keys),
      "Content-Encoding": "aes128gcm",
      "Content-Type": "application/octet-stream",
      TTL: String(24 * 60 * 60),
      Urgency: "high",
    },
    body: body as BodyInit,
  });
  await res.body?.cancel();
  return res.status;
}

// --------------------------------------------------------------- database

// deno-lint-ignore no-explicit-any
const runtime = (globalThis as any).Deno;
const SUPABASE_URL: string = runtime?.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY: string = runtime?.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

async function db(path: string, init: RequestInit = {}): Promise<any> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=representation",
      ...(init.headers ?? {}),
    },
  });
  if (!res.ok) throw new Error(`${path}: ${res.status} ${await res.text()}`);
  const text = await res.text();
  return text ? JSON.parse(text) : null;
}

interface PushConfig {
  webhook_secret: string;
  vapid_public_key: string | null;
  vapid_private_jwk: JsonWebKey | null;
}

async function loadConfig(): Promise<PushConfig> {
  const rows = await db("push_config?id=eq.1&select=*");
  if (!rows?.length) throw new Error("push_config missing — run migration 0050");
  return rows[0];
}

/// The key pair, created on first use. The "is null" filter makes two
/// concurrent first calls agree on one pair.
async function ensureKeys(cfg: PushConfig): Promise<VapidKeys> {
  if (cfg.vapid_public_key && cfg.vapid_private_jwk) {
    return { publicKey: cfg.vapid_public_key, privateJwk: cfg.vapid_private_jwk };
  }
  const fresh = await generateVapidKeys();
  await db("push_config?id=eq.1&vapid_public_key=is.null", {
    method: "PATCH",
    body: JSON.stringify({
      vapid_public_key: fresh.publicKey,
      vapid_private_jwk: fresh.privateJwk,
    }),
  });
  const stored = await loadConfig();
  return {
    publicKey: stored.vapid_public_key!,
    privateJwk: stored.vapid_private_jwk!,
  };
}

// [German, English] — same names as in the app.
const SPORTS: Record<string, [string, string]> = {
  laufen: ["Laufen", "running"],
  radfahren: ["Radfahren", "cycling"],
  schwimmen: ["Schwimmen", "swimming"],
  wandern: ["Wandern", "hiking"],
  tennis: ["Tennis", "tennis"],
  padel: ["Padeltennis", "padel"],
  schwangerschaftssport: ["Schwangerschaftssport", "pregnancy fitness"],
  hundeGassi: ["Hunde spazieren", "dog walking"],
  kinderSpielen: ["Kinder spielen", "kids playdate"],
  bouldern: ["Bouldern", "bouldering"],
  badminton: ["Badminton", "badminton"],
  tischtennis: ["Tischtennis", "table tennis"],
  beachvolleyball: ["Beachvolleyball", "beach volleyball"],
  sonstige: ["deine Sportzeit", "your sport time"],
};
const DAYS_DE = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"];
const DAYS_EN = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

const firstName = (full: string | null | undefined) =>
  (full ?? "").trim().split(/\s+/)[0] || "SAMEPACE";

const inList = (ids: string[]) => `(${ids.map((i) => `"${i}"`).join(",")})`;

interface Notice {
  userIds: string[];
  build: (lang: string) => { title: string; body: string };
  url: string;
  tag: string;
}

async function noticeFor(event: any): Promise<Notice | null> {
  if (event.type === "message") {
    const [msg] = await db(
      `messages?id=eq.${event.id}&select=group_id,sender_id,content,gif_url`,
    );
    if (!msg) return null;
    const [group] = await db(`groups?id=eq.${msg.group_id}&select=name,is_direct`);
    const [sender] = await db(`profiles?id=eq.${msg.sender_id}&select=full_name`);
    const members = await db(
      `group_members?group_id=eq.${msg.group_id}&user_id=neq.${msg.sender_id}&muted=is.false&select=user_id`,
    );
    const name = firstName(sender?.full_name);
    const text = (msg.content ?? "").trim();
    return {
      userIds: members.map((m: any) => m.user_id),
      build: (lang: string) => ({
        title: group?.is_direct || !group?.name ? name : `${name} · ${group.name}`,
        body: text
          ? text.length > 140 ? `${text.slice(0, 140)}…` : text
          : msg.gif_url
          ? "GIF"
          : "…",
      }),
      url: `#/group/${msg.group_id}`,
      tag: `chat-${msg.group_id}`,
    };
  }
  if (event.type === "match") {
    const [other] = await db(`profiles?id=eq.${event.other_user_id}&select=full_name`);
    const name = firstName(other?.full_name);
    return {
      userIds: [event.user_id],
      build: (lang) =>
        lang === "en"
          ? { title: "New Sportbuddy! 🎉", body: `You and ${name} both want to train together.` }
          : { title: "Neuer Sportbuddy! 🎉", body: `${name} und du wollt zusammen trainieren.` },
      url: "#/matches",
      tag: `match-${event.other_user_id}`,
    };
  }
  if (event.type === "new_match") {
    const [mine] = await db(
      `activities?id=eq.${event.activity_id}&select=sport,day_of_week,specific_date`,
    );
    const [theirs] = await db(
      `activities?id=eq.${event.other_activity_id}&select=user_id,start_time,end_time`,
    );
    if (!mine || !theirs) return null;
    const [other] = await db(`profiles?id=eq.${theirs.user_id}&select=full_name`);
    const name = firstName(other?.full_name);
    const time = `${theirs.start_time.slice(0, 5)}–${theirs.end_time.slice(0, 5)}`;
    return {
      userIds: [event.user_id],
      build: (lang) => {
        const sport = (SPORTS[mine.sport] ?? SPORTS.sonstige)[lang === "en" ? 1 : 0];
        const day = (lang === "en" ? DAYS_EN : DAYS_DE)[mine.day_of_week - 1];
        return lang === "en"
          ? {
            title: `🎉 New match for ${sport} on ${day}`,
            body: `${name} is in too, ${time}. Take a look!`,
          }
          : {
            title: `🎉 Neuer Match für ${sport} am ${day}`,
            body: `${name} ist auch dabei, ${time}. Schau vorbei!`,
          };
      },
      url: `#/matches/${event.activity_id}`,
      tag: `new-match-${event.activity_id}`,
    };
  }
  if (event.type === "chat_request") {
    const [from] = await db(`profiles?id=eq.${event.from_user}&select=full_name`);
    const name = firstName(from?.full_name);
    return {
      userIds: [event.to_user],
      build: (lang) =>
        lang === "en"
          ? { title: "New chat request", body: `${name} would like to chat with you.` }
          : { title: "Neue Chat-Anfrage", body: `${name} möchte mit dir schreiben.` },
      url: "#/chat",
      tag: `request-${event.from_user}`,
    };
  }
  return null;
}

async function deliver(event: any, keys: VapidKeys): Promise<number> {
  const notice = await noticeFor(event);
  if (!notice || notice.userIds.length === 0) return 0;
  const ids = inList(notice.userIds);
  const subs: PushSubscriptionRow[] = await db(
    `push_subscriptions?user_id=in.${ids}&select=endpoint,user_id,p256dh,auth`,
  );
  if (subs.length === 0) return 0;
  const profiles = await db(
    `profiles?id=in.${ids}&select=id,ui_language,push_quiet_start,push_quiet_end,push_quiet_windows`,
  );
  const langOf = new Map<string, string>(
    profiles.map((p: any) => [p.id, p.ui_language ?? "de"]),
  );
  const quiet = new Set<string>(
    profiles
      .filter((p: any) =>
        inQuietHours(p.push_quiet_start, p.push_quiet_end) ||
        (Array.isArray(p.push_quiet_windows) &&
          p.push_quiet_windows.some((w: any) => inQuietHours(w?.start ?? null, w?.end ?? null)))
      )
      .map((p: any) => p.id),
  );

  let sent = 0;
  await Promise.all(subs.filter((sub) => !quiet.has(sub.user_id)).map(async (sub) => {
    const { title, body } = notice.build(langOf.get(sub.user_id) ?? "de");
    try {
      const status = await sendPush(
        sub,
        { title, body, url: notice.url, tag: notice.tag },
        keys,
      );
      if (status === 404 || status === 410) {
        await db(
          `push_subscriptions?endpoint=eq.${encodeURIComponent(sub.endpoint)}`,
          { method: "DELETE" },
        );
      } else if (status < 300) {
        sent++;
      } else {
        console.warn("push rejected", status, new URL(sub.endpoint).host);
      }
    } catch (e) {
      console.warn("push failed", String(e));
    }
  }));
  return sent;
}

/// Whether it's currently within someone's "Ruhezeit" (Vienna time). A
/// window like 22:00–07:00 wraps past midnight.
export function inQuietHours(
  start: string | null,
  end: string | null,
  now: Date = new Date(),
): boolean {
  if (!start || !end) return false;
  const toMinutes = (t: string) => Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5));
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/Vienna",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(now);
  const part = (type: string) => Number(parts.find((p) => p.type === type)?.value ?? 0);
  const current = part("hour") * 60 + part("minute");
  const s = toMinutes(start);
  const e = toMinutes(end);
  if (s === e) return false;
  return s < e ? current >= s && current < e : current >= s || current < e;
}

// ---------------------------------------------------------------- handler

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

export async function handler(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const event = await req.json().catch(() => ({}));
    const cfg = await loadConfig();

    // The app asks for the public key before subscribing — it's public by
    // design, so no secret needed.
    if (event.action === "publicKey") {
      const keys = await ensureKeys(cfg);
      return json({ publicKey: keys.publicKey });
    }

    if (req.headers.get("x-push-secret") !== cfg.webhook_secret) {
      return json({ error: "forbidden" }, 403);
    }
    const keys = await ensureKeys(cfg);
    const sent = await deliver(event, keys);
    return json({ sent });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
}

runtime?.serve(handler);
