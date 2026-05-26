let secret = sessionStorage.getItem("nf_admin_secret") || "";
let currentFilter = "all";
let currentSearch = "";
let keysCache = [];

const loginScreen = document.getElementById("loginScreen");
const dashboard = document.getElementById("dashboard");
const secretInput = document.getElementById("secretInput");
const loginBtn = document.getElementById("loginBtn");
const loginError = document.getElementById("loginError");
const keysList = document.getElementById("keysList");
const keyCount = document.getElementById("keyCount");
const statsRow = document.getElementById("statsRow");
const searchInput = document.getElementById("searchInput");
const modal = document.getElementById("modal");
const modalTitle = document.getElementById("modalTitle");
const modalBody = document.getElementById("modalBody");
const modalCancel = document.getElementById("modalCancel");
const modalSave = document.getElementById("modalSave");

function headers() {
  return {
    "Content-Type": "application/json",
    "X-Admin-Secret": secret,
  };
}

async function api(path, options = {}) {
  const res = await fetch(path, {
    ...options,
    headers: { ...headers(), ...(options.headers || {}) },
  });
  const data = await res.json();
  if (!res.ok || data.ok === false) {
    throw new Error(data.error || "Request failed");
  }
  return data;
}

function fmtDate(ts) {
  if (!ts) return "—";
  return new Date(ts).toLocaleString();
}

function statusTag(status) {
  return `<span class="tag tag-${status}">${status}</span>`;
}

function showModal(title, bodyHtml, onSave) {
  modalTitle.textContent = title;
  modalBody.innerHTML = bodyHtml;
  modal.classList.remove("hidden");
  modalSave.onclick = onSave;
}

function hideModal() {
  modal.classList.add("hidden");
  modalSave.onclick = null;
}

function renderStats(stats) {
  statsRow.innerHTML = `
    <div class="stat-card"><strong>${stats.all}</strong><span>Total</span></div>
    <div class="stat-card"><strong>${stats.active}</strong><span>Active</span></div>
    <div class="stat-card"><strong>${stats.used}</strong><span>Used</span></div>
    <div class="stat-card"><strong>${stats.expired}</strong><span>Expired</span></div>
    <div class="stat-card"><strong>${stats.revoked}</strong><span>Revoked</span></div>
  `;
}

function renderKeys(keys) {
  keyCount.textContent = keys.length;

  if (!keys.length) {
    keysList.innerHTML = `<div class="empty-state">No keys found.</div>`;
    return;
  }

  keysList.innerHTML = keys.map((k) => `
    <div class="key-row" data-key="${k.key}">
      <div class="key-row-top">
        <div>
          <div class="key-value">${k.key}</div>
          <div class="key-meta" style="margin-top:8px">
            ${statusTag(k.status)}
            ${k.manual ? '<span class="tag tag-manual">Manual</span>' : ""}
            <span>${k.expiresInHours}h left</span>
            <span>Created ${fmtDate(k.createdAt)}</span>
          </div>
        </div>
        <div class="row-actions">
          <button class="icon-btn" data-action="copy" data-key="${k.key}">Copy</button>
          <button class="icon-btn" data-action="edit" data-key="${k.key}">Edit</button>
          <button class="icon-btn" data-action="reset" data-key="${k.key}">Reset HWID</button>
          <button class="icon-btn danger" data-action="delete" data-key="${k.key}">Delete</button>
        </div>
      </div>
      <div class="key-meta">
        <span>HWID: ${k.hwid || "Not locked"}</span>
        <span>IP: ${k.postbackIp || "—"}</span>
        <span>Expires: ${fmtDate(k.expiresAt)}</span>
        ${k.note ? `<span>Note: ${k.note}</span>` : ""}
      </div>
    </div>
  `).join("");
}

async function loadKeys() {
  const params = new URLSearchParams({ filter: currentFilter, search: currentSearch });
  const data = await api(`/api/admin/keys?${params}`);
  keysCache = data.keys;
  renderStats(data.stats);
  renderKeys(data.keys);
}

async function tryLogin() {
  secret = secretInput.value.trim();
  if (!secret) return;

  try {
    await api("/api/admin/keys?filter=all");
    sessionStorage.setItem("nf_admin_secret", secret);
    loginScreen.classList.add("hidden");
    dashboard.classList.remove("hidden");
    await loadKeys();
  } catch {
    loginError.textContent = "Invalid admin secret.";
    loginError.classList.remove("hidden");
  }
}

