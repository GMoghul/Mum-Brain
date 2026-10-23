# Notes for Claude working on Mum Brain, Sorted

## Brand pack — keep it up to date
A general "for everyone" mode may be added later, so on the `app-store` branch all Mum Brain–specific
text lives in the `BRAND` block at the top of the script in `index.html`. The block holds:
- the app name and short name
- the slogan
- the feedback question
- the backup file name
- example jobs/projects
- the default theme

When making any change:
- Any new text mentioning mums, the app's name or a mum-style example goes into `BRAND` and is
  referenced from there. Never type it directly into the app.
- When merging `main` into `app-store`, check the incoming changes for new mum/app-name wording
  and move it into `BRAND`.
- Never put the storage key, Firebase config or the family-sharing encryption salts in `BRAND`.
  Every edition must keep them identical so lists, backups and sharing work across editions.
