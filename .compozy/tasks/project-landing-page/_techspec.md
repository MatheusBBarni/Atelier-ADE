# Project Landing Page

## Executive Summary

This TechSpec implements the Project Landing Page as a small Astro site in a new top-level `web/` directory, published through GitHub Pages. The site stays static by default, keeps the repository as the primary call to action, and uses a single progressive-enhancement client-side fetch to show live GitHub star count on the repo button.

The primary technical trade-off is deliberate: Astro gives the project a maintainable static-site workflow and room to grow, but it introduces the repo’s first web toolchain and a small amount of browser-side runtime behavior. The design keeps that cost bounded by isolating the site in `web/`, avoiding a backend, avoiding analytics tooling, and treating the star count as non-blocking enhancement rather than core page functionality.

## System Architecture

### Component Overview

- **Astro site shell (`web/`)**  
  Owns the landing page build, route structure, metadata, and styling. It is isolated from the SwiftPM application and contains only the files needed to build and deploy the site.

- **Single landing page route (`web/src/pages/index.astro`)**  
  Renders the full MVP page: hero, screenshot, capability summary, trust cues, repo CTA, and secondary docs/quickstart links. It should remain the only route in MVP.

- **Site content module (`web/src/siteContent.ts`)**  
  Holds the canonical public product name, CTA destinations, section copy, and capability lists. This keeps naming and public text centralized without introducing a CMS or markdown pipeline.

- **Repo CTA enhancement (`web/src/components/RepoStarCTA.astro` + inline or colocated client script)**  
  Renders the primary GitHub CTA with a stable fallback label, then fetches public GitHub repository metadata in the browser and updates the star count if available.

- **Static assets (`web/src/assets/` and `web/public/`)**  
  Hold the copied or normalized screenshot, logo, favicon, and other fixed public assets. Use `src/assets/` for Astro-managed images and `public/` only for fixed-path files such as `favicon`, `robots.txt`, or `CNAME`.

- **Pages deployment workflow (`.github/workflows/deploy-pages.yml`)**  
  Builds the Astro site from `web/`, publishes the generated `dist/` artifact to GitHub Pages, and becomes the only deployment path for the landing page.

### Data Flow

1. Developers update landing-page copy and links in `web/src/siteContent.ts` and page markup in `web/src/pages/index.astro`.
2. Astro builds the site into static output in `web/dist/`.
3. GitHub Actions publishes the built artifact to GitHub Pages.
4. A visitor loads pre-rendered HTML/CSS/assets from Pages.
5. The repo CTA renders immediately with a working GitHub link.
6. A small client script requests public GitHub repository metadata and, if successful, updates the button label with live star count.

### External System Interactions

- **GitHub Pages** serves the built static site.
- **GitHub REST API** provides public repository metadata for the star CTA.
- **GitHub repository** remains the primary downstream destination for qualified visitors.

## Implementation Design

### Core Interfaces

The MVP has one primary runtime contract: the repo CTA state that the page renders before and after GitHub metadata loads. The Astro implementation should mirror this shape in TypeScript even though the contract is shown here in compact struct form.

```go
type RepoCTAState struct {
    Href       string
    Label      string
    Stars      int
    Loading    bool
    Fallback   bool
    ErrorCode  string
}
```

A matching TypeScript shape should back the Astro component state used by the CTA enhancement script.

### Data Models

- **SiteContent**
  - `productName: string`
  - `tagline: string`
  - `repoUrl: string`
  - `docsUrl: string`
  - `quickstartUrl: string`
  - `heroBullets: string[]`
  - `capabilities: CapabilityItem[]`
  - `trustNotes: string[]`
  - `statusNote?: string`

- **CapabilityItem**
  - `title: string`
  - `description: string`
  - `priority: 'critical' | 'high' | 'medium'`

- **GitHubRepoResponse**
  - `stargazers_count: number`
  - `html_url: string`
  - `name: string`
  - `owner.login: string`

- **RepoCTAState**
  - `href: string`
  - `label: string`
  - `stars?: number`
  - `loading: boolean`
  - `fallback: boolean`
  - `errorCode?: 'rate_limited' | 'network' | 'invalid_response'`

- **Storage**
  - No database
  - No server-side persistence
  - No local storage required for MVP

### API Endpoints

#### Project-owned endpoints

MVP introduces **no project-owned API endpoints**.

#### Consumed external endpoint

