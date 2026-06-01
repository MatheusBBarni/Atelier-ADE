import { basename, resolve } from "node:path";

import { describe, expect, it } from "vitest";

import {
  DEFAULT_PAGES_BASE,
  DEFAULT_SITE_ORIGIN,
  assertWebWorkspaceRoot,
  getAstroSiteConfig,
  getWebWorkspaceRoot,
  normalizeBasePath,
  normalizeOrigin
} from "../../src/config/siteConfig.mjs";

describe("site configuration defaults", () => {
  it("derives the GitHub Pages site and base defaults", () => {
    expect(getAstroSiteConfig({})).toEqual({
      site: DEFAULT_SITE_ORIGIN,
      base: DEFAULT_PAGES_BASE
    });
  });

  it("uses stable CI or local overrides when provided", () => {
    expect(
      getAstroSiteConfig({
        SITE_ORIGIN: "https://preview.example.com/",
        SITE_BASE: "preview"
      })
    ).toEqual({
      site: "https://preview.example.com",
      base: "/preview"
    });

    expect(
      getAstroSiteConfig({
        PUBLIC_SITE_ORIGIN: "https://public.example.com///",
        PUBLIC_SITE_BASE: "/"
      })
    ).toEqual({
      site: "https://public.example.com",
      base: "/"
    });
  });

  it("normalizes standalone site metadata values", () => {
    expect(normalizeOrigin("https://example.com///")).toBe("https://example.com");
    expect(normalizeBasePath("Atelier-ADE/")).toBe("/Atelier-ADE");
    expect(normalizeBasePath("")).toBe("/");
  });
});

describe("web workspace boundary", () => {
  it("resolves helpers to the web workspace root", () => {
    const workspaceRoot = getWebWorkspaceRoot();

    expect(basename(workspaceRoot)).toBe("web");
  });

  it("rejects paths outside the web workspace boundary", () => {
    const workspaceRoot = getWebWorkspaceRoot();
    const repositoryRoot = resolve(workspaceRoot, "..");

    expect(assertWebWorkspaceRoot(workspaceRoot)).toBe(workspaceRoot);
    expect(() => assertWebWorkspaceRoot(repositoryRoot)).toThrow("Expected web workspace root");
  });
});
