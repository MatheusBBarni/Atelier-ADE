# Landing Page Asset Ownership

The landing page owns only the MVP public-site copies it needs.

- `web/src/assets/` contains Astro-managed page assets imported by routes, currently `atelier-app-screenshot.png` and `atelier-logo.png`.
- `web/public/` contains fixed-path public metadata for GitHub Pages and site identity, currently `favicon.png`, `robots.txt`, and `.nojekyll`.
- `web/src/pages/site.webmanifest.ts` generates `site.webmanifest` so launch and icon paths use the configured Astro base.
- `docs/images/app-image.png` and `docs/images/atelier-logo.png` remain documentation assets and source references. The README screenshot path stays `docs/images/app-image.png`.
- `Sources/NativeMacADE/Resources/` remains Swift app-owned. Do not use `AppIcon.png` or bundled app icon resources as landing-page inputs.
