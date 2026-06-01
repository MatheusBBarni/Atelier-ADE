import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import {
  LANDING_PAGE_URL,
  landingPageAssets,
  siteContent
} from "../../src/siteContent.ts";

const testDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(testDirectory, "../../..");

function readRepositoryFile(path) {
  return readFileSync(resolve(repositoryRoot, path), "utf8");
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function extractSection(markdown, heading) {
  const sectionPattern = new RegExp(
    `(?:^|\\n)## ${escapeRegex(heading)}\\n([\\s\\S]*?)(?=\\n## |$)`
  );
  return markdown.match(sectionPattern)?.[1] ?? "";
}

function extractRunScriptModes(runScript) {
  const usageModes = runScript.match(/Usage: \.\/scripts\/run\.sh \[([^\]]+)\]/)?.[1];

  if (!usageModes) {
    throw new Error("Unable to find scripts/run.sh usage modes");
  }

  return usageModes.split("|");
}

describe("README public entry points", () => {
  it("links to the landing page, repository, docs, and quickstart destinations", () => {
    const readme = readRepositoryFile("README.md");
    const evaluateSection = extractSection(readme, "Evaluate Atelier");

    expect(evaluateSection).toContain(`[Open the repository](${siteContent.repoUrl})`);
    expect(evaluateSection).toContain(`[View the product overview](${LANDING_PAGE_URL})`);
    expect(evaluateSection).toContain(`[Read the README](${siteContent.docsUrl})`);
    expect(evaluateSection).toContain(`[Build and run](${siteContent.quickstartUrl})`);
  });

  it("preserves the repo-first CTA hierarchy with docs and quickstart as secondary paths", () => {
    const readme = readRepositoryFile("README.md");
    const evaluateSection = extractSection(readme, "Evaluate Atelier");
    const repositoryIndex = evaluateSection.indexOf("Open the repository");
    const overviewIndex = evaluateSection.indexOf("View the product overview");
    const docsIndex = evaluateSection.indexOf("Read the README");
    const quickstartIndex = evaluateSection.indexOf("Build and run");

    expect(repositoryIndex).toBeGreaterThan(-1);
    expect(repositoryIndex).toBeLessThan(overviewIndex);
    expect(overviewIndex).toBeLessThan(docsIndex);
    expect(docsIndex).toBeLessThan(quickstartIndex);
    expect(evaluateSection).toMatch(/primary path for source, status, and project reality/);
  });

  it("uses Atelier as public copy and keeps internal package naming out of the README", () => {
    const readme = readRepositoryFile("README.md");

    expect(readme).toContain("# Atelier");
    expect(readme).toContain(siteContent.productName);
    expect(readme).not.toMatch(/NativeMacADE/);
  });

  it("keeps README quickstart commands aligned with scripts/run.sh modes", () => {
    const readme = readRepositoryFile("README.md");
    const runScript = readRepositoryFile("scripts/run.sh");
    const quickstartSection = extractSection(readme, "Build, test, and run");
    const modes = extractRunScriptModes(runScript);

    expect(modes).toEqual(["run", "build", "bundle", "test"]);

    for (const mode of modes) {
      expect(quickstartSection).toContain(`./scripts/run.sh ${mode}`);
    }

    expect(runScript).toContain('APP_BUNDLE_NAME="Atelier"');
    expect(quickstartSection).toContain("Atelier.app");
  });

  it("keeps screenshot proof and release artifact references valid", () => {
    const readme = readRepositoryFile("README.md");
    const releaseWorkflow = readRepositoryFile(".github/workflows/release-build.yml");
    const readmeScreenshot = readme.match(/!\[[^\]]*\]\(([^)]+)\)/)?.[1];

    expect(readmeScreenshot).toBe(landingPageAssets.screenshot.sourcePath);
    expect(existsSync(resolve(repositoryRoot, readmeScreenshot))).toBe(true);
    expect(readme).toContain("Atelier-macOS-<version>.zip");
    expect(releaseWorkflow).toContain('ZIP_NAME="Atelier-macOS-${APP_VERSION}.zip"');
    expect(releaseWorkflow).toContain("name: Atelier-macOS-${{ env.APP_VERSION }}");
  });

  it("states license status honestly while no LICENSE file exists", () => {
    const readme = readRepositoryFile("README.md");
    const licenseSection = extractSection(readme, "License");

    expect(existsSync(resolve(repositoryRoot, "LICENSE"))).toBe(false);
    expect(licenseSection).toMatch(/formal project license has not been finalized yet/i);
    expect(licenseSection).toMatch(/reuse rights as pending/i);
  });
});
