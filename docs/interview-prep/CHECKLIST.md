# Interview Day — Logistics Checklist

**Interview:** Wed 1 Oct 2026 · **11:30 AM** · Conference Cabin, The CO Working
Company, Above Westside, **Orange City Mall-1, Jaiprakash Nagar Metro Station,
Nagpur – 25**. Contact: Viral Mandaviya · 8888888227 · info.swasiq@gmail.com.
**Plan to arrive by 11:00.**

---

## The night before (30 Sep eve)

- [ ] **Laptop** fully charged + charger in the bag
- [ ] **Phone** (Redmi) charged + charger; USB cable for backup
- [ ] **Fixed APK installed** on phone (verify login with the demo accounts — if unsure, re-run `adb`/MTP with the laptop tonight)
- [ ] Laptop: repo at `d7d4ec7` (or latest) — `git status` clean
- [ ] Admin portal verified: run `npm run dev` in `admin-web/`, open `http://localhost:5173`
- [ ] Register a **new device login** check tonight if possible (hotspot ON, phone + laptop)
- [ ] **Printed résumés ×2** (they explicitly asked to bring "Resumes'")
- [ ] Photo ID (any) — coworking venue may ask
- [ ] Rehearse: run the **WALKTHROUGH** once with the **DEMO-SCRIPT** open on the desk

## Morning of (Oct 1)

- [ ] Recharge phone + laptop; put phone hotspot ON as backup internet from the start
- [ ] Laptop: start admin portal (`npm run dev`), open `http://localhost:5173`, stay logged in as admin
- [ ] Phone: open QuickServe, stay on the customer login
- [ ] Open in a tab: `github.com/Rutuja-kale06/quickserve` (for the live code/architecture walkthrough)
- [ ] Open `docs/interview-prep/DEMO-SCRIPT.md` + `WALKTHROUGH.md` as speaker notes
- [ ] Backup: `docs/screenshots/` folder visible in Explorer (no-internet fallback)

## At the venue

- [ ] Confirm the cabin; introduce yourself; hand résumés at the start
- [ ] Demo order: **code → architecture → security → live demo** (5–6 min demo)
- [ ] If Wi-Fi is weak → join laptop to **phone hotspot**; if no internet at all → screenshot fallback + explain live data is safe to sample later
- [ ] End on the **audit log** tab (open), not a login screen

## Recovery lines

- "I built this against a live Supabase project, so every screen reflects real data."
- "That's the permission boundary — the database rejected it, which is exactly what I want to show." (if a denial looks like a glitch)
- "I tested this offline scenario, so let me show the fallback path." (if internet dies)

## What they may ask for extra

- Walk me through `create_request` as if I'm a customer. → Show the RPC + RLS insert policy.
- Show me the deny case live. → Try `update_request_status` on someone else's request / a skip. Expect an audit row.
- Why this stack? / What next? → See QANDA.md.
- Résumé → provide a clean ATS-friendly PDF version alongside the printed copies.