import { defineConfig } from "astro/config";

import { getAstroSiteConfig } from "./src/config/siteConfig.mjs";

const pagesConfig = getAstroSiteConfig();

export default defineConfig({
  output: "static",
  site: pagesConfig.site,
  base: pagesConfig.base
});
