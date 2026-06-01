# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State

## Shared Decisions

## Shared Learnings
- SwiftPM raw code coverage includes build/dependency artifacts in this repo. For PRD task coverage gates, use first-party source coverage from `xcrun llvm-cov report ... -ignore-filename-regex='(^|/)\\.build/|(^|/)Tests/'` unless a stricter repository gate is introduced.

## Open Risks

## Handoffs
