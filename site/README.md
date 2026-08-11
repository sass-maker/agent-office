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

## Manual production deployment

The Cloudflare Pages target is declared in `wrangler.jsonc`. After the Fleet
deploy guard passes on a clean, synchronized `main`, deploy the informational
site with:

```bash
./scripts/deploy-site.sh
```

The script pins Wrangler, attaches the exact Git commit to the deployment, and
never uploads a Mac application binary.
