# Project Landing Page

## Overview

Project Landing Page defines the first dedicated public homepage for Atelier. Its job is to help developers understand what Atelier is, why it exists, and why it is credible before asking them to take a deeper step. The page should turn a README-first project surface into a clearer product entry point without pretending the product is more mature than it is.

This PRD is for developers evaluating whether Atelier fits their workflow, plus technically curious open-source visitors deciding whether the project deserves closer attention. The value is business and product clarity. A strong landing page reduces discovery friction, sharpens positioning, and creates a public narrative that matches the product’s actual strengths: native macOS feel, local-first transparency, and calmer agentic workflow management.

The approved MVP is intentionally small. It is a trust-first, repo-oriented trailhead, not a broad marketing site and not an install-first funnel.

## Goals

- Make Atelier understandable to a first-time developer visitor within a short page scan.
- Build trust by grounding the page in real product proof, concrete current capabilities, and honest maturity signals.
- Increase qualified downstream engagement by moving visitors from the landing page into the repository first, with docs and quickstart as secondary paths.
- Establish a consistent external product story that reduces naming drift and weak positioning across public surfaces.
- Create a reusable foundation for later docs, quickstart, release, and broader proof surfaces once the product matures.

### Business Objectives and Expected Outcomes

- Improve the project’s public legibility so new visitors do not have to infer the product from scattered repo artifacts.
- Position Atelier as a distinct native, local-first alternative to browser-shell or plugin-based agent workflows.
- Increase the number of high-intent visitors who inspect the repository and continue deeper into evaluation.
- Reduce the risk that cold visitors misclassify the project as unfinished, generic, or unclear.

### Milestones

- **MVP readiness:** the landing page presents a clear, trustworthy, screenshot-led product surface with a repo-first next step.
- **Evaluation validation:** qualified visitors move into the repository and supporting materials at a healthy rate.
- **Expansion readiness:** stronger docs, quickstart, or workflow-explainer surfaces are added only after the MVP proves its value.

## User Stories

### Primary Persona: Developer Evaluating Atelier

- As a developer visiting Atelier for the first time, I want to understand what the product is quickly so that I can decide whether it is worth deeper attention.
- As a developer comparing Atelier with other AI development tools, I want to see what makes it distinct so that I can judge whether it fits my workflow.
- As a skeptical developer, I want proof that the product is real and current so that I do not waste time on vague claims or aspirational marketing.
- As a technically curious visitor, I want a direct path into the repository so that I can inspect the source and project reality myself.

### Secondary Persona: Early Open-Source Adopter or Contributor

- As an open-source-minded visitor, I want the landing page to be honest about project maturity so that I can calibrate my expectations.
- As a possible contributor, I want the public story to line up with the repository so that I can understand the project’s direction without confusion.

### Edge Cases

- As a visitor who arrives from a social link or search result, I want a clear explanation without needing prior context.
- As a developer who is not ready to inspect the repo immediately, I want docs or quickstart visible as secondary paths so that I can continue evaluating in a lower-friction way.
- As a visitor cautious about AI-tool trust, I want to see transparent, inspectable language rather than overconfident claims.

## Core Features

### Critical

- **Trust-First Hero**  
  The hero must explain what Atelier is, who it is for, and why it is different, with language that prioritizes credibility over hype. It should make the native, local-first, transparent workflow stance visible immediately.

- **Real Product Proof**  
  The page must show a real screenshot of the product so visitors can anchor the story in something concrete. The proof should reinforce that Atelier is already a real app, not just a concept.

- **Concrete Capability Summary**  
  The page must describe what Atelier can do today using specific, current product facts such as persistent projects, project-scoped sessions, terminal tabs, restore and resume behavior, and agent-oriented workflows.

- **Repo-First Primary Path**  
  The page must give qualified visitors a clear next step into the repository. This is the primary downstream action because the current product maturity and source-build reality make repo inspection a better fit than a harder conversion ask.

### High

- **Secondary Evaluation Paths**  
  The page should expose docs and quickstart as visible but secondary next steps for visitors who want more guidance before opening the repository or who are ready to evaluate further.

- **Naming and Status Clarity**  
  The page should use a consistent public product name and make current maturity legible. It should reduce confusion caused by name drift or unclear status across the repo and related artifacts.

### Medium

- **Trust Reinforcement Cues**  
  The page should include lightweight cues that reinforce honesty and inspectability, such as links to source, clear wording about current scope, and alignment with actual product surfaces.

### Feature Interaction Principles

- The hero establishes relevance and credibility before any deeper action.
- The screenshot makes the trust claim concrete.
- The capability summary turns the screenshot into a believable product story.
- The repo CTA is the primary next step after understanding and trust are established.
- Docs and quickstart support evaluation without taking over the page’s primary job.

## User Experience

### First Contact Flow

1. A developer lands on the page from search, social, or a shared link.
2. The hero explains Atelier’s purpose and differentiator in a few seconds.
3. The screenshot confirms that the product is real and gives visitors visual grounding.
4. A concise capability section shows what the product can actually do today.
5. The visitor chooses a next step:
   - open the repository
   - continue into docs
   - inspect quickstart if they are already high intent

### Repeat Evaluation Flow

1. A returning visitor reopens the page after hearing about Atelier or seeing the repo.
2. The page quickly reaffirms the product story and trust posture.
3. The visitor uses the page as a stable orientation layer before going back into the repo or docs.

### Primary UX Principles

