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
5. **Done (widget):** home and lock screen widget (`ios-widget/`, added to the Xcode project by `scripts/add-widget.sh` on GitHub's Mac).
   - Small (day, date, up to 4 jobs), Medium (greeting, date, progress + up to 5 jobs), Large (adds a mini month with dots, Brain dump button, "still to do from earlier"); lock screen: rectangular, circular ring, inline.
   - App's theme colours, dark mode and fonts (static Fraunces/Figtree instances, OFL). Tap opens Today (`mumbrain://today`); Brain dump button opens Brain dump.
   - The app sends the next 8 days of jobs to the App Group `group.com.gmoghul.mumbrainsorted` via its own `WidgetBridge` plugin (registered in `MainViewController`); the widget turns over at midnight by itself.
   - Apple side: App Group created and added to the app's App ID; widget App ID `com.gmoghul.mumbrainsorted.widget` with the same group.
   - The archive is unsigned, so the build gives the app and widget a placeholder signature carrying the App Group before the real signing. Run the workflow by hand with mode `check` to build and sign without uploading.
   - Medium widget (v1.9.6, 25 Oct 2026): up to 6 jobs, with "+N more" at the bottom level with the job count; drops to 5, 4 or 3 jobs if the iPhone's text size is larger so nothing gets cut off.
7. **Shared list notifications (v1.7.0):** when someone adds, changes, ticks off or removes a shared job, everyone else in the family gets a notification showing exactly what changed (e.g. **Dentist** · *Changed by Sam* · When: Fri 30 Oct · 3 pm → Mon 2 Nov · 4 pm).
   - One notification per job, grouped together on the phone. Quick edits to the same job are gathered for 6 seconds first, so one edit = one notification. Your own changes never notify you.
   - Settings › Family sharing: **Your name** (shown to the family) and **Sound / Quiet / Off** (Quiet = silently into the notification list). The iPhone's own settings (Focus, silent, Notifications) always apply.
   - Still private: the wording is written and scrambled on the sender's phone (key made from the family code, salt `mum-brain/family-note/v1`). The server only passes it on; the extension `ios-widget/MumBrainNotify` unscrambles it on the receiving phone. If it can't, the phone shows "A shared job has changed".
   - Pieces: `families/{id}/events` (scrambled messages, deleted once sent), `families/{id}/devices` (each phone's Apple address + Sound/Quiet), the Cloud Function in `functions/` (London, europe-west2), `firestore.rules`.
   - Setup: Apple Push key (.p8) and App ID `com.gmoghul.mumbrainsorted.notify` (with the App Group); Firebase on the Blaze plan; GitHub secrets `FIREBASE_SA`, `APNS_KEY_P8`, `APNS_KEY_ID`; then run **Actions › Firebase setup**. Re-run it whenever `functions/` or `firestore.rules` change.
   - Online version: can't receive these (iPhone web apps can't get them reliably), but once merged into `main` its changes would notify the phone app users.
8. **Family tester feedback (v1.8.0, 24 Oct 2026):**
   - Shared jobs show who added them and who last changed or ticked them off (grey lines under the details in the job screen). Stored inside the scrambled job: `by`/`bd`/`bat` (added by: name, phone id, time) and `eby`/`ebd`/`eat`/`ek` (last change).
   - Shared jobs can have a "Needs doing by" date (`due`, shown as a "By Mon 26 Oct" tag, red once overdue) and a "Who's doing it" (`own` = phone id, `ownN` = name). The choices are Anyone, Me, and anyone the shared list has heard from. In the phone app, whoever it's with (or everyone, if it's anyone's) gets a reminder the morning before the deadline, at the morning summary time.
   - Changes to either show in the shared-change notification ("Needs doing by Fri 30 Oct", "Now with Sam").
   - "Send code" message no longer mentions the online version.
   - Two calmer, unisex themes: Navy and Stone (bottom row with Ink).
9. **Family admins, like a WhatsApp group (v1.9.0, 24 Oct 2026):**
   - Settings › Family sharing shows everyone in the family ("In this family"), with "Admin" next to admins. Whoever created the family is the first admin and can't be removed or dismissed; admins tap a person to **Make admin / Dismiss as admin** or **Remove** (tap twice). If the last admin leaves, the longest-standing member becomes admin.
   - Each phone signs in quietly with Firebase **anonymous sign-in** (turned on in console.firebase.google.com › Security › Authentication, 24 Oct 2026; leave "Auto clean-up" off). `families/{id}/members/{uid}`: name (scrambled with the family key), role, creator, phone id. `meta/owner` = the creator's sign-in (set once; for families made before v1.9.0, the first phone to open v1.9.0 claims it).
   - **Removing someone moves the family to a new code** (they already know the old one, so that's the only way to really shut them out): the admin's phone sets up a new family with the same people and roles (`meta/rotated`), copies the shared jobs across, leaves each remaining member a scrambled note with the new code in `families/{old}/moves/{uid}` (only that member's sign-in can read it), marks the old family `meta/moved` and clears its jobs. Other phones follow automatically; the removed person's phone sees the move with no note and leaves ("You're no longer in the family list"). The notification server ignores moved families.
   - Shared jobs themselves still work without sign-in (so the online version keeps working). People using the online version don't appear in the member list and aren't moved over when someone is removed.
   - Limitation: deleting and reinstalling the app (or clearing its data) gives the phone a new sign-in, so it rejoins as a new member and the old entry stays in the list. If that was the creator, they lose the creator spot.
10. **New look (v1.10.0, 25 Oct 2026)** – after a tester said the app "looked AI-built":
   - Font: new default **Native** (the phone's own font, SF Pro on iPhone). Soft (Fraunces/Figtree) is still in Settings › Font; anyone on Soft is moved to Native once (`prefs.look2`).
   - Accents taken from the icon: Linen `#6548A8` (icon lilac, deeper), Sky `#3767AE` (icon blue, deeper).
   - Section and group labels in normal case (no small capitals with wide spacing).
   - Flatter cards: a hairline edge instead of soft drop shadows; lighter shadow on the tab bar and + button.
   - Progress bar drawn as the icon's three rows (lilac, blue, teal), in the app and the medium widget. Sharp style keeps its plain bar.
   - Widget: plain white background in light mode (no theme colour or wash), dark in dark mode; phone's own font unless the app is on Soft (the app now sends `theme.font`).
6. App icon (brain in rows, 21 Oct 2026 – `icon-1024.png` for the App Store; redraw all sizes with `python3 scripts/make-icon.py .`), privacy policy page, store listing and screenshots.

## Brand pack (keeping a future "everyone" edition open)
All the Mum Brain–specific wording sits in one `BRAND` block at the top of the script in `index.html`:
name, short name, slogan, feedback question, backup file name, example jobs
("Book dentist", "Dentist Fri 3pm", "Camping trip", "baby prep") and the default theme (Linen).
Other places that carry the name: `manifest.json`, `capacitor.config.json` (`appName`) and the icons.

Deliberately **not** in the brand pack, so existing lists, backups and family sharing keep working across
any edition: the storage key, the Firebase project, and the family-sharing encryption salts.

Note: Apple's guideline 4.3 (spam) rejects near-identical apps under separate App IDs, so a general edition
should be either a mode inside this one app, or a clearly different app – not a reskin.
