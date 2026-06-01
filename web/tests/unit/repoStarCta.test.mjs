import { describe, expect, it, vi } from "vitest";
import { JSDOM } from "jsdom";

import {
  GITHUB_REPO_API_URL,
  applyRepoCTAState,
  createFallbackRepoCTAState,
  enhanceRepoStarCTA,
  fetchGitHubRepoCTAState,
  formatRepoCTAStarLabel,
  formatStarCount,
  getGitHubRepoApiUrl,
  parseGitHubRepoStars,
  readFallbackRepoCTAState
} from "../../src/repoStarCta.ts";
import { REPOSITORY_URL } from "../../src/siteContent.ts";

const fallbackState = createFallbackRepoCTAState({
  href: REPOSITORY_URL,
  label: "Open the repository"
});

function jsonResponse(body, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => body
  };
}

describe("repo star CTA formatting", () => {
  it("derives the GitHub API endpoint from the centralized repository URL", () => {
    expect(getGitHubRepoApiUrl(REPOSITORY_URL)).toBe(GITHUB_REPO_API_URL);
    expect(GITHUB_REPO_API_URL).toBe(
      "https://api.github.com/repos/MatheusBBarni/Atelier-ADE"
    );
  });

  it("formats GitHub star counts for CTA labels", () => {
    expect(formatStarCount(0)).toBe("0 stars");
    expect(formatStarCount(1)).toBe("1 star");
    expect(formatStarCount(1234)).toBe("1,234 stars");
    expect(formatRepoCTAStarLabel("Open the repository", 1234)).toBe(
      "Open the repository - 1,234 stars"
    );
  });
});

describe("GitHub repository metadata parsing", () => {
  it("accepts valid public GitHub metadata with a star count", () => {
    expect(
      parseGitHubRepoStars({
        stargazers_count: 42,
        html_url: REPOSITORY_URL,
        name: "Atelier-ADE",
        owner: {
          login: "MatheusBBarni"
        }
      })
    ).toBe(42);
  });

  it("rejects invalid or incomplete GitHub metadata", () => {
    expect(parseGitHubRepoStars(null)).toBeNull();
    expect(parseGitHubRepoStars({ stargazers_count: 42 })).toBeNull();
    expect(parseGitHubRepoStars({ html_url: REPOSITORY_URL })).toBeNull();
    expect(parseGitHubRepoStars({ stargazers_count: -1, html_url: REPOSITORY_URL })).toBeNull();
    expect(parseGitHubRepoStars({ stargazers_count: 2.5, html_url: REPOSITORY_URL })).toBeNull();
    expect(
      parseGitHubRepoStars({ stargazers_count: 42, html_url: "https://example.com/repo" })
    ).toBeNull();
  });
});

describe("GitHub repository CTA state", () => {
  it("updates the fallback CTA label with the expected star count from a valid response", async () => {
    const fetchImpl = vi.fn(async () =>
      jsonResponse({
        stargazers_count: 1288,
        html_url: REPOSITORY_URL
      })
    );

    const state = await fetchGitHubRepoCTAState({
      fallbackState,
      fetchImpl
    });

    expect(fetchImpl).toHaveBeenCalledWith(GITHUB_REPO_API_URL, {
      headers: {
        Accept: "application/vnd.github+json"
      }
    });
    expect(state).toMatchObject({
      href: REPOSITORY_URL,
      label: "Open the repository - 1,288 stars",
      stars: 1288,
      loading: false,
      fallback: false
    });
    expect(state.errorCode).toBeUndefined();
  });

  it("preserves fallback CTA text on invalid GitHub metadata responses", async () => {
    const state = await fetchGitHubRepoCTAState({
      fallbackState,
      fetchImpl: async () => jsonResponse({ stargazers_count: 1288 })
    });

    expect(state).toMatchObject({
      href: REPOSITORY_URL,
      label: "Open the repository",
      loading: false,
      fallback: true,
      errorCode: "invalid_response"
    });
    expect(state.stars).toBeUndefined();
  });

  it("preserves link state on network failures and rate-limited responses", async () => {
    const networkState = await fetchGitHubRepoCTAState({
      fallbackState,
      fetchImpl: async () => {
        throw new Error("offline");
      }
    });
    const rateLimitedState = await fetchGitHubRepoCTAState({
      fallbackState,
      fetchImpl: async () => jsonResponse({ message: "rate limited" }, 429)
    });

    expect(networkState).toMatchObject({
      href: REPOSITORY_URL,
      label: "Open the repository",
      fallback: true,
      errorCode: "network"
    });
    expect(rateLimitedState).toMatchObject({
      href: REPOSITORY_URL,
      label: "Open the repository",
      fallback: true,
      errorCode: "rate_limited"
    });
  });

  it("preserves fallback state when fetch is unavailable or GitHub returns a server error", async () => {
    const unavailableState = await fetchGitHubRepoCTAState({
      fallbackState,
      fetchImpl: null
    });
    const serverErrorState = await fetchGitHubRepoCTAState({
      fallbackState,
      fetchImpl: async () => jsonResponse({ message: "unavailable" }, 503)
    });

    expect(unavailableState).toMatchObject({
      href: REPOSITORY_URL,
      label: "Open the repository",
      fallback: true,
      errorCode: "network"
    });
    expect(serverErrorState).toMatchObject({
      href: REPOSITORY_URL,
      label: "Open the repository",
      fallback: true,
      errorCode: "network"
    });
  });
});

