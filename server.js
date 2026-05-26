require("dotenv").config();

const express = require("express");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;
const BASE_URL = (process.env.BASE_URL || `http://localhost:${PORT}`).replace(/\/$/, "");
const LOOTLABS_TOKEN = process.env.LOOTLABS_API_TOKEN || "";
const TIER_ID = parseInt(process.env.LOOTLABS_TIER_ID || "4", 10);
const NUM_TASKS = parseInt(process.env.LOOTLABS_NUM_TASKS || "5", 10);
const THEME = parseInt(process.env.LOOTLABS_THEME || "4", 10);
const KEY_HOURS = parseInt(process.env.KEY_DURATION_HOURS || "24", 10);
const ADMIN_SECRET = process.env.ADMIN_SECRET || "change-me";
const SCRIPT_SOURCE_URL = process.env.SCRIPT_SOURCE_URL || "";
const LOCAL_SCRIPT_PATH = path.join(__dirname, "script", "improved_script.lua");
const DATA_DIR = path.join(__dirname, "data");
const DATA_FILE = path.join(DATA_DIR, "store.json");

const LOOTLABS = {
  contentLocker: "https://creators.lootlabs.gg/api/public/content_locker",
  urlEncryptor: "https://creators.lootlabs.gg/api/public/url_encryptor",
};

app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

function ensureStore() {
  if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
  if (!fs.existsSync(DATA_FILE)) {
    fs.writeFileSync(DATA_FILE, JSON.stringify({ sessions: {}, keys: {} }, null, 2));
  }
}

function readStore() {
  ensureStore();
  try {
    return JSON.parse(fs.readFileSync(DATA_FILE, "utf8"));
  } catch {
    return { sessions: {}, keys: {} };
  }
}

function writeStore(store) {
  ensureStore();
  fs.writeFileSync(DATA_FILE, JSON.stringify(store, null, 2));
}

function newSessionId() {
  return crypto.randomBytes(16).toString("hex");
}

function generateKey() {
  const part = () => crypto.randomBytes(3).toString("hex").toUpperCase();
  return `NF-${part()}-${part()}-${part()}`;
}

function keyExpiresAt(hours) {
  return Date.now() + (hours || KEY_HOURS) * 60 * 60 * 1000;
}

function normalizeKey(value) {
  return String(value || "").trim().toUpperCase();
}

function getAdminSecret(req) {
  return req.headers["x-admin-secret"] || req.query.secret || "";
}

function requireAdmin(req, res, next) {
  if (getAdminSecret(req) !== ADMIN_SECRET) {
    return json(res, 403, { ok: false, error: "Forbidden" });
  }
  next();
}

function getKeyStatus(record) {
  if (!record) return "missing";
  if (record.revoked) return "revoked";
  if (Date.now() >= record.expiresAt) return "expired";
  if (record.hwid) return "used";
  return "active";
}

function serializeKey(record) {
  const remainingMs = record.expiresAt - Date.now();
  return {
    key: record.key,
    status: getKeyStatus(record),
    createdAt: record.createdAt,
    expiresAt: record.expiresAt,
    expiresInHours: Math.max(0, Math.ceil(remainingMs / 3600000)),
    hwid: record.hwid || null,
    hwidLockedAt: record.hwidLockedAt || null,
    postbackIp: record.postbackIp || null,
    sessionId: record.sessionId || null,
    manual: Boolean(record.manual),
    note: record.note || "",
    revoked: Boolean(record.revoked),
  };
}

async function lootLabsPost(url, body) {
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${LOOTLABS_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    throw new Error(`LootLabs returned non-JSON (${res.status}): ${text.slice(0, 200)}`);
  }
  if (data.type === "error") {
    throw new Error(data.message || "LootLabs API error");
  }
  return data;
}

async function encryptDestination(destinationUrl) {
  const data = await lootLabsPost(LOOTLABS.urlEncryptor, {
    destination_url: destinationUrl,
  });
  return data.message;
}

