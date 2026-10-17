# App Store listing – Mum Brain, Sorted

Ready to copy into App Store Connect once Apple approves the developer account.
Character limits are Apple's; every field below has been counted.

## Basics
| Field | Text | Limit |
|---|---|---|
| App name | Mum Brain, Sorted | 17 / 30 |
| Subtitle | Brain dump to-do list for mums | 30 / 30 |
| Primary category | Productivity | |
| Secondary category | Lifestyle | |
| Age rating | 4+ (answer "None" to every content question) | |
| Price | Free (for testing) | |
| Privacy policy URL | https://gmoghul.github.io/Mum-Brain/privacy.html | |
| Support URL | https://gmoghul.github.io/Mum-Brain/privacy.html#help | |

The slogan "Out of your head. Into your day." is 32 characters, two over the subtitle limit, so it opens the promotional text instead.

## Promotional text (133 / 170)
Can be changed at any time without a new app version.

> Out of your head. Into your day. Get every job out of your head first, then give it a day when you're ready. Made by a mum, for mums.

## Keywords (97 / 100)
Commas, no spaces. Words already in the name or subtitle (mum, brain, dump, sorted, to-do) are left out, as Apple counts those anyway.

```
to do list,planner,organiser,family,shared list,reminders,checklist,daily tasks,mom,routine,mummy
```

## Description

> Out of your head. Into your day.
>
> Mum Brain is a to-do list built around the way a busy mum's mind actually works: everything arrives at once, at the worst possible moment. So instead of making you decide when and where every job goes, Mum Brain gives you a brain dump.
>
> BRAIN DUMP FIRST
> • Get every job out of your head in seconds, with no date needed
> • Type "Dentist Fri 3pm" and it lands on the right day automatically
> • A gentle morning card suggests 3 brain dump jobs to give a day
>
> PLAN YOUR DAYS
> • Today, Week and Month views, with jobs packed close so you see the whole list at once
> • Hold and drag jobs between days
> • Repeating jobs: daily, weekly, fortnightly, monthly or on the days you pick
> • Alarms that arrive even when the app is closed
> • A morning summary of the day's jobs, at a time you choose
>
> SHARE WITH YOUR FAMILY
> • A shared family list everyone can add to and tick off
> • Shared jobs are encrypted on your phone, so nobody else can read them, not even the app's maker
>
> PROJECTS FOR BIGGER JOBS
> • Trip prep, a house move or a room makeover, with dates, subtasks and a progress bar
> • Archive a project and bring it back next time
>
> MAKE IT YOURS
> • Calm themes, fonts, text sizes and spacing
> • Lists and colour tags to group your jobs
> • A little celebration when you clear your day
>
> PRIVATE BY DESIGN
> No accounts, no adverts, no tracking. Your own jobs stay on your phone.
>
> Made by a mum, for mums, and shaped by feedback from mums testing it. Tell us what you think from Settings › Feedback.

Before submitting, check every feature listed is in the build you send. The home-screen widget is deliberately left out until it's built.

## TestFlight "What to test" (for the testing mums)

> Thank you for testing Mum Brain as a real app!
>
> New in this version:
> • Alarms now arrive even when the app is closed. Tap "Allow" when it asks about notifications.
> • A morning summary of your day's jobs, at 9am by default. Change the time or turn it off in Settings › Morning summary.
> • Your jobs are now kept safely on your phone, so they won't be cleared if you don't open the app for a while.
>
> Please try:
> 1. Add a job for later today with an alarm, close the app and check the alarm arrives.
> 2. Check tomorrow's morning summary shows the right jobs.
> 3. Bring your jobs across from the web version: save a backup there (Settings › Backup), then restore it here.
>
> Tell me what's confusing, annoying or missing, in the group chat or Settings › Feedback.

## App Privacy answers (App Store Connect › App Privacy)
These match privacy.html. Apple calls something "collected" when it leaves the phone and is kept.

- **Do you or your partners collect data?** Yes
- **Other User Content** (shared family list jobs, stored encrypted)
  - Used for: App Functionality
  - Linked to the user's identity: No
  - Used for tracking: No
- **Other User Content** (feedback form answers) – also tick **Name** if keeping the optional name box
  - Used for: Other Purposes (improving the app)
  - Linked to the user's identity: No
  - Used for tracking: No
- Not collected: contact info, location, health, financial, browsing history, identifiers, usage data, diagnostics (unless analytics are added later).

## Export compliance (encryption)
Shared lists use standard encryption (AES-GCM) built into iPhone, used only to keep the user's own data private. When App Store Connect asks:
- "Does your app use encryption?" Yes
- "Does it qualify for any exemptions?" Yes – it only uses standard encryption built into the operating system for protecting user data.

This normally means no extra paperwork. Adding `ITSAppUsesNonExemptEncryption = NO` to the app's settings later stops Apple asking on every upload.

## Screenshots (to do once the app is on your phone)
Apple needs at least one set at 6.9-inch iPhone size (1320 × 2868). Suggested five, each with a one-line caption:
1. Brain dump – "Get it out of your head"
2. Today – "See your whole day at a glance"
3. Week – "Drag jobs to another day"
4. Family list – "Share jobs with your family"
5. Morning summary notification – "Start the day knowing what's on"
