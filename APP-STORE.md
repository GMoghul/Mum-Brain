# Mum Brain – phone app version

This branch (`app-store`) turns the web app into a real iPhone app (Android later) using Capacitor.
The live web app on GitHub Pages (`main`) is not affected.

## How it works
- `index.html` stays the single source of the app. `npm run web` copies it into `www/`, which the phone app is built from.
- GitHub's Mac computers build the app (see `.github/workflows/ios-build.yml`), so no Mac is needed.
- App ID: `com.gmoghul.mumbrainsorted` (can still be changed until the first upload to Apple – after that it's permanent).

## Stages
1. **Done:** project set up and a test build on GitHub's Macs.
2. **Set up (19 Oct 2026):** signing + automatic upload to TestFlight (job `testflight` in the workflow).
   - Apple side done: App ID `com.gmoghul.mumbrainsorted` (Push Notifications + App Groups), app "Mum Brain, Sorted" in App Store Connect (SKU `mumbrainsorted001`, version 1.0).
   - Needs three GitHub secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (the .p8 file's full text). The key must have **Admin** access – Apple only allows cloud signing with Admin keys. Until they're saved, the upload job is skipped.
   - Build number = the GitHub run number, so every upload is unique. Every push to `app-store` uploads a new TestFlight build.
3. **Done (v1.6.0):** closed-app alarms and the morning summary (local notifications, scheduled on the phone).
   - Morning summary: on by default at 9am; on/off and time in Settings (phone app only).
   - Good morning message (v1.6.2): 3 styles (Gentle, Cheerful, Straight to it), 2 greetings each to pick from, plus a no-jobs line. Only the greeting makes a sound; each job (up to 5, then "+N more") arrives quietly as a "passive" notification grouped underneath, with a Done button. Jobs ticked off in the app are cleared from the notification list.
   - Alarms: same alarm options as the web app; notifications have a **Done** button.
   - iPhone allows 64 waiting notifications, so the app plans 10 days of morning summaries and the 50 soonest alarms, and re-plans every time jobs change or the app is opened.
   - Limits: the summary uses the jobs the phone knew about when the app was last opened; normal notifications are muted on silent (true alarms through silent are a possible later upgrade).
4. **Done (v1.6.1):** on-device safe copy. Everything the app saves is also kept in the app's own storage (iPhone UserDefaults, via @capacitor/preferences), which iPhone doesn't clear. If the web storage is ever wiped, the app restores from the safe copy and reloads once. The Safari-only "Add to Home Screen" cards are hidden in the phone app.
5. Home-screen widget (Dawn-style: greeting, today's jobs, brain dump nudge, month view on larger sizes).
6. App icon (brain in rows, 21 Oct 2026 – `icon-1024.png` for the App Store; redraw all sizes with `python3 scripts/make-icon.py .`), privacy policy page, store listing and screenshots.

## Brand pack (keeping a future "everyone" edition open)
All the Mum Brain–specific wording sits in one `BRAND` block at the top of the script in `index.html`:
name, short name, slogan, tester note, feedback question, backup file name, example jobs
("Book dentist", "Dentist Fri 3pm", "Camping trip", "baby prep") and the default theme (Linen).
Other places that carry the name: `manifest.json`, `capacitor.config.json` (`appName`) and the icons.

Deliberately **not** in the brand pack, so existing lists, backups and family sharing keep working across
any edition: the storage key, the Firebase project, and the family-sharing encryption salts.

Note: Apple's guideline 4.3 (spam) rejects near-identical apps under separate App IDs, so a general edition
should be either a mode inside this one app, or a clearly different app – not a reskin.