describe("repo CTA DOM enhancement", () => {
  it("reads fallback state from rendered CTA markup and applies enhanced label state", () => {
    const dom = new JSDOM(`
      <div data-repo-star-cta data-repo-url="${REPOSITORY_URL}" data-fallback-label="Open the repository">
        <a data-repo-cta-link href="${REPOSITORY_URL}">
          <span data-repo-cta-label>Open the repository</span>
        </a>
      </div>
    `);
    const root = dom.window.document.querySelector("[data-repo-star-cta]");

    expect(readFallbackRepoCTAState(root)).toMatchObject({
      href: REPOSITORY_URL,
      label: "Open the repository",
      fallback: true
    });

    applyRepoCTAState(root, {
      href: REPOSITORY_URL,
      label: "Open the repository - 99 stars",
      stars: 99,
      loading: false,
      fallback: false
    });

    expect(root.getAttribute("data-repo-cta-state")).toBe("enhanced");
    expect(root.getAttribute("data-repo-cta-stars")).toBe("99");
    expect(root.querySelector("[data-repo-cta-link]").getAttribute("href")).toBe(REPOSITORY_URL);
    expect(root.querySelector("[data-repo-cta-label]").textContent).toBe(
      "Open the repository - 99 stars"
    );
  });

  it("falls back to link text or default label when rendered data attributes are missing", () => {
    const domWithLinkText = new JSDOM(`
      <div data-repo-star-cta>
        <a data-repo-cta-link href="${REPOSITORY_URL}">Repo source</a>
      </div>
    `);
    const domWithNoLink = new JSDOM("<div data-repo-star-cta></div>");

    expect(
      readFallbackRepoCTAState(domWithLinkText.window.document.querySelector("[data-repo-star-cta]"))
    ).toMatchObject({
      href: REPOSITORY_URL,
      label: "Repo source"
    });
    expect(
      readFallbackRepoCTAState(domWithNoLink.window.document.querySelector("[data-repo-star-cta]"))
    ).toMatchObject({
      href: REPOSITORY_URL,
      label: "Open the repository"
    });
  });

  it("enhances all matching CTA roots and keeps fallback data when enhancement fails", async () => {
    const dom = new JSDOM(`
      <main>
        <div data-repo-star-cta data-repo-url="${REPOSITORY_URL}" data-fallback-label="Open the repository">
          <a data-repo-cta-link href="${REPOSITORY_URL}">
            <span data-repo-cta-label>Open the repository</span>
          </a>
        </div>
      </main>
    `);
    const [state] = await enhanceRepoStarCTA({
      documentRef: dom.window.document,
      fetchImpl: async () =>
        jsonResponse({
          stargazers_count: 7,
          html_url: REPOSITORY_URL
        })
    });
    const root = dom.window.document.querySelector("[data-repo-star-cta]");

    expect(state).toMatchObject({
      stars: 7,
      fallback: false
    });
    expect(root.getAttribute("data-repo-cta-state")).toBe("enhanced");
    expect(root.getAttribute("data-repo-cta-stars")).toBe("7");

    applyRepoCTAState(root, {
      href: REPOSITORY_URL,
      label: "Open the repository",
      loading: false,
      fallback: true,
      errorCode: "network"
    });
    expect(root.getAttribute("data-repo-cta-state")).toBe("fallback");
    expect(root.getAttribute("data-repo-cta-stars")).toBeNull();
  });

  it("does nothing when no document is available", async () => {
    await expect(enhanceRepoStarCTA({ documentRef: null })).resolves.toEqual([]);
  });
});
