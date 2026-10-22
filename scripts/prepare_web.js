// Copies the payment return pages and legal pages next to the Flutter web app
// before `firebase deploy --only hosting`. Run `flutter build web` first.
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const out = path.join(root, "build", "web");
if (!fs.existsSync(path.join(out, "index.html"))) {
  console.error("\n  build/web is missing. Run:  flutter build web --release\n");
  process.exit(1);
}
for (const item of ["legal", "payment", "logo.png"]) {
  const src = path.join(root, "hosting", item);
  if (fs.existsSync(src)) fs.cpSync(src, path.join(out, item), { recursive: true });
}
console.log("Web app ready in build/web (with legal and payment pages).");
