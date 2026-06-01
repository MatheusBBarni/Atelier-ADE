export const REQUIRED_WEB_VALIDATION_COMMANDS = Object.freeze([
  {
    id: "unit-tests",
    label: "Run web unit tests",
    script: "test:unit",
    command: "npm run test:unit"
  },
  {
    id: "astro-build",
    label: "Build Astro site",
    script: "build",
    command: "npm run build"
  },
  {
    id: "link-paths",
    label: "Validate built links and paths",
    script: "validate:links",
    command: "npm run validate:links"
  },
  {
    id: "no-js-cta",
    label: "Validate no-JavaScript repo CTA",
    script: "validate:no-js-cta",
    command: "npm run validate:no-js-cta"
  },
  {
    id: "accessibility",
    label: "Run accessibility smoke check",
    script: "validate:a11y",
    command: "npm run validate:a11y"
  }
]);

export function parsePackageJson(packageJson) {
  return typeof packageJson === "string" ? JSON.parse(packageJson) : packageJson;
}

export function resolveWebValidationCommands(packageJson) {
  const parsedPackage = parsePackageJson(packageJson);
  const scripts = parsedPackage?.scripts ?? {};

  return REQUIRED_WEB_VALIDATION_COMMANDS.map((entry) => {
    if (typeof scripts[entry.script] !== "string") {
      throw new Error(`Missing required web script: ${entry.script}`);
    }

    return {
      ...entry,
      workingDirectory: "web"
    };
  });
}

export function collectMissingWorkflowCommands(workflowText, commands) {
  return commands
    .filter(({ command }) => !workflowText.includes(`run: ${command}`))
    .map(({ command }) => command);
}
