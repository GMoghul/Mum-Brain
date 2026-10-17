# Mum Brain – phone app version

This branch (`app-store`) turns the web app into a real iPhone app (Android later) using Capacitor.
The live web app on GitHub Pages (`main`) is not affected.

## How it works
- `index.html` stays the single source of the app. `npm run web` copies it into `www/`, which the phone app is built from.
- GitHub's Mac computers build the app (see `.github/workflows/ios-build.yml`), so no Mac is needed.
- App ID: `com.gmoghul.mumbrainsorted` (can still be changed until the first upload to Apple – after that it's permanent).

## Stages
1. **Done:** project set up and a test build on GitHub's Macs.
2. **Next (needs Apple approval):** signing + automatic upload to TestFlight. Needs an App Store Connect API key saved as GitHub secrets.
3. **Done (v1.6.0):** closed-app alarms and the morning summary (local notifications, scheduled on the phone).
   - Morning summary: on by default at 9am; on/off and time in Settings (phone app only).
   - Alarms: same alarm options as the web app; notifications have a **Done** button.
   - iPhone allows 64 waiting notifications, so the app plans 10 days of morning summaries and the 50 soonest alarms, and re-plans every time jobs change or the app is opened.
   - Limits: the summary uses the jobs the phone knew about when the app was last opened; normal notifications are muted on silent (true alarms through silent are a possible later upgrade).
4. **Done (v1.6.1):** on-device safe copy. Everything the app saves is also kept in the app's own storage (iPhone UserDefaults, via @capacitor/preferences), which iPhone doesn't clear. If the web storage is ever wiped, the app restores from the safe copy and reloads once. The Safari-only "Add to Home Screen" cards are hidden in the phone app.
5. Home-screen widget (Dawn-style: greeting, today's jobs, brain dump nudge, month view on larger sizes).
6. App icon, privacy policy page, store listing and screenshots.
