import {
  DEFAULT_PAGES_BASE,
  DEFAULT_SITE_ORIGIN,
  REPOSITORY_URL as CONFIG_REPOSITORY_URL
} from "./config/repository.mjs";

export const CANONICAL_PRODUCT_NAME = "Atelier";
export const REPOSITORY_URL = CONFIG_REPOSITORY_URL;
export const DOCS_URL = `${REPOSITORY_URL}#readme`;
export const QUICKSTART_URL = `${REPOSITORY_URL}#build-test-and-run`;
export const LANDING_PAGE_URL = `${DEFAULT_SITE_ORIGIN}${DEFAULT_PAGES_BASE}/`;

const ASTRO_ASSET_PREFIX = "/_astro";

type AssetOwner = "web/src/assets" | "web/public";
type CapabilityPriority = "critical" | "high" | "medium";
type CtaKind = "repo" | "docs" | "quickstart";
type CtaPriority = "primary" | "secondary";

type AstroManagedAsset = {
  kind: "astro-managed";
  owner: Extract<AssetOwner, "web/src/assets">;
  fileName: string;
  importPath: string;
  sourcePath: string;
  alt: string;
  expectedPublicPathPrefix: string;
};

type FixedPublicAsset = {
  kind: "fixed-public";
  owner: Extract<AssetOwner, "web/public">;
  fileName: string;
  publicPath: `/${string}`;
  sourcePath?: string;
  label: string;
};

type LandingPageAsset = AstroManagedAsset | FixedPublicAsset;

type CapabilityItem = {
  title: string;
  description: string;
  priority: CapabilityPriority;
};

type TrustNote = {
  title: string;
  description: string;
};

type LandingPageLink = {
  kind: CtaKind;
  label: string;
  href: string;
  description: string;
  priority: CtaPriority;
  order: number;
  ariaLabel: string;
};

type SiteContent = {
  productName: string;
  tagline: string;
  metaDescription: string;
  repoUrl: string;
  docsUrl: string;
  quickstartUrl: string;
  landingPageUrl: string;
  statusNote: string;
  hero: {
    eyebrow: string;
    title: string;
    summary: string;
    bullets: readonly string[];
  };
  proof: {
    eyebrow: string;
    title: string;
    description: string;
    caption: string;
  };
  capabilities: readonly CapabilityItem[];
  trustNotes: readonly TrustNote[];
  ctas: readonly LandingPageLink[];
  assets: typeof landingPageAssets;
};

export const landingPageAssets = {
  screenshot: {
    kind: "astro-managed",
    owner: "web/src/assets",
    fileName: "atelier-app-screenshot.png",
    importPath: "src/assets/atelier-app-screenshot.png",
    sourcePath: "docs/images/app-image.png",
    alt: `${CANONICAL_PRODUCT_NAME} macOS app screenshot`,
    expectedPublicPathPrefix: `${ASTRO_ASSET_PREFIX}/atelier-app-screenshot`
  },
  logo: {
    kind: "astro-managed",
    owner: "web/src/assets",
    fileName: "atelier-logo.png",
    importPath: "src/assets/atelier-logo.png",
    sourcePath: "docs/images/atelier-logo.png",
    alt: `${CANONICAL_PRODUCT_NAME} logo`,
    expectedPublicPathPrefix: `${ASTRO_ASSET_PREFIX}/atelier-logo`
  },
  favicon: {
    kind: "fixed-public",
    owner: "web/public",
    fileName: "favicon.png",
    publicPath: "/favicon.png",
    sourcePath: "docs/images/atelier-logo.png",
    label: `${CANONICAL_PRODUCT_NAME} favicon`
  },
  manifest: {
    kind: "fixed-public",
    owner: "web/public",
    fileName: "site.webmanifest",
    publicPath: "/site.webmanifest",
    label: `${CANONICAL_PRODUCT_NAME} web manifest`
  },
  robots: {
    kind: "fixed-public",
    owner: "web/public",
    fileName: "robots.txt",
    publicPath: "/robots.txt",
    label: `${CANONICAL_PRODUCT_NAME} robots metadata`
  },
  nojekyll: {
    kind: "fixed-public",
    owner: "web/public",
    fileName: ".nojekyll",
    publicPath: "/.nojekyll",
    label: `${CANONICAL_PRODUCT_NAME} GitHub Pages metadata`
  }
} as const satisfies Record<string, LandingPageAsset>;

export type LandingPageAssetKey = keyof typeof landingPageAssets;

