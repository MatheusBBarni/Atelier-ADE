import { describe, expect, it } from "vitest";

import {
  CANONICAL_PRODUCT_NAME,
  getLandingPageAsset,
  getLandingPageAssetUrl,
  landingPageAssets,
  siteContent,
  withSiteBase
} from "../../src/siteContent.ts";

describe("landing page asset metadata", () => {
  it("resolves expected Pages-aware asset URL prefixes and fixed public paths", () => {
    expect(getLandingPageAssetUrl("screenshot", "/Atelier-ADE/")).toBe(
      "/Atelier-ADE/_astro/atelier-app-screenshot"
    );
    expect(getLandingPageAssetUrl("favicon", "/Atelier-ADE/")).toBe(
      "/Atelier-ADE/favicon.png"
    );
    expect(getLandingPageAssetUrl("manifest", "/")).toBe("/site.webmanifest");
    expect(withSiteBase("/robots.txt", "Atelier-ADE")).toBe("/Atelier-ADE/robots.txt");
  });

  it("keeps page-imported assets under web/src/assets and fixed public assets under web/public", () => {
    expect(getLandingPageAsset("screenshot")).toMatchObject({
      kind: "astro-managed",
      owner: "web/src/assets",
      importPath: "src/assets/atelier-app-screenshot.png",
      sourcePath: "docs/images/app-image.png"
    });
    expect(getLandingPageAsset("logo")).toMatchObject({
      kind: "astro-managed",
      owner: "web/src/assets",
      importPath: "src/assets/atelier-logo.png",
      sourcePath: "docs/images/atelier-logo.png"
    });
    expect(getLandingPageAsset("favicon")).toMatchObject({
      kind: "fixed-public",
      owner: "web/public",
      publicPath: "/favicon.png"
    });
  });

  it("does not select Swift app resource paths for landing page assets", () => {
    const serializedAssets = JSON.stringify(landingPageAssets);

    expect(serializedAssets).not.toMatch(/Sources\/NativeMacADE/);
    expect(serializedAssets).not.toMatch(/Resources\/AppIcon\.png/);
    expect(serializedAssets).not.toMatch(/AppIcon/);
  });

  it("derives public labels from the canonical Atelier product name", () => {
    const assetLabels = Object.values(landingPageAssets).map((asset) =>
      "alt" in asset ? asset.alt : asset.label
    );

    expect(siteContent.productName).toBe(CANONICAL_PRODUCT_NAME);
    expect(CANONICAL_PRODUCT_NAME).toBe("Atelier");
    expect(assetLabels.every((label) => label.includes(CANONICAL_PRODUCT_NAME))).toBe(true);
  });
});