- **Clarity before persuasion** — the page should explain before it sells.
- **Trust before conversion** — the page should ask only for the next level of attention the project has earned.
- **Proof before abstraction** — concrete product evidence should appear early.
- **Small and scannable** — the MVP should feel quick to absorb rather than exhaustive.

### Onboarding and Discoverability

- The page should serve as the first coherent product overview outside the README.
- It should help visitors self-select quickly: right audience deeper in, wrong audience out early.
- The primary CTA should not trap visitors; it should move them into the repository with confidence and leave docs/quickstart clearly visible.

### Accessibility and Usability Expectations

- The page should remain easy to scan, readable, and navigable for keyboard and assistive-technology users.
- Visual hierarchy should make the hero, proof, capabilities, and next steps obvious.
- Copy should avoid ambiguous marketing language and keep user meaning explicit.

## High-Level Technical Constraints

- The MVP must stay aligned with current public product reality and avoid claims the repository cannot support.
- The page must work with the existing README, docs assets, and repository as primary supporting surfaces.
- The experience must reflect current product constraints honestly, including macOS-first positioning and early-stage maturity where relevant.
- The page should minimize trust friction by avoiding unnecessary data collection and by keeping external claims inspectable through source-linked surfaces.

## Non-Goals (Out of Scope)

- **Install-first conversion funnel** — The MVP will not center download or quickstart as the main ask.
- **Large marketing site** — The MVP will not include broad storytelling sprawl, deep comparison pages, or a full campaign surface.
- **Benchmark-based performance claims** — The page will not make “faster than” claims that the project cannot publicly prove.
- **Enterprise trust packaging** — The MVP will not add heavyweight enterprise, governance, or commercial trust surfaces.
- **Lead capture or gated forms** — The page will not prioritize email collection, waitlists, or sales-style flows.
- **Deep workflow tutorial content** — The MVP will not try to replace docs or a fuller product explainer.

## Phased Rollout Plan

### MVP (Phase 1)

**Included**
- Trust-first hero
- Real product screenshot
- Concrete current capabilities
- Repo-first CTA
- Secondary docs and quickstart paths
- Naming and maturity clarity

**Success criteria to proceed to Phase 2**
- Visitors move from the page into the repository at a meaningful rate.
- User testing shows that most qualified visitors can explain what Atelier is after a short scan.
- The page reduces confusion caused by weak public positioning.

### Phase 2

**Additions**
- More explicit workflow explanation
- Stronger supporting docs or getting-started path
- Better supporting proof such as richer visual walkthroughs
- Cleaner narrative around trust, maturity, and audience fit

**Success criteria to proceed to Phase 3**
- Repo visitors continue deeper into docs or evaluation instead of stopping at inspection.
- Users report that the page helps them decide whether Atelier fits their workflow.
- The product story remains clear without inflating scope or claims.

### Phase 3

**Longer-term expansion**
- Stronger quickstart or release-oriented evaluation path
- Broader proof hub with richer demos and supporting materials
- Additional public surfaces only if they strengthen the same trust-first story

**Long-term success criteria**
- The landing page becomes the default public entry point for Atelier.
- Qualified developer traffic consistently turns into deeper product evaluation.
- Expansion happens from proven need rather than imitation of competitor marketing patterns.

## Success Metrics

- **Repo visit rate:** at least **25%** of unique landing-page visitors open the repository.
- **Message clarity:** at least **80%** of tested users can accurately explain what Atelier is and why it is different after a brief scan.
- **Proof engagement:** at least **60%** of visitors reach or interact with the screenshot/capability section.
- **Docs continuation rate:** at least **15%** of unique visitors continue into docs after the landing page.
- **Quickstart start rate:** at least **5%** of unique visitors begin the quickstart path after visiting the page.
- **Qualified bounce control:** bounce rate for relevant developer traffic stays at or below **55%**.

## Risks and Mitigations

- **The page may build curiosity without enough downstream support**  
  Mitigation: keep the repository, docs, and quickstart visibly connected and treat the page as part of an evaluation system, not a standalone artifact.

- **Visitors may still be confused by naming drift or maturity gaps**  
  Mitigation: use one canonical public name on the page and make project status explicit and consistent.

- **Trust-first positioning may become vague or overly soft**  
  Mitigation: ground the message in real screenshot proof and specific current capabilities.

- **Repo-first may be too technical for some otherwise qualified users**  
  Mitigation: keep docs and quickstart present as secondary paths so visitors can choose their preferred depth.

- **Competitors may look more polished or complete**  
  Mitigation: position Atelier around a focused, credible wedge rather than trying to imitate broader marketing surfaces.

## Architecture Decision Records

- [ADR-001: Docs-First Trailhead Landing Page Scope for V1](adrs/adr-001.md) — Establishes a minimal, honest landing page instead of an install-first marketing site.
- [ADR-002: Trust-First Repo-Oriented Landing Page PRD Scope](adrs/adr-002.md) — Sets trust, screenshot-led proof, and repo-first evaluation as the MVP product direction.

## Open Questions

- What should be the single canonical public product name across the repo, landing page, and future docs?
- Should the repo CTA remain primary after the first release, or should docs become primary if user behavior shows inspection alone is not enough?
- Is one screenshot enough proof for MVP, or will a short visual walkthrough be necessary sooner?
- When should the project shift from repo-first evaluation toward a stronger quickstart or release-first path?
- How should the page communicate open-source status until the project license is finalized?