| Method | Endpoint | Purpose | Required Fields | Success | Failure Handling |
|---|---|---|---|---|---|
| GET | `https://api.github.com/repos/{owner}/{repo}` | Fetch public repo metadata for the star CTA | none | `200` with `stargazers_count` and `html_url` | On `403/429/5xx/network failure`, keep fallback CTA label and preserve navigation |

## Integration Points

- **GitHub Pages**
  - **Purpose:** host the static site
  - **Auth/AuthZ:** GitHub Actions artifact deploy using repo permissions
  - **Error handling:** fail CI job and keep previous live site unchanged when build or deploy fails

- **GitHub REST API**
  - **Purpose:** provide live public star count for the repo CTA
  - **Auth/AuthZ:** no token in browser code; use only public unauthenticated endpoint for MVP
  - **Error handling:** treat the fetch as optional enhancement; fall back to static CTA text without blocking page interaction
  - **Retry strategy:** no aggressive retry loop; a single request per page load is enough for MVP

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
|-----------|-------------|---------------------|-----------------|
| `web/` Astro project | new | Adds the repo’s first web toolchain; low-to-medium integration risk | Create minimal Astro app with one route and limited client code |
| `web/src/pages/index.astro` | new | Owns all MVP page rendering; low risk if kept single-page | Implement hero, screenshot, capabilities, trust cues, and CTA layout |
| `web/src/siteContent.ts` | new | Centralizes public copy and links; low risk | Define canonical public text and link constants |
| `web/src/components/RepoStarCTA.astro` | new | Small runtime enhancement depends on GitHub API; medium risk | Implement resilient fallback-first CTA behavior |
| `web/src/assets/` / `web/public/` | new/modified | Asset duplication or drift may occur; low risk | Normalize screenshot/logo ownership for the site |
| `.github/workflows/deploy-pages.yml` | new | New CI/CD path for web deploys; medium risk | Add build and GitHub Pages deployment workflow |
| `README.md` | modified | Public naming and CTA alignment can drift; medium risk | Update links and wording to align with landing page and chosen public name |
| GitHub repo settings | modified | Pages source and permissions must be correct; medium risk | Set Pages source to GitHub Actions and verify publish permissions |

## Testing Approach

### Unit Tests

- Keep unit tests minimal for MVP.
- Test only logic that benefits from isolation:
  - repo-star response parsing
  - CTA label formatting
  - fallback-state selection when GitHub data is unavailable
- If the CTA logic stays inline and trivial, prefer extracting a tiny helper rather than introducing a broad test harness.
- Mock only the GitHub metadata response shape and failure modes.

### Integration Tests

- **Required baseline**
  - `astro build` succeeds from `web/`
  - generated output contains valid internal links
  - no-JavaScript fallback CTA still links correctly to GitHub
  - a basic accessibility smoke pass confirms heading order, image alt text, and interactive label clarity

- **Environment dependencies**
  - Node LTS available in CI
  - GitHub Pages deployment job permissions configured
  - stable Pages base URL and repository path available in Astro config

- **Explicitly deferred**
  - full browser E2E suite
  - visual regression platform
  - analytics instrumentation validation

## Development Sequencing

### Build Order

1. **Scaffold the Astro site in `web/`** — no dependencies  
   Create Astro config, package metadata, one page route, and the minimum build scripts.

2. **Configure Pages-aware site settings** — depends on step 1  
   Set the site URL, Pages base path, static output behavior, and build conventions needed for GitHub Pages.

3. **Add site content and page structure** — depends on steps 1 and 2  
   Implement `siteContent.ts`, page markup, screenshot usage, trust sections, and secondary links.

4. **Implement the repo CTA enhancement** — depends on step 3  
   Add the fallback-first CTA plus the client-side GitHub metadata fetch and label update.

5. **Normalize assets and public metadata files** — depends on steps 2 and 3  
   Place screenshot/logo/favicons in the correct Astro-managed or fixed-path locations.

6. **Add deployment workflow and validation checks** — depends on steps 1 through 5  
   Create the GitHub Pages workflow, wire the build job to `web/`, and run build/link/basic accessibility checks in CI.

7. **Align repository entry points** — depends on steps 3 and 6  
   Update `README.md` and related public references so the landing page, repo links, and public naming stay consistent.

### Technical Dependencies

- GitHub Pages must be configured to publish from GitHub Actions.
- The final public site URL and base path must be known before final Astro config is locked.
- The canonical public product name must be settled before final copy and metadata are frozen.
- The repository’s open-source/license messaging must be stable enough to present honestly on the page.
- GitHub public API rate limits must be accepted as a runtime constraint for the star enhancement.