async function createLootLabsLink(sessionId) {
  const destination = `${BASE_URL}/key?sid=${sessionId}`;
  const encrypted = await encryptDestination(destination);

  const locker = await lootLabsPost(LOOTLABS.contentLocker, {
    title: "NightFall Key",
    url: destination,
    tier_id: TIER_ID,
    number_of_tasks: NUM_TASKS,
    theme: THEME,
    thumbnail: `${BASE_URL}/thumb.svg`,
  });

  let entry = locker.message;
  if (Array.isArray(entry)) entry = entry[0];
  const lootUrl = entry?.loot_url;
  if (!lootUrl) {
    throw new Error("LootLabs did not return loot_url: " + JSON.stringify(locker.message).slice(0, 200));
  }

  const separator = lootUrl.includes("?") ? "&" : "?";
  return `${lootUrl}${separator}data=${encrypted}&puid=${sessionId}`;
}

function isKeyValid(record) {
  if (!record) return false;
  if (record.revoked) return false;
  return Date.now() < record.expiresAt;
}

function json(res, status, body) {
  res.status(status).json(body);
}

function createKeyRecord(options) {
  const key = options.key || generateKey();
  const hours = options.hours || KEY_HOURS;
  return {
    key,
    sessionId: options.sessionId || null,
    createdAt: Date.now(),
    expiresAt: keyExpiresAt(hours),
    hwid: options.hwid || null,
    hwidLockedAt: options.hwid ? Date.now() : null,
    postbackIp: options.postbackIp || null,
    revoked: false,
    manual: Boolean(options.manual),
    note: options.note || "",
  };
}

app.get("/api/health", (_req, res) => {
  json(res, 200, {
    ok: true,
    service: "NightFall Key System",
    lootlabsConfigured: Boolean(LOOTLABS_TOKEN),
    tierId: TIER_ID,
    tasks: NUM_TASKS,
    keyHours: KEY_HOURS,
  });
});

app.post("/api/get-link", async (_req, res) => {
  if (!LOOTLABS_TOKEN) {
    return json(res, 500, { ok: false, error: "LOOTLABS_API_TOKEN not configured on server." });
  }

  const sessionId = newSessionId();
  const store = readStore();

  store.sessions[sessionId] = {
    id: sessionId,
    createdAt: Date.now(),
    completed: false,
    completedAt: null,
    postbackIp: null,
    key: null,
    linkCreatedAt: Date.now(),
  };

  try {
    const url = await createLootLabsLink(sessionId);
    store.sessions[sessionId].lootUrl = url;
    writeStore(store);
    return json(res, 200, { ok: true, url, sessionId });
  } catch (err) {
    delete store.sessions[sessionId];
    writeStore(store);
    console.error("[get-link]", err.message);
    return json(res, 502, { ok: false, error: err.message });
  }
});

app.get("/api/postback", (req, res) => {
  const clickId = String(req.query.click_id || "");
  const ip = String(req.query.ip || "");
  const uniqueId = String(req.query.unique_id || "");

  if (!clickId) {
    return res.status(400).send("missing click_id");
  }

  const store = readStore();
  const session = store.sessions[clickId];

  if (!session) {
    console.warn("[postback] unknown session:", clickId);
    return res.status(200).send("ok");
  }

  if (!session.completed) {
    session.completed = true;
    session.completedAt = Date.now();
    session.postbackIp = ip;
    session.postbackUniqueId = uniqueId;

    const key = generateKey();
    session.key = key;

    store.keys[key] = createKeyRecord({
      key,
      sessionId: clickId,
      postbackIp: ip,
      manual: false,
    });

    writeStore(store);
    console.log("[postback] key issued for session", clickId);
  }

  res.status(200).send("ok");
});

app.get("/api/session/:sid", (req, res) => {
  const sid = req.params.sid;
  const store = readStore();
  const session = store.sessions[sid];

  if (!session) {
    return json(res, 404, { ok: false, error: "Session not found." });
  }

  return json(res, 200, {
    ok: true,
    completed: session.completed,
    key: session.completed ? session.key : null,
    expiresInHours: KEY_HOURS,
  });
});

