import { REPOSITORY_URL } from "./siteContent";

export const REPO_STAR_CTA_SELECTOR = "[data-repo-star-cta]";
export const REPO_CTA_LINK_SELECTOR = "[data-repo-cta-link]";
export const REPO_CTA_LABEL_SELECTOR = "[data-repo-cta-label]";
export const GITHUB_REPO_API_URL = getGitHubRepoApiUrl(REPOSITORY_URL);

export type RepoCTAErrorCode = "rate_limited" | "network" | "invalid_response";

export type RepoCTAState = {
  href: string;
  label: string;
  stars?: number;
  loading: boolean;
  fallback: boolean;
  errorCode?: RepoCTAErrorCode;
};

type GitHubRepoMetadata = {
  stargazers_count?: unknown;
  html_url?: unknown;
};

type FetchLike = (
  input: string,
  init?: {
    headers?: Record<string, string>;
  }
) => Promise<{
  ok: boolean;
  status: number;
  json: () => Promise<unknown>;
}>;

type FetchGitHubRepoCTAStateOptions = {
  endpoint?: string;
  fallbackState: RepoCTAState;
  fetchImpl?: FetchLike;
};

type EnhanceRepoStarCTAOptions = {
  documentRef?: Pick<Document, "querySelectorAll">;
  fetchImpl?: FetchLike;
  selector?: string;
};

export function getGitHubRepoApiUrl(repoUrl: string) {
  const { pathname } = new URL(repoUrl);
  const [owner, repo] = pathname.replace(/^\/+|\/+$/g, "").split("/");

  return `https://api.github.com/repos/${owner}/${repo}`;
}

export function createFallbackRepoCTAState({
  href,
  label
}: Pick<RepoCTAState, "href" | "label">): RepoCTAState {
  return {
    href,
    label,
    loading: false,
    fallback: true
  };
}

export function formatStarCount(stars: number) {
  const starLabel = stars === 1 ? "star" : "stars";

  return `${new Intl.NumberFormat("en-US").format(stars)} ${starLabel}`;
}

export function formatRepoCTAStarLabel(fallbackLabel: string, stars: number) {
  return `${fallbackLabel} - ${formatStarCount(stars)}`;
}

export function parseGitHubRepoStars(metadata: unknown) {
  if (!metadata || typeof metadata !== "object") {
    return null;
  }

  const { stargazers_count: stars, html_url: htmlUrl } = metadata as GitHubRepoMetadata;

  if (!Number.isInteger(stars) || Number(stars) < 0) {
    return null;
  }

  if (typeof htmlUrl !== "string" || !htmlUrl.startsWith("https://github.com/")) {
    return null;
  }

  return Number(stars);
}

export function getRepoCTAErrorCode(status: number): RepoCTAErrorCode {
  return status === 403 || status === 429 ? "rate_limited" : "network";
}

export async function fetchGitHubRepoCTAState({
  endpoint = GITHUB_REPO_API_URL,
  fallbackState,
  fetchImpl = globalThis.fetch as FetchLike | undefined
}: FetchGitHubRepoCTAStateOptions): Promise<RepoCTAState> {
  const fallback = {
    ...fallbackState,
    loading: false,
    fallback: true
  };

  if (typeof fetchImpl !== "function") {
    return {
      ...fallback,
      errorCode: "network"
    };
  }

  try {
    const response = await fetchImpl(endpoint, {
      headers: {
        Accept: "application/vnd.github+json"
      }
    });

    if (!response.ok) {
      return {
        ...fallback,
        errorCode: getRepoCTAErrorCode(response.status)
      };
    }

    const stars = parseGitHubRepoStars(await response.json());

    if (stars === null) {
      return {
        ...fallback,
        errorCode: "invalid_response"
      };
    }

    return {
      href: fallback.href,
      label: formatRepoCTAStarLabel(fallback.label, stars),
      stars,
      loading: false,
      fallback: false
    };
  } catch {
    return {
      ...fallback,
      errorCode: "network"
    };
  }
}

export function readFallbackRepoCTAState(root: Element) {
  const link = root.querySelector<HTMLAnchorElement>(REPO_CTA_LINK_SELECTOR);
  const labelTarget = root.querySelector<HTMLElement>(REPO_CTA_LABEL_SELECTOR) ?? link;
  const href = root.getAttribute("data-repo-url") ?? link?.getAttribute("href") ?? REPOSITORY_URL;
  const label =
    root.getAttribute("data-fallback-label") ??
    labelTarget?.textContent?.trim() ??
    "Open the repository";

  return createFallbackRepoCTAState({
    href,
    label
  });
}

export function applyRepoCTAState(root: Element, state: RepoCTAState) {
  const link = root.querySelector<HTMLAnchorElement>(REPO_CTA_LINK_SELECTOR);
  const labelTarget = root.querySelector<HTMLElement>(REPO_CTA_LABEL_SELECTOR) ?? link;
  const stateName = state.fallback ? "fallback" : "enhanced";

  root.setAttribute("data-repo-cta-state", stateName);

  if (state.stars === undefined) {
    root.removeAttribute("data-repo-cta-stars");
  } else {
    root.setAttribute("data-repo-cta-stars", String(state.stars));
  }

  if (link) {
    link.setAttribute("href", state.href);
    link.setAttribute("data-repo-cta-state", stateName);
  }

  if (labelTarget) {
    labelTarget.textContent = state.label;
  }
}

export async function enhanceRepoStarCTA({
  documentRef = globalThis.document,
  fetchImpl = globalThis.fetch as FetchLike | undefined,
  selector = REPO_STAR_CTA_SELECTOR
}: EnhanceRepoStarCTAOptions = {}) {
  if (!documentRef?.querySelectorAll) {
    return [];
  }

  const roots = Array.from(documentRef.querySelectorAll(selector));

  return Promise.all(
    roots.map(async (root) => {
      const fallbackState = readFallbackRepoCTAState(root);
      const state = await fetchGitHubRepoCTAState({
        fallbackState,
        fetchImpl
      });

      applyRepoCTAState(root, state);

      return state;
    })
  );
}
