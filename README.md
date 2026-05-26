# NightFall Key System (LootLabs)

Custom key website + API for NightFall, powered by your LootLabs API.

---

## GitHub — same repo or separate?

**Yes — put it in the same repo as `loader.lua`.** That is the recommended setup for your NightFall repo (`quarter67/NightFall`).

Your repo should look like this:

```
NightFall/                    ← your GitHub repo (public)
├── loader.lua                ← users run this in their executor
├── key-system/               ← the key website + API (this folder)
│   ├── server.js
│   ├── package.json
│   ├── .env.example
│   ├── .gitignore
│   ├── README.md
│   └── public/
│       ├── index.html
│       ├── key.html
│       ├── css/
│       └── js/
└── README.md                 ← optional repo readme for GitHub
```

### What to upload vs keep private

| Upload to GitHub | Do NOT upload |
|------------------|---------------|
| `loader.lua` | `improved_script.lua` (keep private — host on CDN or private raw link) |
| `key-system/` folder (all source files) | `key-system/.env` (has your API token) |
| `key-system/.env.example` | `key-system/node_modules/` |
| | `key-system/data/` (keys database — created on server at runtime) |

---

## Step 1 — Add key-system to GitHub

You already have `loader.lua` on GitHub. Add the key system as a **folder inside the same repo**.

### Option A: Upload via GitHub website (easiest)

> **Got "Try uploading fewer than 100 files"?**  
> You dragged the whole `key-system` folder including `node_modules/`. GitHub's web uploader maxes out at 100 files.  
> **Fix:** Only upload source files — **never** upload `node_modules/`, `.env`, or `data/`.  
> A ready-to-upload copy is at `script/github-upload/key-system/` (14 files only).

> **Windows hides `.gitignore` and `.env.example` when dragging?**  
> Windows treats dotfiles as hidden, so they won't appear when you drag the folder.  
> **Fix:** Use the `github-upload/key-system/` folder — it has visible copies named `gitignore` and `env.example` instead. Upload those. Render does not need the dot prefix.

1. Open your repo: `https://github.com/quarter67/NightFall`
2. Click **Add file** → **Upload files**
3. Drag the **`github-upload\key-system`** folder contents (select all inside, not the parent folder):

```
key-system/
├── server.js
├── package.json
├── package-lock.json
├── env.example          ← visible copy (Windows hides .env.example)
├── gitignore            ← visible copy (Windows hides .gitignore)
├── README.md
├── UPLOAD-NOTE.txt
└── public/
    ├── index.html
    ├── key.html
    ├── thumb.svg
    ├── css/style.css
    └── js/app.js
    └── js/key.js
```

   **Do NOT include:**
   - `node_modules/` ← this is what causes the 100-file error
   - `.env` ← has your API token
   - `data/` ← created automatically on the server

4. **Before clicking Commit:** confirm ~14 files are listed (including `env.example` and `gitignore`)
5. Scroll down → **Commit message:** `Add LootLabs key system`
6. Click **Commit changes**

Render will run `npm install` on deploy — that recreates `node_modules` on the server automatically.

### Option B: Git command line

From your script folder on PC:

```powershell
cd c:\Users\amand\Downloads\script

git clone https://github.com/quarter67/NightFall.git
cd NightFall

# Copy loader + key-system into the cloned repo if not already there
# (skip if you're already working inside the repo)

git add loader.lua key-system/
git status
# Confirm .env and node_modules are NOT listed

git commit -m "Add LootLabs key system"
git push
```

---

## Step 2 — Deploy to Render (free hosting)

Render runs your key server 24/7 so users can get keys and the loader can validate them.

### 2.1 Create a Render account

