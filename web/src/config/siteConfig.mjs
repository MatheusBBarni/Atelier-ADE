import { dirname, resolve, basename } from "node:path";
import { fileURLToPath } from "node:url";

import {
  DEFAULT_PAGES_BASE,
  DEFAULT_SITE_ORIGIN,
  REPOSITORY_NAME,
  REPOSITORY_OWNER,
  REPOSITORY_URL
} from "./repository.mjs";

export {
  DEFAULT_PAGES_BASE,
  DEFAULT_SITE_ORIGIN,
  REPOSITORY_NAME,
  REPOSITORY_OWNER,
  REPOSITORY_URL
} from "./repository.mjs";

export function normalizeOrigin(origin) {
  return origin.replace(/\/+$/, "");
}

export function normalizeBasePath(basePath) {
  if (!basePath || basePath === "/") {
    return "/";
  }

  const withLeadingSlash = basePath.startsWith("/") ? basePath : `/${basePath}`;
  return withLeadingSlash.replace(/\/+$/, "");
}

export function getAstroSiteConfig(env = process.env) {
  const site = normalizeOrigin(env.PUBLIC_SITE_ORIGIN ?? env.SITE_ORIGIN ?? DEFAULT_SITE_ORIGIN);
  const base = normalizeBasePath(env.PUBLIC_SITE_BASE ?? env.SITE_BASE ?? DEFAULT_PAGES_BASE);

  return { site, base };
}

export function assertWebWorkspaceRoot(workspaceRoot) {
  const resolvedRoot = resolve(workspaceRoot);

  if (basename(resolvedRoot) !== "web") {
    throw new Error(`Expected web workspace root, received: ${resolvedRoot}`);
  }

  return resolvedRoot;
}

export function getWebWorkspaceRoot(metaUrl = import.meta.url) {
  const moduleDirectory = dirname(fileURLToPath(metaUrl));
  return assertWebWorkspaceRoot(resolve(moduleDirectory, "../.."));
}
