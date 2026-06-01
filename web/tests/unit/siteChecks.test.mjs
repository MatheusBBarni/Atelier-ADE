import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

import { afterEach, beforeEach, describe, expect, it } from "vitest";

import { DEFAULT_PAGES_BASE, REPOSITORY_URL } from "../../src/config/siteConfig.mjs";
import {
  collectAccessibilitySmokeIssues,
  collectLinkPathIssues,
  collectNoJavaScriptCtaIssues,
  findNoJavaScriptRepoCTA,
  parseInternalReference,
  parseValidationCliArgs,
  resolveDistPathForPublicPath,
  runBuiltSiteChecks,
  stripBasePath
} from "../../scripts/validation/siteChecks.mjs";

let distDir;

function writeDistFile(relativePath, contents = "") {
  const filePath = join(distDir, relativePath);
  mkdirSync(resolve(filePath, ".."), { recursive: true });
  writeFileSync(filePath, contents);
}

function sampleHtml() {
  return `<!doctype html>
    <html lang="en">
      <head>
        <title>Atelier</title>
        <link rel="icon" href="${DEFAULT_PAGES_BASE}/favicon.png" />
      </head>
      <body>
        <a class="skip-link" href="#main">Skip to content</a>
        <main id="main">
          <h1>Atelier</h1>
          <h2 id="proof">Proof</h2>
          <a href="${DEFAULT_PAGES_BASE}/">Home</a>
          <a
            data-repo-cta-link
            data-repo-cta-fallback
            href="${REPOSITORY_URL}"
            aria-label="Open the Atelier GitHub repository"
          >
            <span>Open the repository</span>
          </a>
          <img src="${DEFAULT_PAGES_BASE}/_astro/app.png" alt="Atelier screenshot" />
          <div style="background-image: url('${DEFAULT_PAGES_BASE}/_astro/hero.png')"></div>
        </main>
      </body>
    </html>`;
}

beforeEach(() => {
  distDir = mkdtempSync(join(tmpdir(), "atelier-web-dist-"));
  writeDistFile("index.html", sampleHtml());
  writeDistFile("favicon.png");
  writeDistFile("_astro/app.png");
  writeDistFile("_astro/hero.png");
});

afterEach(() => {
  rmSync(distDir, { recursive: true, force: true });
});

describe("validation CLI argument parsing", () => {
  it("resolves selected checks and Pages base path options", () => {
    expect(
      parseValidationCliArgs([
        "--check",
        "links",
        "--check=no-js-cta",
        "--base",
        "Atelier-ADE/",
        "--dist=public-site"
      ])
    ).toEqual({
      checks: ["links", "no-js-cta"],
      distDir: "public-site",
      basePath: DEFAULT_PAGES_BASE,
      repoUrl: REPOSITORY_URL
    });
  });

  it("rejects unknown checks and malformed options", () => {
    expect(() => parseValidationCliArgs(["--check", "visual"])).toThrow(
      "Unknown validation check: visual"
    );
    expect(() => parseValidationCliArgs(["--base"])).toThrow("Missing value for --base");
  });
});

describe("Pages base path validation", () => {
  it("maps GitHub Pages URLs into built dist files", () => {
    expect(stripBasePath("/Atelier-ADE/", DEFAULT_PAGES_BASE)).toBe("/");
    expect(stripBasePath("/Atelier-ADE/_astro/app.png", DEFAULT_PAGES_BASE)).toBe(
      "/_astro/app.png"
    );
    expect(stripBasePath("/_astro/app.png", DEFAULT_PAGES_BASE)).toBeNull();
    expect(resolveDistPathForPublicPath(distDir, "/")).toBe(join(distDir, "index.html"));
    expect(resolveDistPathForPublicPath(distDir, "/_astro/app.png")).toBe(
      join(distDir, "_astro/app.png")
    );
  });

  it("classifies local, external, and hash-only references", () => {
    expect(parseInternalReference("#proof", DEFAULT_PAGES_BASE)).toMatchObject({
      publicPath: "/",
      hash: "proof"
    });
    expect(parseInternalReference(`${DEFAULT_PAGES_BASE}/favicon.png`, DEFAULT_PAGES_BASE)).toMatchObject({
      publicPath: "/favicon.png"
    });
    expect(parseInternalReference(REPOSITORY_URL, DEFAULT_PAGES_BASE)).toEqual({ skipped: true });
  });

  it("finds broken internal references and missing hash targets", () => {
    const html = sampleHtml()
      .replace(`${DEFAULT_PAGES_BASE}/favicon.png`, "/favicon.png")
      .replace("#main", "#missing-main");

    expect(collectLinkPathIssues(html, { distDir, basePath: DEFAULT_PAGES_BASE })).toEqual([
      "link[href]: Reference is outside configured base /Atelier-ADE: /favicon.png",
      "a[href]: missing hash target #missing-main"
    ]);
  });
});

describe("no-JavaScript CTA validation", () => {
  it("identifies the fallback GitHub repository link in built output", () => {
    expect(findNoJavaScriptRepoCTA(sampleHtml())).toMatchObject({
      href: REPOSITORY_URL,
      label: "Open the repository",
      ariaLabel: "Open the Atelier GitHub repository",
      hasFallbackMarker: true
    });
    expect(collectNoJavaScriptCtaIssues(sampleHtml())).toEqual([]);
  });

  it("reports missing or inaccessible fallback CTA markup", () => {
    expect(collectNoJavaScriptCtaIssues("<main></main>")).toEqual([
      `No fallback repository CTA link found for ${REPOSITORY_URL}`
    ]);

    expect(
      collectNoJavaScriptCtaIssues(`
        <a data-repo-cta-link href="${REPOSITORY_URL}"></a>
      `)
    ).toEqual([
      "Fallback repository CTA has no visible label",
      "Fallback repository CTA has no accessible label",
      "Fallback repository CTA is missing data-repo-cta-fallback"
    ]);
  });
});

describe("built site smoke validation", () => {
  it("passes the combined link, no-JavaScript CTA, and accessibility checks", () => {
    expect(
      runBuiltSiteChecks({
        html: sampleHtml(),
        distDir,
        basePath: DEFAULT_PAGES_BASE,
        repoUrl: REPOSITORY_URL
      })
    ).toMatchObject({
      ok: true,
      issueCount: 0
    });
  });

  it("reports basic accessibility smoke issues", () => {
    expect(
      collectAccessibilitySmokeIssues(`
        <html>
          <body>
            <h1>One</h1>
            <h3>Jump</h3>
            <img src="/missing-alt.png" />
            <a href="/empty"></a>
            <button></button>
          </body>
        </html>
      `)
    ).toEqual([
      "Document language must be set to en",
      "Heading level jumps from h1 to h3",
      "Image is missing alt text: /missing-alt.png",
      "Link is missing an accessible label: /empty",
      "Button is missing an accessible label"
    ]);
  });
});