## Monitoring and Observability

- **Build/deploy metrics**
  - Astro build success/failure
  - GitHub Pages deploy success/failure
  - broken-link check failures
  - accessibility smoke failures

- **Runtime visibility**
  - No first-party analytics in MVP
  - No server-side logs because there is no backend
  - GitHub repository traffic/referrer data and star movement act as the primary downstream signals

- **Operational logging**
  - CI logs capture build and deploy failures
  - Local development console may log CTA fetch failures, but production should fail quietly into fallback UI

- **Alerting**
  - GitHub Actions failure notifications are the only required alerting path for MVP
  - No runtime alerting is required because the page remains functional when the star fetch fails

## Technical Considerations

### Key Decisions

- **Decision:** Introduce Astro in a new top-level `web/` directory  
  **Rationale:** Keeps site tooling isolated from SwiftPM app code while enabling a structured static-site workflow.  
  **Trade-offs:** Adds a new web toolchain to a previously Swift-only repo.  
  **Alternatives rejected:** plain static HTML/CSS and Astro under `docs/`.

- **Decision:** Deploy with GitHub Pages through Actions  
  **Rationale:** Matches a static-site MVP and avoids custom hosting infrastructure.  
  **Trade-offs:** Adds another CI workflow and requires correct Pages configuration.  
  **Alternatives rejected:** repo-only landing assets with no live site.

- **Decision:** Keep the repo CTA as progressive enhancement with client-side star fetch  
  **Rationale:** Supports the repo-first PRD while keeping the page functional without a backend.  
  **Trade-offs:** Accepts browser-side rate limits and one small runtime dependency.  
  **Alternatives rejected:** build-time star fetch and analytics-first measurement.

- **Decision:** Keep content centralized in a small code module instead of markdown or CMS infrastructure  
  **Rationale:** The MVP is one page with a stable copy surface; a code module is the smallest editable abstraction.  
  **Trade-offs:** Content edits require code changes.  
  **Alternatives rejected:** markdown-driven generation and fragmented partials.

- **Decision:** Treat page-level metrics as mostly non-instrumented in MVP  
  **Rationale:** Matches the trust-first posture and user preference for GitHub-native signals.  
  **Trade-offs:** Some PRD success metrics can only be validated qualitatively or via GitHub-side data until analytics are added later.  
  **Alternatives rejected:** adding privacy-light analytics in MVP.

### Known Risks

- **Metrics mismatch with PRD targets**  
  Some PRD metrics, such as bounce and section engagement, are not directly measurable without analytics.  
  **Mitigation:** validate MVP success primarily with repo traffic/referrals, user testing, and build/deploy health; defer richer telemetry to a later phase if needed.

- **CTA posture drift across ADRs and public copy**  
  Earlier artifacts describe docs-first posture while later PRD decisions move to repo-first.  
  **Mitigation:** implementation follows ADR-002 and newer technical ADRs where CTA priority differs.

- **GitHub API rate limiting or outage**  
  The star count can fail to load or be rate-limited in the browser.  
  **Mitigation:** design the CTA as progressive enhancement with a static label and working link.

- **Name and license ambiguity weaken trust more than implementation details**  
  The page can ship technically sound code but still confuse users if public naming and status remain unresolved.  
  **Mitigation:** centralize public name in `siteContent.ts` and block final copy freeze until name/status text is agreed.

- **Web scope creep**  
  Astro can make it tempting to add routes, MDX, content collections, or richer interactivity too early.  
  **Mitigation:** lock MVP to one page, one enhancement, and the minimum deploy pipeline.

## Architecture Decision Records

- [ADR-001: Docs-First Trailhead Landing Page Scope for V1](adrs/adr-001.md) — Establishes the original minimal trailhead direction and rejects a glossy install-first marketing site.
- [ADR-002: Trust-First Repo-Oriented Landing Page PRD Scope](adrs/adr-002.md) — Refines the MVP toward trust-first messaging, screenshot-led proof, and a repo-first CTA.
- [ADR-003: Implement the Landing Page as an Astro Site in /web with GitHub Pages Deployment](adrs/adr-003.md) — Chooses Astro in a dedicated `web/` folder and Pages-based static deployment.
- [ADR-004: Use a Client-Side GitHub Star CTA Instead of Site Analytics or Build-Time GitHub Metadata](adrs/adr-004.md) — Chooses a progressive-enhancement repo CTA with live GitHub stars and no first-party analytics.
