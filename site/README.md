# Local marketing-site preview

From the project root:

```bash
python3 -m http.server 4173 --directory site
```

Then open `http://localhost:4173`.

The page is intentionally static and dependency-free. It contains no checkout,
email capture, analytics, or deployment configuration.

Run the deterministic release-readiness check from the project root:

```bash
node scripts/check-site.mjs
```

`release.json` is deliberately fail-closed. A binary URL is rejected until all
four trust gates pass and the release has a checksum and support URL.
