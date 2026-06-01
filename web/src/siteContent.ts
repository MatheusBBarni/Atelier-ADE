export const CANONICAL_PRODUCT_NAME = "Atelier";

const ASTRO_ASSET_PREFIX = "/_astro";

type AssetOwner = "web/src/assets" | "web/public";

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

export const siteContent = {
  productName: CANONICAL_PRODUCT_NAME,
  assets: landingPageAssets
} as const;

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
