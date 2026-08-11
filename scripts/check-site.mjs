import { access, readFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const site = resolve(root, "site");
const requiredFiles = [
  "index.html",
  "styles.css",
  "script.js",
  "release.json",
  "assets/favicon.svg",
  "assets/workplace.jpg",
  "assets/employees.png",
];

await Promise.all(requiredFiles.map((file) => access(resolve(site, file))));

const html = await readFile(resolve(site, "index.html"), "utf8");
const release = JSON.parse(await readFile(resolve(site, "release.json"), "utf8"));
const requiredCopy = [
  "macOS 14 or newer",
  "Local organization files",
  "Contact pending",
  "Privacy statement",
  "Distribution build in preparation",
];

for (const copy of requiredCopy) {
  if (!html.includes(copy)) throw new Error(`Missing required release copy: ${copy}`);
}

if (release.schema !== "fleet.mac-release.v1") throw new Error("Unsupported release schema");
if (!release.version || !release.build) throw new Error("Release version and build are required");

if (release.downloadUrl !== null) {
  const gates = Object.values(release.trust ?? {});
  if (gates.length !== 4 || gates.some((value) => value !== true)) {
    throw new Error("A download URL requires every trust gate to pass");
  }
  if (!/^[a-f0-9]{64}$/i.test(release.sha256 ?? "")) {
    throw new Error("A download URL requires a valid SHA-256 checksum");
  }
  if (!release.supportUrl) throw new Error("A download URL requires a support URL");
}

const binaryUrls = html.match(/https?:[^\s"']+\.(?:dmg|pkg|zip)/gi) ?? [];
if (binaryUrls.length > 0 && release.downloadUrl === null) {
  throw new Error("The page exposes a binary URL while release metadata is closed");
}

console.log("Office OS site check passed; binary distribution remains fail-closed.");
