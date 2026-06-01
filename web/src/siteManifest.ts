import { getLandingPageAssetUrl, siteContent, withSiteBase } from "./siteContent";

export function createSiteWebManifest(basePath = "/") {
  return {
    name: siteContent.productName,
    short_name: siteContent.productName,
    description: "Native, local-first macOS agentic development workflows.",
    start_url: withSiteBase("/", basePath),
    scope: withSiteBase("/", basePath),
    display: "standalone",
    background_color: "#f7f4ef",
    theme_color: "#201f1c",
    icons: [
      {
        src: getLandingPageAssetUrl("favicon", basePath),
        sizes: "512x512",
        type: "image/png"
      }
    ]
  };
}
