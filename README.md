# NightFall Key System — Simple Setup Guide

This is your key website. Users complete LootLabs ads → get a random key → paste it in the loader.

Works on **PC, mobile, and Safari**.

---

## What your GitHub should look like ✅

If your upload looks like this, **you're good — click Commit:**

```
NightFall/
├── loader.lua
├── server.js
├── package.json
├── package-lock.json
├── README.md
├── env.example
├── gitignore
└── public/
    ├── index.html
    ├── key.html
    ├── admin.html
    ├── thumb.svg
    ├── css/
    │   ├── style.css
    │   └── admin.css
    └── js/
        ├── app.js
        ├── key.js
        └── admin.js
```

**Never upload these:**
- `node_modules/` (too many files, breaks GitHub)
- `.env` (has your secret API token)

---

## Step 1 — Put files on GitHub

1. Go to `github.com/quarter67/NightFall`
2. Click **Add file** → **Upload files**
3. Drag all your files in (like your screenshot)
4. Click **Commit changes**

Done. GitHub part is finished.

---

## Step 2 — Deploy on Render (put it online)

Render hosts your key website for free.

1. Go to [render.com](https://render.com) and sign up (use GitHub login)
2. Click **New +** → **Web Service**
3. Pick your repo: **quarter67/NightFall**
4. Fill in exactly this:

| Setting | What to put |
|---------|-------------|
| Name | `nightfall-keys` (anything works) |
| Language | **Node** (NOT Docker) |
| Branch | `main` |
| Root Directory | **leave blank** |
| Build Command | `npm install` |
| Start Command | `npm start` |
| Plan | **Free** |

5. Scroll down to **Environment Variables**. Add each one:

| Name | Value |
|------|-------|
| `LOOTLABS_API_TOKEN` | Your LootLabs API key |
| `BASE_URL` | `https://nightfall-keys.onrender.com` (your Render URL) |
| `LOOTLABS_TIER_ID` | `4` |
| `LOOTLABS_NUM_TASKS` | `5` |
| `LOOTLABS_THEME` | `4` |
| `KEY_DURATION_HOURS` | `24` |
| `ADMIN_SECRET` | Make up a password (for your admin panel) |

6. Click **Create Web Service**
7. Wait a few minutes until it says **Live**
8. Copy your URL (example: `https://nightfall-keys.onrender.com`)

**Test it:** open `https://YOUR-URL.onrender.com` — you should see the Get Key page.

---

## Step 3 — Set up LootLabs

### 3a. Fill in your profile
1. Log in at [lootlabs.gg](https://lootlabs.gg)
2. Go to **Profile** and fill in everything it asks for
3. If you skip this, keys won't work

### 3b. Turn on Postback (IMPORTANT)
This tells your site when someone finished the ads.

1. LootLabs → **Advanced** tab
2. Find **Postback**
3. Paste this (use YOUR Render URL):

```
https://YOUR-RENDER-URL.onrender.com/api/postback
```

4. Turn postback **ON**
5. Save

**If you skip this, users finish ads but never get a key.**

---

## Step 4 — Update loader.lua

1. Open `loader.lua` on your PC
2. Change this line to your Render URL:

```lua
API_BASE_URL = "https://nightfall-keys.onrender.com",
```

3. Change this to where your script is hosted:

```lua
SCRIPT_URL = "https://YOUR-SCRIPT-LINK/improved_script.lua?v=",
```

4. Upload the new `loader.lua` to GitHub

**Only share `loader.lua` with users. Never share `improved_script.lua` directly.**

---

## Step 5 — Test everything

Do this yourself before giving it to users:

1. Open your website → click **Get Key**
2. Complete **all 5** ad steps (don't skip any)
3. You should get a random key like `NF-A3F2B1-C8D4E5-9F0A1B`
4. Run `loader.lua` in your executor
5. Paste the key → click **Continue**
6. Script should load

---

## Admin panel (manage keys like Junkie)

Open this in your browser:

```
https://YOUR-RENDER-URL.onrender.com/admin
```

Password = whatever you set as `ADMIN_SECRET` in Render.

**You can:**
- See all keys
- Create keys manually
- Delete keys
- Reset HWID (let key work on new device)
- Extend key time
- Export keys

---

## How users get a key

1. Run `loader.lua`
2. Click **Get Key**
3. Finish all 5 ads in browser (Safari/Chrome/mobile all work)
4. Copy the random key
5. Paste in loader → **Continue**

Keys last **24 hours** and lock to one device.

---

## When something breaks

| Problem | Fix |
|---------|-----|
| GitHub says "too many files" | You uploaded `node_modules`. Don't. |
| Render deploy fails | Language must be **Node**, Root Directory **blank** |
| "Get key failed" | Fill LootLabs profile + check API token in Render |
| Key page stuck on "Waiting" | Turn on LootLabs postback (Step 3b) |
| Loader says invalid key | Check `API_BASE_URL` matches your Render URL exactly |
| "HWID_MISMATCH" | Key already used on another device. Make a new key. |
| Site slow first visit | Normal on Render free tier — wait 30 seconds |

---

## Quick links after setup

| What | URL |
|------|-----|
| Get Key page | `https://YOUR-URL.onrender.com` |
| Admin panel | `https://YOUR-URL.onrender.com/admin` |
| Health check | `https://YOUR-URL.onrender.com/api/health` |
| LootLabs postback | `https://YOUR-URL.onrender.com/api/postback` |

Replace `YOUR-URL` with your actual Render domain.