1. Go to [render.com](https://render.com)
2. Sign up (GitHub login works — connects to your repo easily)

### 2.2 Create the Web Service

1. Click **New +** → **Web Service**
2. Connect your GitHub account if asked
3. Select repo: **quarter67/NightFall**
4. Fill in these settings:

| Setting | Value |
|---------|-------|
| **Name** | `nightfall-keys` (or anything you like) |
| **Region** | Pick closest to you |
| **Branch** | `main` |
| **Root Directory** | `key-system` ← **important** because key-system is a subfolder |
| **Runtime** | `Node` |
| **Build Command** | `npm install` |
| **Start Command** | `npm start` |
| **Instance Type** | Free |

5. Scroll to **Environment Variables** → click **Add Environment Variable** for each:

| Key | Value |
|-----|-------|
| `LOOTLABS_API_TOKEN` | Your 64-char token from LootLabs panel |
| `BASE_URL` | `https://nightfall-keys.onrender.com` (use YOUR Render URL — set after first deploy if unsure) |
| `LOOTLABS_TIER_ID` | `4` |
| `LOOTLABS_NUM_TASKS` | `5` |
| `LOOTLABS_THEME` | `4` |
| `KEY_DURATION_HOURS` | `24` |
| `ADMIN_SECRET` | Any random password you make up |

6. Click **Create Web Service**
7. Wait 2–5 minutes for deploy. When it says **Live**, copy your URL  
   Example: `https://nightfall-keys.onrender.com`

### 2.3 Fix BASE_URL after first deploy

If you guessed the URL wrong in step 2.2:

1. Render dashboard → your service → **Environment**
2. Edit `BASE_URL` → set it to your exact live URL (no trailing slash)
3. Save → Render will redeploy automatically

### 2.4 Test the deploy

Open in browser:

```
https://YOUR-RENDER-URL.onrender.com/api/health
```

You should see JSON like:

```json
{"ok":true,"service":"NightFall Key System","lootlabsConfigured":true}
```

Then open:

```
https://YOUR-RENDER-URL.onrender.com
```

You should see the NightFall **Get Key** page.

---

## Step 3 — LootLabs panel setup

The key system will not work until LootLabs postback is enabled. Postback tells your server when someone actually finished the ads.

### 3.1 Complete creator profile (required)

1. Log in at [lootlabs.gg](https://lootlabs.gg)
2. Go to **Profile** / creator settings
3. Fill in **every mandatory field** (payment info, name, etc.)
4. If this is incomplete, the API returns errors even with a valid token

### 3.2 Copy your API token

1. **Profile → API Key** (PC) or **+Menu → API Key** (mobile)
2. Click **Copy API key**
3. Paste into Render env var `LOOTLABS_API_TOKEN` (Step 2.2)

### 3.3 Enable Postback (critical)

1. LootLabs panel → **Advanced** tab
2. Find **Postback** section
3. Set **Postback URL** to:

```
https://YOUR-RENDER-URL.onrender.com/api/postback
```

Replace `YOUR-RENDER-URL` with your actual Render domain.

4. **Enable / turn on** postback
5. Save

Without this, users finish ads but never get a key (key page stays on "Waiting").

### 3.4 LootLabs ad settings (already configured in code)

These are set server-side — you do not change them in the LootLabs panel manually:

| Setting | Value | Meaning |
|---------|-------|---------|
| Tier | `4` | Maximum Profit |
| Tasks | `5` | 5 ad steps per key (max revenue) |
| Theme | `4` | GTA-style locker page |

To lower ads to 3 steps, change `LOOTLABS_NUM_TASKS` to `3` in Render env vars.

---

## Step 4 — Update loader.lua

After deploy, point the loader at your live key server.

1. Open `loader.lua` on your PC
2. Change these lines at the top:

```lua
local CONFIG = {
    REQUIRED_PLACE_ID = 134225461562780,

    -- Your deployed Render URL (no trailing slash)
    API_BASE_URL = "https://nightfall-keys.onrender.com",

    -- Where the actual script is hosted (NOT public GitHub if you want it private)
    SCRIPT_URL = "https://YOUR-CDN-OR-PRIVATE-URL/improved_script.lua?v=",

    KEY_CACHE_PATH = "ScriptHub/nightfall_key.txt",
    MAX_ATTEMPTS = 5,
}
```

3. Upload the updated `loader.lua` to GitHub (same repo, replace the old file)
4. Share **only** `loader.lua` with users — never share `improved_script.lua` directly

### Where to host improved_script.lua

Options (pick one):

- **Private raw GitHub** — separate private repo, use raw link in `SCRIPT_URL`
- **Discord CDN** — upload to a Discord channel, copy link
- **Your own file host / CDN**
- **Pastebin-style host** (less ideal)

The loader downloads the script from `SCRIPT_URL` after key validation.

---

## Step 5 — Full test (do this yourself first)

1. **Health check** — open `https://YOUR-URL/api/health` → should say `"ok": true`
2. **Get Key page** — open `https://YOUR-URL` → click **Get Key**
3. **Complete all 5 ad steps** on the LootLabs page (do not skip)
4. **Key page** — you should land on `/key?sid=...` and see a key like `NF-XXXX-XXXX-XXXX`
5. **Loader** — run `loader.lua` in your executor
6. Paste the key → click **Continue**
7. Script should load

If step 4 fails (stuck on "Waiting"):
- Postback URL in LootLabs is wrong or not enabled
- You did not finish all ad steps

---

## How it works (overview)

1. User clicks **Get Key** on your site (or in the loader).
2. Server creates a LootLabs content locker link (tier 4, 5 ad steps).
3. Destination URL is encrypted with LootLabs Redirect API (anti-bypass).
4. User completes all ad tasks.
5. LootLabs sends a **postback** to `/api/postback` → key is generated.
6. User lands on `/key?sid=...` and copies their key.
7. Loader validates the key + HWID via `/api/validate`.

---

## Local testing (optional)

```powershell
cd c:\Users\amand\Downloads\script\key-system
npm install
npm start
```

Open http://localhost:3000

Create a `.env` file (copy from `.env.example`) and add your LootLabs token locally.  
**Never commit `.env` to GitHub.**

Note: postback from LootLabs will not reach `localhost` unless you use a tunnel (ngrok). For local testing, deploy to Render instead.

---

## API endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/get-link` | Creates LootLabs link + session |
| GET | `/api/postback` | LootLabs callback (automatic) |
| GET | `/api/session/:sid` | Key page polling |
| GET | `/api/validate?key=&hwid=` | Loader validation |
| GET | `/api/health` | Status check |
| GET | `/api/stats?secret=` | Admin stats |

---

## User flow (share this with your users)

1. Run `loader.lua` in your executor.
2. Click **Get Key** → open the link in your browser.
3. Complete **all 5** ad steps (do not skip).
4. Copy the key from the key page.
5. Paste into the loader → **Continue**.

Keys last 24 hours and lock to your HWID on first use.

---

## Mobile players

**Yes — the key system works on mobile**, with a few notes:

| Step | Mobile |
|------|--------|
| **Get Key website** | Works in phone browser (Safari, Chrome). LootLabs ads run on mobile too. |
| **Copy key** | Key page has a Copy button — works on mobile browsers. |
| **Loader in executor** | Works on mobile executors (Delta, Arceus X, etc.) if they support `game:HttpGet` or `request()` to your Render URL. |
| **HWID lock** | Uses `gethwid()` if the executor supports it; otherwise falls back to Roblox UserId. |

**Mobile user flow:**
1. Run `loader.lua` in mobile executor
2. Tap **Get Key** → open link in browser (paste from clipboard if needed)
3. Complete all 5 ad steps on phone
4. Copy key from key page
5. Paste into loader → **Continue**

The NightFall script itself already has mobile UI (touch aim button, etc.) — the key system does not block mobile players.

---

## Troubleshooting

**"Get key failed" / LootLabs error**
- Fill mandatory creator details in LootLabs panel.
- Check `LOOTLABS_API_TOKEN` in Render environment variables.
- Redeploy after changing env vars.

**Key page stuck on "Waiting"**
- Postback URL not set or wrong in LootLabs Advanced tab.
- User did not finish all ad steps.
- `BASE_URL` in Render does not match your live domain.

**"HWID_MISMATCH" in loader**
- Key already used on another PC/executor. Get a new key.

**Loader can't validate / "HTTP request failed"**
- `API_BASE_URL` in `loader.lua` must match your Render URL exactly.
- Executor must allow `game:HttpGet` to your domain.

**Render deploy fails**
- Confirm **Root Directory** is set to `key-system`
- Confirm `package.json` exists inside `key-system/`

**Render free tier sleeps**
- First visit after idle may take ~30 seconds to wake up. This is normal on free tier.

---

## Files in this folder

```
key-system/
  server.js          ← API + LootLabs integration
  package.json       ← Node dependencies
  public/            ← Website (HTML/CSS/JS)
  .env.example       ← Template for env vars (safe to commit)
  .gitignore         ← Blocks .env, node_modules, data/
  data/store.json    ← Created automatically on server (do not commit)
```
