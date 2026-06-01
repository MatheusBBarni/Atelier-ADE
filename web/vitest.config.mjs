import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: ["tests/**/*.test.mjs"],
    testTimeout: 300_000,
    coverage: {
      provider: "v8",
      reporter: ["text", "json-summary"],
      include: ["src/config/siteConfig.mjs", "src/siteContent.ts", "src/repoStarCta.ts"],
      thresholds: {
        branches: 80,
        functions: 80,
        lines: 80,
        statements: 80
      }
    }
  }
});