function validateKeyForHwid(key, hwid) {
  const store = readStore();
  const record = store.keys[key];

  if (!record || !isKeyValid(record)) {
    return { ok: false, error: record?.revoked ? "KEY_REVOKED" : "KEY_EXPIRED" };
  }

  if (!hwid) {
    return { ok: false, error: "Missing HWID." };
  }

  if (record.hwid && record.hwid !== hwid) {
    return { ok: false, error: "HWID_MISMATCH" };
  }

  if (!record.hwid) {
    record.hwid = hwid;
    record.hwidLockedAt = Date.now();
    writeStore(store);
  }

  return { ok: true, record };
}

app.get("/api/validate", (req, res) => {
  const key = normalizeKey(req.query.key);
  const hwid = String(req.query.hwid || "").trim();

  if (!key) {
    return json(res, 400, { ok: false, valid: false, error: "Missing key." });
  }

  const result = validateKeyForHwid(key, hwid);
  if (!result.ok) {
    return json(res, 200, { ok: true, valid: false, error: result.error });
  }

  const remainingMs = result.record.expiresAt - Date.now();
  return json(res, 200, {
    ok: true,
    valid: true,
    expiresAt: record.expiresAt,
    expiresInHours: Math.max(0, Math.ceil(remainingMs / 3600000)),
  });
});

async function loadScriptSource() {
  if (fs.existsSync(LOCAL_SCRIPT_PATH)) {
    const source = fs.readFileSync(LOCAL_SCRIPT_PATH, "utf8");
    if (source && source.length > 0) {
      return source;
    }
  }

  if (!SCRIPT_SOURCE_URL) {
    throw new Error("No script found. Upload script/improved_script.lua to GitHub or set SCRIPT_SOURCE_URL.");
  }

  const scriptRes = await fetch(SCRIPT_SOURCE_URL);
  if (!scriptRes.ok) {
    throw new Error(`Script host returned ${scriptRes.status}`);
  }

  const source = await scriptRes.text();
  if (!source || source.length === 0) {
    throw new Error("Script file is empty");
  }

  return source;
}

app.get("/api/script", async (req, res) => {
  const key = normalizeKey(req.query.key);
  const hwid = String(req.query.hwid || "").trim();

  if (!key) {
    return json(res, 400, { ok: false, error: "Missing key." });
  }

  const result = validateKeyForHwid(key, hwid);
  if (!result.ok) {
    return json(res, 403, { ok: false, error: result.error });
  }

  try {
    const source = await loadScriptSource();
    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    res.send(source);
  } catch (err) {
    console.error("[script]", err.message);
    json(res, 502, { ok: false, error: err.message || "Failed to fetch script." });
  }
});

app.get("/key", (_req, res) => {
  res.sendFile(path.join(__dirname, "public", "key.html"));
});

app.get("/admin", (_req, res) => {
  res.sendFile(path.join(__dirname, "public", "admin.html"));
});

app.get("/api/admin/keys", requireAdmin, (req, res) => {
  const store = readStore();
  const filter = String(req.query.filter || "all").toLowerCase();
  const search = String(req.query.search || "").trim().toLowerCase();

  let keys = Object.values(store.keys).map(serializeKey);

  if (filter !== "all") {
    keys = keys.filter((k) => k.status === filter);
  }

  if (search) {
    keys = keys.filter((k) =>
      k.key.toLowerCase().includes(search)
      || (k.hwid && k.hwid.toLowerCase().includes(search))
      || (k.note && k.note.toLowerCase().includes(search))
      || (k.postbackIp && k.postbackIp.includes(search))
    );
  }

  keys.sort((a, b) => b.createdAt - a.createdAt);

  json(res, 200, {
    ok: true,
    total: keys.length,
    keys,
    stats: {
      all: Object.keys(store.keys).length,
      active: Object.values(store.keys).filter((k) => getKeyStatus(k) === "active").length,
      used: Object.values(store.keys).filter((k) => getKeyStatus(k) === "used").length,
      expired: Object.values(store.keys).filter((k) => getKeyStatus(k) === "expired").length,
      revoked: Object.values(store.keys).filter((k) => getKeyStatus(k) === "revoked").length,
    },
  });
});

