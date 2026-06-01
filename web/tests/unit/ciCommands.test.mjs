import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

import {
  REQUIRED_WEB_VALIDATION_COMMANDS,
  collectMissingWorkflowCommands,
  resolveWebValidationCommands
} from "../../scripts/validation/ciCommands.mjs";

const packageJson = readFileSync(resolve(process.cwd(), "package.json"), "utf8");

describe("web CI validation command contract", () => {
  it("resolves the required web validation commands from package scripts", () => {
    expect(resolveWebValidationCommands(packageJson)).toEqual(
      REQUIRED_WEB_VALIDATION_COMMANDS.map((entry) => ({
        ...entry,
        workingDirectory: "web"
      }))
    );
  });

  it("reports missing package scripts before workflow commands drift", () => {
    expect(() =>
      resolveWebValidationCommands({
        scripts: {
          build: "astro build"
        }
      })
    ).toThrow("Missing required web script: test:unit");
  });

  it("detects validation commands missing from workflow text", () => {
    const commands = resolveWebValidationCommands(packageJson);
    const workflowText = commands
      .filter(({ script }) => script !== "validate:a11y")
      .map(({ command }) => `run: ${command}`)
      .join("\n");

    expect(collectMissingWorkflowCommands(workflowText, commands)).toEqual([
      "npm run validate:a11y"
    ]);
  });
});
