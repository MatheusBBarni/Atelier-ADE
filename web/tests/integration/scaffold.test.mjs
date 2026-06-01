import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { beforeAll, describe, expect, it } from "vitest";

import {
  CANONICAL_PRODUCT_NAME,
  getLandingPageAssetUrl,
  landingPageAssets
} from "../../src/siteContent.ts";

const webRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const repositoryRoot = resolve(webRoot, "..");
const indexPath = resolve(webRoot, "dist/index.html");
let buildOutput;

function run(command, args, cwd, timeout = 300_000) {
  return execFileSync(command, args, {
    cwd,
    env: {
      ...process.env,
      ASTRO_TELEMETRY_DISABLED: "1"
    },
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    timeout
  });
}

describe("Astro scaffold integration", () => {
  beforeAll(() => {
    buildOutput = run("npm", ["run", "build"], webRoot);
  });

  it("builds the static site and emits the index route", () => {
    expect(buildOutput).toContain("Complete");
    expect(existsSync(indexPath)).toBe(true);
    expect(readFileSync(indexPath, "utf8")).toContain("<h1");
  });

  it("keeps the Swift package buildable from the repository root", () => {
    expect(() => run("swift", ["build"], repositoryRoot)).not.toThrow();
  });

  it("keeps web tooling isolated from Swift and release automation surfaces", () => {
    const swiftPackage = readFileSync(resolve(repositoryRoot, "Package.swift"), "utf8");
    const runScript = readFileSync(resolve(repositoryRoot, "scripts/run.sh"), "utf8");
    const releaseWorkflow = readFileSync(
      resolve(repositoryRoot, ".github/workflows/release-build.yml"),
      "utf8"
    );

    expect(existsSync(resolve(repositoryRoot, "package.json"))).toBe(false);
    expect(swiftPackage).not.toMatch(/astro|npm|web\//i);
    expect(runScript).not.toMatch(/astro|npm|web\//i);
    expect(releaseWorkflow).not.toMatch(/astro|npm|web\//i);
    expect(existsSync(resolve(repositoryRoot, "Sources/NativeMacADE/Resources/AppIcon.png"))).toBe(
      true
    );
    expect(runScript).toContain("Sources/NativeMacADE/Resources/AppIcon.png");
  });

  it("resolves the copied MVP screenshot through the Astro-managed asset pipeline", () => {
    const indexHtml = readFileSync(indexPath, "utf8");
    const expectedScreenshotPrefix = getLandingPageAssetUrl("screenshot", "/Atelier-ADE");
    const screenshotMatch = indexHtml.match(/src="([^"]*atelier-app-screenshot[^"]*)"/);

    expect(indexHtml).toContain(`alt="${landingPageAssets.screenshot.alt}"`);
    expect(indexHtml).not.toContain("docs/images/app-image.png");
    expect(indexHtml).not.toContain("Sources/NativeMacADE");
    expect(screenshotMatch?.[1]).toContain(expectedScreenshotPrefix);

    const emittedPath = screenshotMatch?.[1].replace(/^\/Atelier-ADE\//, "");
    expect(emittedPath).toBeTruthy();
    expect(existsSync(resolve(webRoot, "dist", emittedPath))).toBe(true);
  });

  it("serves fixed public metadata files from web/public after build", () => {
    const indexHtml = readFileSync(indexPath, "utf8");
    const manifest = JSON.parse(readFileSync(resolve(webRoot, "dist/site.webmanifest"), "utf8"));

    expect(indexHtml).toContain(`href="${getLandingPageAssetUrl("favicon", "/Atelier-ADE")}"`);
    expect(indexHtml).toContain(`href="${getLandingPageAssetUrl("manifest", "/Atelier-ADE")}"`);
    expect(existsSync(resolve(webRoot, "dist/favicon.png"))).toBe(true);
    expect(existsSync(resolve(webRoot, "dist/robots.txt"))).toBe(true);
    expect(existsSync(resolve(webRoot, "dist/.nojekyll"))).toBe(true);
    expect(manifest.name).toBe(CANONICAL_PRODUCT_NAME);
    expect(manifest.short_name).toBe(CANONICAL_PRODUCT_NAME);
    expect(manifest.icons[0]).toMatchObject({
      src: "/Atelier-ADE/favicon.png",
      sizes: "512x512",
      type: "image/png"
    });
  });

  it("preserves the README screenshot source path outside the site asset copy", () => {
    const readme = readFileSync(resolve(repositoryRoot, "README.md"), "utf8");
    const readmeScreenshot = readme.match(/!\[[^\]]*\]\((docs\/images\/app-image\.png)\)/)?.[1];

    expect(readmeScreenshot).toBe("docs/images/app-image.png");
    expect(existsSync(resolve(repositoryRoot, readmeScreenshot))).toBe(true);
    expect(existsSync(resolve(webRoot, "src/assets/atelier-app-screenshot.png"))).toBe(true);
  });
});