app.post("/api/admin/keys", requireAdmin, (req, res) => {
  const store = readStore();
  const count = Math.min(Math.max(parseInt(req.body.count || "1", 10), 1), 50);
  const hours = Math.min(Math.max(parseInt(req.body.hours || String(KEY_HOURS), 10), 1), 720);
  const note = String(req.body.note || "").slice(0, 120);
  const created = [];

  for (let i = 0; i < count; i += 1) {
    const record = createKeyRecord({ hours, note, manual: true });
    store.keys[record.key] = record;
    created.push(serializeKey(record));
  }

  writeStore(store);
  json(res, 200, { ok: true, created });
});

app.patch("/api/admin/keys/:key", requireAdmin, (req, res) => {
  const store = readStore();
  const key = normalizeKey(req.params.key);
  const record = store.keys[key];

  if (!record) {
    return json(res, 404, { ok: false, error: "Key not found." });
  }

  if (typeof req.body.note === "string") {
    record.note = req.body.note.slice(0, 120);
  }

  if (req.body.revoked === true) record.revoked = true;
  if (req.body.revoked === false) record.revoked = false;

  if (req.body.resetHwid === true) {
    record.hwid = null;
    record.hwidLockedAt = null;
  }

  if (req.body.addHours) {
    const add = Math.min(Math.max(parseInt(req.body.addHours, 10), 1), 720);
    record.expiresAt += add * 60 * 60 * 1000;
  }

  if (req.body.hours) {
    const hours = Math.min(Math.max(parseInt(req.body.hours, 10), 1), 720);
    record.expiresAt = Date.now() + hours * 60 * 60 * 1000;
  }

  writeStore(store);
  json(res, 200, { ok: true, key: serializeKey(record) });
});

app.delete("/api/admin/keys/:key", requireAdmin, (req, res) => {
  const store = readStore();
  const key = normalizeKey(req.params.key);

  if (!store.keys[key]) {
    return json(res, 404, { ok: false, error: "Key not found." });
  }

  delete store.keys[key];
  writeStore(store);
  json(res, 200, { ok: true });
});

app.delete("/api/admin/keys/expired/all", requireAdmin, (_req, res) => {
  const store = readStore();
  let removed = 0;

  for (const [key, record] of Object.entries(store.keys)) {
    if (getKeyStatus(record) === "expired" || getKeyStatus(record) === "revoked") {
      delete store.keys[key];
      removed += 1;
    }
  }

  writeStore(store);
  json(res, 200, { ok: true, removed });
});

app.get("/api/stats", requireAdmin, (req, res) => {
  const store = readStore();
  const sessions = Object.values(store.sessions);
  const keys = Object.values(store.keys);

  json(res, 200, {
    ok: true,
    sessions: sessions.length,
    completed: sessions.filter((s) => s.completed).length,
    activeKeys: keys.filter((k) => isKeyValid(k)).length,
    totalKeys: keys.length,
  });
});

app.get("*", (req, res) => {
  if (req.path.startsWith("/api/")) {
    return json(res, 404, { ok: false, error: "Not found" });
  }
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

ensureStore();

if (!LOOTLABS_TOKEN) {
  console.warn("[NightFall] WARNING: LOOTLABS_API_TOKEN is missing. Set it in .env");
}

app.listen(PORT, () => {
  console.log(`[NightFall] Key system running on ${BASE_URL}`);
  console.log(`[NightFall] LootLabs tier ${TIER_ID} · ${NUM_TASKS} tasks · keys last ${KEY_HOURS}h`);
  console.log(`[NightFall] Postback URL → ${BASE_URL}/api/postback`);
  console.log(`[NightFall] Admin panel → ${BASE_URL}/admin`);
});
