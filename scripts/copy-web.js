// Copies the web app (the same files GitHub Pages serves) into www/,
// which is the folder the phone app is built from.
// The live web app stays exactly where it is, so the testing mums aren't affected.
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const out = path.join(root, 'www');
const files = ['index.html', 'manifest.json', 'sw.js', 'icon-180.png', 'icon-192.png', 'icon-512.png'];

fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out, { recursive: true });
for (const f of files) {
  fs.copyFileSync(path.join(root, f), path.join(out, f));
}
console.log(`Copied ${files.length} files into www/`);
