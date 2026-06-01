import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const webRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const repositoryRoot = resolve(webRoot, "..");

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
  it("builds the static site and emits the index route", () => {
    const output = run("npm", ["run", "build"], webRoot);
    const indexPath = resolve(webRoot, "dist/index.html");

    expect(output).toContain("Complete");
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
  });
});
