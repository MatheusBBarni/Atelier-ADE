import { describe, expect, it } from "vitest";

import { DEFAULT_PAGES_BASE } from "../../src/config/siteConfig.mjs";
import { createSiteWebManifest } from "../../src/siteManifest.ts";

describe("site web manifest", () => {
  it("uses the default GitHub Pages base for launch scope and icon paths", () => {
    expect(createSiteWebManifest(DEFAULT_PAGES_BASE)).toMatchObject({
      start_url: "/Atelier-ADE/",
      scope: "/Atelier-ADE/",
      icons: [
        {
          src: "/Atelier-ADE/favicon.png",
          sizes: "512x512",
          type: "image/png"
        }
      ]
    });
  });

  it("uses root and custom base paths without hardcoding the repository path", () => {
    expect(createSiteWebManifest("/")).toMatchObject({
      start_url: "/",
      scope: "/",
      icons: [{ src: "/favicon.png" }]
    });

    expect(createSiteWebManifest("/preview-site/")).toMatchObject({
      start_url: "/preview-site/",
      scope: "/preview-site/",
      icons: [{ src: "/preview-site/favicon.png" }]
    });
  });
});
