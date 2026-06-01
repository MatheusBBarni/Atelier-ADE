# Landing Page Asset Ownership

The landing page owns only the public-site copies it needs.

- `web/src/assets/` contains Astro-managed page assets imported by routes:
  - `atelier-app-screenshot.png` from `docs/images/app-image.png`
  - `atelier-app-focus-and-appearance.png` from `docs/images/app-focus-and-appearance.png`
  - `atelier-app-focus-workspace.png` from `docs/images/app-focus-workspace.png`
  - `atelier-app-settings-agent-profiles.png` from `docs/images/app-settings-agent-profiles.png`
  - `atelier-app-settings-keyboard-shortcuts.png` from `docs/images/app-settings-keyboard-shortcuts.png`
  - `atelier-logo.png` from `docs/images/atelier-logo.png`
- `web/public/` contains fixed-path public metadata for GitHub Pages and site identity, currently `favicon.png`, `robots.txt`, and `.nojekyll`.
- `web/src/pages/site.webmanifest.ts` generates `site.webmanifest` so launch and icon paths use the configured Astro base.
- The `docs/images/` files remain documentation assets and source references. The README screenshot path stays `docs/images/app-image.png`.
- `Sources/NativeMacADE/Resources/` remains Swift app-owned. Do not use `AppIcon.png` or bundled app icon resources as landing-page inputs.