loginBtn.addEventListener("click", tryLogin);
secretInput.addEventListener("keydown", (e) => {
  if (e.key === "Enter") tryLogin();
});

document.querySelectorAll(".filter-btn").forEach((btn) => {
  btn.addEventListener("click", async () => {
    document.querySelectorAll(".filter-btn").forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    currentFilter = btn.dataset.filter;
    await loadKeys();
  });
});

searchInput.addEventListener("input", async (e) => {
  currentSearch = e.target.value.trim();
  await loadKeys();
});

document.getElementById("createKeyBtn").addEventListener("click", () => {
  showModal("Create key", `
    <label>Duration (hours)</label>
    <input id="createHours" type="number" min="1" max="720" value="24" />
    <label>Note (optional)</label>
    <input id="createNote" type="text" maxlength="120" placeholder="e.g. VIP user" />
  `, async () => {
    const hours = document.getElementById("createHours").value;
    const note = document.getElementById("createNote").value;
    await api("/api/admin/keys", {
      method: "POST",
      body: JSON.stringify({ count: 1, hours, note }),
    });
    hideModal();
    await loadKeys();
  });
});

document.getElementById("batchCreateBtn").addEventListener("click", () => {
  showModal("Batch create keys", `
    <label>How many keys</label>
    <input id="batchCount" type="number" min="1" max="50" value="5" />
    <label>Duration (hours)</label>
    <input id="batchHours" type="number" min="1" max="720" value="24" />
    <label>Note (optional)</label>
    <input id="batchNote" type="text" maxlength="120" placeholder="Batch keys" />
  `, async () => {
    const count = document.getElementById("batchCount").value;
    const hours = document.getElementById("batchHours").value;
    const note = document.getElementById("batchNote").value;
    await api("/api/admin/keys", {
      method: "POST",
      body: JSON.stringify({ count, hours, note }),
    });
    hideModal();
    await loadKeys();
  });
});

document.getElementById("deleteExpiredBtn").addEventListener("click", async () => {
  if (!confirm("Delete all expired and revoked keys?")) return;
  await api("/api/admin/keys/expired/all", { method: "DELETE" });
  await loadKeys();
});

document.getElementById("exportBtn").addEventListener("click", () => {
  const blob = new Blob([JSON.stringify(keysCache, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `nightfall-keys-${Date.now()}.json`;
  a.click();
  URL.revokeObjectURL(url);
});

keysList.addEventListener("click", async (e) => {
  const btn = e.target.closest("[data-action]");
  if (!btn) return;
  const key = btn.dataset.key;
  const action = btn.dataset.action;

  if (action === "copy") {
    await navigator.clipboard.writeText(key);
    btn.textContent = "Copied!";
    setTimeout(() => { btn.textContent = "Copy"; }, 1500);
    return;
  }

  if (action === "delete") {
    if (!confirm(`Delete key ${key}?`)) return;
    await api(`/api/admin/keys/${encodeURIComponent(key)}`, { method: "DELETE" });
    await loadKeys();
    return;
  }

  if (action === "reset") {
    await api(`/api/admin/keys/${encodeURIComponent(key)}`, {
      method: "PATCH",
      body: JSON.stringify({ resetHwid: true }),
    });
    await loadKeys();
    return;
  }

  if (action === "edit") {
    const record = keysCache.find((k) => k.key === key);
    showModal("Edit key", `
      <label>Key</label>
      <input value="${key}" readonly />
      <label>Note</label>
      <input id="editNote" type="text" maxlength="120" value="${record?.note || ""}" />
      <label>Add hours to expiry</label>
      <input id="editAddHours" type="number" min="1" max="720" value="24" />
      <label>Revoked</label>
      <input id="editRevoked" type="checkbox" ${record?.revoked ? "checked" : ""} />
    `, async () => {
      const note = document.getElementById("editNote").value;
      const addHours = document.getElementById("editAddHours").value;
      const revoked = document.getElementById("editRevoked").checked;
      await api(`/api/admin/keys/${encodeURIComponent(key)}`, {
        method: "PATCH",
        body: JSON.stringify({ note, addHours, revoked }),
      });
      hideModal();
      await loadKeys();
    });
  }
});

modalCancel.addEventListener("click", hideModal);
modal.addEventListener("click", (e) => {
  if (e.target === modal) hideModal();
});

if (secret) {
  tryLogin();
}
