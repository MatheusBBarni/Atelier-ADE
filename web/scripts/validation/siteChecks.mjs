import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

import { JSDOM } from "jsdom";

import {
  DEFAULT_PAGES_BASE,
  REPOSITORY_URL,
  normalizeBasePath
} from "../../src/config/siteConfig.mjs";

export const VALIDATION_CHECKS = Object.freeze(["links", "no-js-cta", "a11y"]);
export const DEFAULT_DIST_DIR = "dist";

const SKIPPED_URL_PROTOCOLS = new Set(["data:", "blob:", "javascript:", "mailto:", "tel:"]);
const LOCAL_REFERENCE_ORIGIN = "https://local.invalid";

function unique(values) {
  return [...new Set(values)];
}

function parseCheckName(checkName) {
  if (!VALIDATION_CHECKS.includes(checkName)) {
    throw new Error(`Unknown validation check: ${checkName}`);
  }

  return checkName;
}

function readOptionValue(args, index, optionName) {
  const value = args[index + 1];

  if (!value || value.startsWith("--")) {
    throw new Error(`Missing value for ${optionName}`);
  }

  return value;
}

export function parseValidationCliArgs(args) {
  const options = {
    checks: [],
    distDir: DEFAULT_DIST_DIR,
    basePath: undefined,
    repoUrl: undefined
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];

    if (arg === "--all") {
      options.checks = [...VALIDATION_CHECKS];
    } else if (arg === "--check") {
      options.checks.push(readOptionValue(args, index, "--check"));
      index += 1;
    } else if (arg.startsWith("--check=")) {
      options.checks.push(arg.slice("--check=".length));
    } else if (arg === "--dist") {
      options.distDir = readOptionValue(args, index, "--dist");
      index += 1;
    } else if (arg.startsWith("--dist=")) {
      options.distDir = arg.slice("--dist=".length);
    } else if (arg === "--base") {
      options.basePath = readOptionValue(args, index, "--base");
      index += 1;
    } else if (arg.startsWith("--base=")) {
      options.basePath = arg.slice("--base=".length);
    } else if (arg === "--repo-url") {
      options.repoUrl = readOptionValue(args, index, "--repo-url");
      index += 1;
    } else if (arg.startsWith("--repo-url=")) {
      options.repoUrl = arg.slice("--repo-url=".length);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return {
    ...options,
    basePath: options.basePath ? normalizeBasePath(options.basePath) : undefined,
    repoUrl: options.repoUrl ?? REPOSITORY_URL,
    checks: unique(options.checks.length ? options.checks : VALIDATION_CHECKS).map(parseCheckName)
  };
}

export function getBuiltIndexPath(distDir) {
  return resolve(distDir, "index.html");
}

export function readBuiltIndexHtml(distDir) {
  return readFileSync(getBuiltIndexPath(distDir), "utf8");
}

export function stripBasePath(pathname, basePath) {
  const normalizedBase = normalizeBasePath(basePath);

  if (normalizedBase === "/") {
    return pathname || "/";
  }

  if (pathname === normalizedBase || pathname === `${normalizedBase}/`) {
    return "/";
  }

  if (pathname.startsWith(`${normalizedBase}/`)) {
    return pathname.slice(normalizedBase.length) || "/";
  }

  return null;
}

export function resolveDistPathForPublicPath(distDir, publicPath) {
  const normalizedPath = publicPath || "/";

  if (normalizedPath === "/" || normalizedPath.endsWith("/")) {
    return resolve(distDir, normalizedPath.replace(/^\/+/, ""), "index.html");
  }

  return resolve(distDir, normalizedPath.replace(/^\/+/, ""));
}

export function parseInternalReference(value, basePath) {
  if (!value || value.startsWith("//")) {
    return { skipped: true };
  }

  if (value.startsWith("#")) {
    return {
      publicPath: "/",
      hash: value.slice(1)
    };
  }

  let parsedUrl;

  try {
    parsedUrl = new URL(value, `${LOCAL_REFERENCE_ORIGIN}/`);
  } catch {
    return {
      issue: `Invalid URL reference: ${value}`
    };
  }

  if (SKIPPED_URL_PROTOCOLS.has(parsedUrl.protocol)) {
    return { skipped: true };
  }

  if (parsedUrl.origin !== LOCAL_REFERENCE_ORIGIN) {
    return { skipped: true };
  }

  const publicPath = stripBasePath(parsedUrl.pathname, basePath);

  if (publicPath === null) {
    return {
      issue: `Reference is outside configured base ${normalizeBasePath(basePath)}: ${value}`
    };
  }

  return {
    publicPath,
    hash: parsedUrl.hash ? decodeURIComponent(parsedUrl.hash.slice(1)) : ""
  };
}

export function extractUrlReferences(document) {
  const references = [];

  for (const element of document.querySelectorAll("a[href], link[href]")) {
    references.push({
      element: element.tagName.toLowerCase(),
      attribute: "href",
      value: element.getAttribute("href")
    });
  }

  for (const element of document.querySelectorAll("img[src], script[src]")) {
    references.push({
      element: element.tagName.toLowerCase(),
      attribute: "src",
      value: element.getAttribute("src")
    });
  }

  for (const element of document.querySelectorAll("source[srcset], img[srcset]")) {
    for (const srcsetEntry of element.getAttribute("srcset").split(",")) {
      references.push({
        element: element.tagName.toLowerCase(),
        attribute: "srcset",
        value: srcsetEntry.trim().split(/\s+/)[0]
      });
    }
  }

  for (const element of document.querySelectorAll("[style]")) {
    const style = element.getAttribute("style");
    const urlPattern = /url\((['"]?)([^'")]+)\1\)/g;
    let match = urlPattern.exec(style);

    while (match) {
      references.push({
        element: element.tagName.toLowerCase(),
        attribute: "style",
        value: match[2]
      });
      match = urlPattern.exec(style);
    }
  }

  return references;
}

export function collectLinkPathIssues(html, { distDir, basePath = DEFAULT_PAGES_BASE }) {
  const { document } = new JSDOM(html).window;
  const issues = [];

  for (const reference of extractUrlReferences(document)) {
    const parsedReference = parseInternalReference(reference.value, basePath);

    if (parsedReference.skipped) {
      continue;
    }

    if (parsedReference.issue) {
      issues.push(`${reference.element}[${reference.attribute}]: ${parsedReference.issue}`);
      continue;
    }

    const filePath = resolveDistPathForPublicPath(distDir, parsedReference.publicPath);

    if (!existsSync(filePath)) {
      issues.push(
        `${reference.element}[${reference.attribute}]: missing built file for ${reference.value}`
      );
    }

    if (parsedReference.hash && !document.getElementById(parsedReference.hash)) {
      issues.push(
        `${reference.element}[${reference.attribute}]: missing hash target #${parsedReference.hash}`
      );
    }
  }

  return issues;
}

export function findNoJavaScriptRepoCTA(html, repoUrl = REPOSITORY_URL) {
  const { document } = new JSDOM(html).window;

  for (const link of document.querySelectorAll("[data-repo-cta-link]")) {
    const href = link.getAttribute("href");

    if (href === repoUrl) {
      return {
        href,
        label: link.textContent.trim(),
        ariaLabel: link.getAttribute("aria-label") ?? "",
        hasFallbackMarker: link.hasAttribute("data-repo-cta-fallback")
      };
    }
  }

  return null;
}

export function collectNoJavaScriptCtaIssues(html, { repoUrl = REPOSITORY_URL } = {}) {
  const cta = findNoJavaScriptRepoCTA(html, repoUrl);
  const issues = [];

  if (!cta) {
    return [`No fallback repository CTA link found for ${repoUrl}`];
  }

  if (!cta.label) {
    issues.push("Fallback repository CTA has no visible label");
  }

  if (!cta.ariaLabel) {
    issues.push("Fallback repository CTA has no accessible label");
  }

  if (!cta.hasFallbackMarker) {
    issues.push("Fallback repository CTA is missing data-repo-cta-fallback");
  }

  return issues;
}

export function collectAccessibilitySmokeIssues(html) {
  const { document } = new JSDOM(html).window;
  const issues = [];
  const headings = [...document.querySelectorAll("h1, h2, h3, h4, h5, h6")];
  const h1Count = document.querySelectorAll("h1").length;

  if (document.documentElement.getAttribute("lang") !== "en") {
    issues.push("Document language must be set to en");
  }

  if (h1Count !== 1) {
    issues.push(`Expected exactly one h1, found ${h1Count}`);
  }

  for (let index = 1; index < headings.length; index += 1) {
    const previousLevel = Number(headings[index - 1].tagName.slice(1));
    const currentLevel = Number(headings[index].tagName.slice(1));

    if (currentLevel - previousLevel > 1) {
      issues.push(`Heading level jumps from h${previousLevel} to h${currentLevel}`);
    }
  }

  for (const image of document.querySelectorAll("img")) {
    if (!image.hasAttribute("alt")) {
      issues.push(`Image is missing alt text: ${image.getAttribute("src") ?? "unknown source"}`);
    }
  }

  for (const link of document.querySelectorAll("a")) {
    const label = link.textContent.trim() || link.getAttribute("aria-label") || link.getAttribute("title");

    if (!label) {
      issues.push(`Link is missing an accessible label: ${link.getAttribute("href") ?? "unknown href"}`);
    }
  }

  for (const button of document.querySelectorAll("button")) {
    const label =
      button.textContent.trim() || button.getAttribute("aria-label") || button.getAttribute("title");

    if (!label) {
      issues.push("Button is missing an accessible label");
    }
  }

  return issues;
}

export function runBuiltSiteChecks({
  html,
  distDir,
  basePath = DEFAULT_PAGES_BASE,
  repoUrl = REPOSITORY_URL,
  checks = VALIDATION_CHECKS
}) {
  const checkCollectors = {
    links: () => collectLinkPathIssues(html, { distDir, basePath }),
    "no-js-cta": () => collectNoJavaScriptCtaIssues(html, { repoUrl }),
    a11y: () => collectAccessibilitySmokeIssues(html)
  };
  const results = checks.map((check) => ({
    check: parseCheckName(check),
    issues: checkCollectors[check]()
  }));
  const issueCount = results.reduce((count, result) => count + result.issues.length, 0);

  return {
    ok: issueCount === 0,
    issueCount,
    results
  };
}

export function checkBuiltSite({
  distDir = DEFAULT_DIST_DIR,
  basePath = DEFAULT_PAGES_BASE,
  repoUrl = REPOSITORY_URL,
  checks = VALIDATION_CHECKS,
  html = readBuiltIndexHtml(distDir)
} = {}) {
  return runBuiltSiteChecks({
    html,
    distDir,
    basePath,
    repoUrl,
    checks
  });
}

export function formatValidationReport(result) {
  const lines = result.results.map(({ check, issues }) => {
    if (issues.length === 0) {
      return `${check}: pass`;
    }

    return [`${check}: fail`, ...issues.map((issue) => `  - ${issue}`)].join("\n");
  });

  return lines.join("\n");
}