export const landingPageCtas = [
  {
    kind: "repo",
    label: "Open the repository",
    href: REPOSITORY_URL,
    description: "Inspect the source, current status, and project reality directly on GitHub.",
    priority: "primary",
    order: 0,
    ariaLabel: "Open the Atelier GitHub repository"
  },
  {
    kind: "docs",
    label: "Read the README",
    href: DOCS_URL,
    description: "Start with the public project overview and current capability notes.",
    priority: "secondary",
    order: 1,
    ariaLabel: "Read the Atelier README"
  },
  {
    kind: "quickstart",
    label: "Build and run",
    href: QUICKSTART_URL,
    description: "Use the current source-build commands for local evaluation on macOS.",
    priority: "secondary",
    order: 2,
    ariaLabel: "Open the Atelier build and run instructions"
  }
] as const satisfies readonly LandingPageLink[];

export const siteContent = {
  productName: CANONICAL_PRODUCT_NAME,
  tagline: "A native, local-first macOS workspace for agentic development.",
  metaDescription:
    "Atelier is an early macOS app for developers who want native, local-first agentic workflows with inspectable project and session state.",
  repoUrl: REPOSITORY_URL,
  docsUrl: DOCS_URL,
  quickstartUrl: QUICKSTART_URL,
  landingPageUrl: LANDING_PAGE_URL,
  statusNote: "Early, usable, and source-build-first.",
  hero: {
    eyebrow: "Native macOS agent workspace",
    title: CANONICAL_PRODUCT_NAME,
    summary:
      "Work with coding agents in a Mac app that keeps projects, sessions, tabs, and state visible on your machine instead of hiding them behind a browser shell.",
    bullets: [
      "Native windowing and macOS-first ergonomics",
      "Project-scoped sessions with terminal tabs that stay together",
      "Local workspace state you can inspect, restore, and resume"
    ]
  },
  proof: {
    eyebrow: "Product proof",
    title: "A real workspace, not an abstract promise.",
    description:
      "The current app keeps persistent projects in a sidebar, groups related work into sessions, opens terminal tabs in a native window, and restores the workspace when you relaunch.",
    caption:
      "Current Atelier macOS workspace with project navigation, session context, terminal tabs, and restore-oriented state."
  },
  capabilities: [
    {
      title: "Persistent projects",
      description:
        "Pin active repositories in a project sidebar so the app opens around the work you actually return to.",
      priority: "critical"
    },
    {
      title: "Project-scoped sessions",
      description:
        "Group related terminal tabs under sessions so a task can keep its context instead of dissolving into loose shells.",
      priority: "critical"
    },
    {
      title: "Native terminal tabs",
      description:
        "Run plain shell tabs and agent-oriented session starts inside a macOS window built for the workflow.",
      priority: "high"
    },
    {
      title: "Restore and resume",
      description:
        "Come back later without rebuilding the workspace from memory; Atelier restores projects, sessions, and tabs.",
      priority: "high"
    },
    {
      title: "Inspectable local posture",
      description:
        "The source, current constraints, and build path stay visible so early adopters can evaluate the product directly.",
      priority: "medium"
    }
  ],
  trustNotes: [
    {
      title: "Source-visible surface",
      description:
        "The repository is the primary evaluation path because the product is early and benefits from direct source inspection."
    },
    {
      title: "Honest maturity",
      description:
        "Atelier is usable today, but still source-build-first while richer onboarding and release packaging mature."
    },
    {
      title: "No hidden conversion layer",
      description:
        "The page points to source, README context, and build commands instead of lead capture or opaque claims."
    }
  ],
  ctas: landingPageCtas,
  assets: landingPageAssets
} as const satisfies SiteContent;

export function getOrderedCtas(links: readonly LandingPageLink[] = landingPageCtas) {
  return [...links].sort((first, second) => first.order - second.order);
}

export function getPrimaryCta(links: readonly LandingPageLink[] = landingPageCtas) {
  return getOrderedCtas(links).find((link) => link.priority === "primary");
}

export function getSecondaryEvaluationLinks(links: readonly LandingPageLink[] = landingPageCtas) {
  return getOrderedCtas(links).filter((link) => link.priority === "secondary");
}

export function getLandingPageAsset(assetKey: LandingPageAssetKey) {
  return landingPageAssets[assetKey];
}

export function withSiteBase(path: `/${string}`, basePath = "/") {
  const trimmedBase = basePath.replace(/^\/+|\/+$/g, "");
  const normalizedBase = trimmedBase ? `/${trimmedBase}` : "";

  return `${normalizedBase}${path}`;
}

export function getLandingPageAssetUrl(assetKey: LandingPageAssetKey, basePath = "/") {
  const asset = getLandingPageAsset(assetKey);
  const assetPath = asset.kind === "fixed-public" ? asset.publicPath : asset.expectedPublicPathPrefix;

  return withSiteBase(assetPath, basePath);
}
