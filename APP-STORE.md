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
3. Closed-app alarms and the 9am morning summary (local notifications).
4. Proper on-device storage (no more 7-day Safari wipes).
5. Home-screen widget (Dawn-style: greeting, today's jobs, brain dump nudge, month view on larger sizes).
6. App icon, privacy policy page, store listing and screenshots.
