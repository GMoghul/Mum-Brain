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
11. **Look, round two (v1.11.0, 25 Oct 2026):**
   - Fonts: **Calm** (SF Rounded, `ui-rounded`; Nunito on other phones) is the new default, **Native** now has lighter (500) headings, **Editorial** = light Newsreader headings with an italic slogan. Old Lora "Classic" font renamed **Bookish**; Nunito "Rounded" renamed **Friendly**. Anyone on Native moves to Calm once (`prefs.look3`).
   - Headings: Brain dump 36, Today / Week / Month (and projects) all 28.
   - **Classic theme replaces Sharp** (internal id still `sharp`, so nothing breaks): white page, soft grey sections (#F4F4F6), slate text, no outlines or shadows. 9 muted colours (old Sharp colours map across) plus **Custom** (the phone's own colour wheel); a too-light custom colour is deepened until it reads at 4.5:1 on white.
   - Watercolour has two versions (Settings › Theme, under the palettes): **Painted band** (default; three brushstrokes across the top, like the icon rows, scrolling away with the page) and **Full wash** (the old wash with painted edges, a tide line and paper grain instead of a heavy blur). `prefs.washv` = band / full.
   - Widget: greeting in Newsreader italic (Fraunces italic on Soft), "It's Sunday" / "25th October" (small: "25th Oct"), lighter text, follows the app's font. When everything's done or nothing's planned, the medium and large widgets show a centred resting message (tick above the words) and drop the progress bar; the medium widget's left side centres too. Newsreader static Regular/Italic (OFL) added to the widget's fonts.
12. **Widget, round three (v1.12.0, 26 Oct 2026):**
   - Two widgets in the gallery: **Today** (white, app icon top left, slim painted wash of the icon's three rows along the bottom with a white rim; the job count and "+N more" sit in the wash) and **Today · Simple** (the same without the wash). The lock screen widgets stay under Today.
   - Wording: *Good morning!* (italic, larger), then "Monday" and "26th October" in softer grey, same size.
   - Medium: up to 5 jobs, centred in the space (4 or 3 with larger iPhone text). On the wash, progress shows as "3 of 18 done" (the rows are already there); Simple keeps the three-row bar.
   - Large: same header with the icon. Small: unchanged (3 jobs, no wash).
   - Fix: the app only sends the widget 14 jobs a day, so it now also sends the real totals (`n`, `nd` per day). The widget showed "14 jobs today" when there were 18.
   - Icon: `ios-widget/MumBrainWidget/BrainIcon.png` (copy of `icon-180.png`; refresh it if the icon changes), added to the widget's resources by `scripts/add-widget.rb`.
13. **Widget + button and ticking off (v1.13.0, 26 Oct 2026):**
   - **+ button** (theme accent, purple on Linen / blue on Sky) bottom right of the medium and large widgets: opens Brain dump (`mumbrain://dump`).
   - The wash now sits behind the bottom line itself (job count, "+N more", + button), so the text is always in its middle. `BottomLine` / `WashBand` in the widget.
   - **Tick off from the widget** (iOS 17+): tap a job's circle. `ToggleJobIntent` flips the job in the widget's own copy straight away and adds it to `widgetTicks` in the App Group. The app collects them (`WidgetBridge.takeTicks`) when it opens or comes back to the front, and saves them properly (shared jobs then sync to the family). Tapping a ticked job again unticks it. Older iPhones: tapping just opens the app as before.
14. **Corner washes (v1.14.0, 26 Oct 2026):**
   - A third watercolour version, **Corners** (`prefs.washv` = corners), next to Band and Full wash in Settings › Theme. One colour pooled in the top left, a second in the bottom right, the middle left as paper: hard dried edges with a tide line, gentle mottling (pigment amount only, never its colour), a few loose speckles and paper grain. Made to look less like a typical AI/airbrushed wash. SVG `.w-corner`, filters `cw` / `cspeck` / `cgrain`.
   - Four two-colour themes, shown first under "Corner washes": **Tide** (teal + lilac, matches the icon), **Mist** (soft blue + sage), **Apricot** (peach + sand), **Rosestone** (stone + dusty rose). Picking one switches the wash to Corners; the older palettes sit under "More colours" and work with Corners too.
15. **Painted band removed (v1.15.0, 26 Oct 2026):** watercolour now has two versions, **Corners** (default) and **Full wash**. Anyone on the band (`prefs.washv` = band, or unset) moves to Corners once.
16. **Smoother wash + middle droplets (v1.15.1, 26 Oct 2026):** the wash is now painted once into a still picture (`paintWash()`, an SVG data-URL background on `.wash`) instead of live SVG filters, which the phone was recomputing on every scroll under the frosted tab bar (lag). The SVGs stay in the page only as the recipe. Corners also gets a few faint droplets and brush flicks through the middle.
17. **Watercolour, pared back (v1.16.0, 26 Oct 2026):** after looking at premium watercolour stationery (restraint, one colour in varying strengths, paint framing a clean centre rather than filling it). Six single-colour themes replace the thirteen: **Lilac** (default, was Linen), **Tide**, **Mist**, **Sage**, **Clay**, **Stone**; each has w1 main, w2 deeper, w3 palest. Old themes move to the nearest (`OLD_PAL`). The wash is one soft pool in the top corner behind the heading, fading out before the add box, a pale echo bottom right and fine paper grain; no middle droplets. **Full wash** removed, so there's one watercolour look. Settings previews are crops of the real painted wash (`washURL()`).
18. **Brushstroke rows (v1.17.0, 26 Oct 2026):** the watercolour is now three slim painted brushstrokes along the bottom, just above the tabs: the same shape as the widget's wash and the icon's rows, in three shades of the theme colour (w1, w1 lighter, w3). The rest of the page is clean paper. **Lilac, Mist and Tide** now use the icon's exact lilac (#B8A3E8), blue (#93B6EE) and teal (#9DD3CE). The `.wash` is a 44px strip fixed above the tab bar; Settings previews show the strip along the bottom of each card.
19. **Clear gap under the brushstrokes (v1.17.1, 26 Oct 2026):** the strip now sits about 14px above the tab bar (like the white rim under the widget's wash) instead of running into it.
20. **Who's doing it chips (v1.18.0, 26 Oct 2026):** on Brain dump › Shared, a row of small chips (Everyone · You · each person · Anyone, with counts) shows one person's jobs. Jobs given to the same name count as one person. A job added while a person's chip is picked is given to them. Only shows once at least one shared job has someone doing it.
21. **Widget tidy-up (v1.19.0, 27 Oct 2026):** ticked-off jobs drop off the widget (all sizes) so the next jobs move up; the record stays in the app and the "x of y done" count. "+N more" now counts only jobs still to do. The large widget shows up to 7 jobs when they sit comfortably, otherwise 6 (or 5 with a larger iPhone text size).
22. **Font trial (v1.20.0, 27 Oct 2026):** four premium serif-heading fonts added to Settings › Font to compare with Elegant: Boutique (Prata), Graceful (Gilda Display), Timeless (Libre Caslon Display) and Magazine (Bodoni Moda). Job text stays in Figtree. Widget unchanged. Once one is picked, trim the font list to a few.
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
