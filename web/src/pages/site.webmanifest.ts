import { getAstroSiteConfig } from "../config/siteConfig.mjs";
import { createSiteWebManifest } from "../siteManifest";

export const prerender = true;

export function GET() {
  const { base } = getAstroSiteConfig();

  return new Response(`${JSON.stringify(createSiteWebManifest(base), null, 2)}\n`, {
    headers: {
      "Content-Type": "application/manifest+json; charset=utf-8"
    }
  });
}
