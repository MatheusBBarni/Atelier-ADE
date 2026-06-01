import { describe, expect, it } from "vitest";

import {
  CANONICAL_PRODUCT_NAME,
  DOCS_URL,
  LANDING_PAGE_URL,
  QUICKSTART_URL,
  REPOSITORY_URL,
  getOrderedCtas,
  getLandingPageAsset,
  getLandingPageAssetUrl,
  getPrimaryCta,
  getSecondaryEvaluationLinks,
  landingPageCtas,
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

describe("public landing page content", () => {
  it("exports the canonical product name and evaluation URLs used by the page", () => {
    expect(siteContent.productName).toBe("Atelier");
    expect(siteContent.productName).toBe(CANONICAL_PRODUCT_NAME);
    expect(siteContent.repoUrl).toBe(REPOSITORY_URL);
    expect(siteContent.docsUrl).toBe(DOCS_URL);
    expect(siteContent.quickstartUrl).toBe(QUICKSTART_URL);
    expect(siteContent.landingPageUrl).toBe(LANDING_PAGE_URL);
    expect(LANDING_PAGE_URL).toBe("https://matheusbbarni.github.io/Atelier-ADE/");
    expect(REPOSITORY_URL).toBe("https://github.com/MatheusBBarni/Atelier-ADE");
    expect(DOCS_URL).toBe(`${REPOSITORY_URL}#readme`);
    expect(QUICKSTART_URL).toBe(`${REPOSITORY_URL}#build-test-and-run`);
  });

  it("includes renderable hero, proof, capability, and trust data for the MVP route", () => {
    expect(siteContent.hero).toMatchObject({
      eyebrow: "Native macOS agent workspace",
      title: "Atelier"
    });
    expect(siteContent.hero.summary).toMatch(/coding agents/i);
    expect(siteContent.hero.bullets).toHaveLength(3);
    expect(siteContent.proof.title).toMatch(/real workspace/i);
    expect(siteContent.proof.caption).toMatch(/Current Atelier macOS workspace/);

    expect(siteContent.capabilities.map((capability) => capability.title)).toEqual(
      expect.arrayContaining([
        "Persistent projects",
        "Project-scoped sessions",
        "Native terminal tabs",
        "Restore and resume"
      ])
    );
    expect(siteContent.capabilities.every((capability) => capability.description.length > 40)).toBe(
      true
    );
    expect(siteContent.trustNotes).toHaveLength(3);
    expect(siteContent.trustNotes.map((note) => note.title)).toEqual(
      expect.arrayContaining([
        "Source-visible surface",
        "Honest maturity",
        "No hidden conversion layer"
      ])
    );
  });

  it("preserves repo-first CTA priority for route rendering and future star enhancement", () => {
    const intentionallyUnordered = [...landingPageCtas].reverse();
    const orderedCtas = getOrderedCtas(intentionallyUnordered);

    expect(orderedCtas.map((link) => link.kind)).toEqual(["repo", "docs", "quickstart"]);
    expect(orderedCtas[0]).toMatchObject({
      kind: "repo",
      priority: "primary",
      href: REPOSITORY_URL,
      label: "Open the repository"
    });
    expect(getPrimaryCta()?.kind).toBe("repo");
    expect(getSecondaryEvaluationLinks().map((link) => link.kind)).toEqual(["docs", "quickstart"]);
  });

  it("keeps public copy on the Atelier name instead of internal package names", () => {
    const publicContent = JSON.stringify({
      hero: siteContent.hero,
      proof: siteContent.proof,
      capabilities: siteContent.capabilities,
      trustNotes: siteContent.trustNotes,
      ctas: siteContent.ctas,
      statusNote: siteContent.statusNote,
      metaDescription: siteContent.metaDescription
    });

    expect(publicContent).toContain("Atelier");
    expect(publicContent).not.toMatch(/NativeMacADE/);
  });
});
