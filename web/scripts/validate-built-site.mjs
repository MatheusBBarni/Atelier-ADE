#!/usr/bin/env node

import { resolve } from "node:path";

import { REPOSITORY_URL, getAstroSiteConfig } from "../src/config/siteConfig.mjs";
import {
  checkBuiltSite,
  formatValidationReport,
  parseValidationCliArgs
} from "./validation/siteChecks.mjs";

const cliOptions = parseValidationCliArgs(process.argv.slice(2));
const pagesConfig = getAstroSiteConfig();
const distDir = resolve(process.cwd(), cliOptions.distDir);
const result = checkBuiltSite({
  distDir,
  basePath: cliOptions.basePath ?? pagesConfig.base,
  repoUrl: cliOptions.repoUrl ?? REPOSITORY_URL,
  checks: cliOptions.checks
});
const report = formatValidationReport(result);

if (report) {
  console.log(report);
}

if (!result.ok) {
  process.exitCode = 1;
}
