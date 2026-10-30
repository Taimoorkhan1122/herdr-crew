# 0023. Bootstrap projects while preserving configuration and active sessions

- Status: Accepted (operational design; implementation pending)
- Date: 2026-10-29

## Context

Project-owned configuration needs predictable first-use, upgrade and migration behavior. Existing handoff restarts preserve saved runtime settings, and automatic lifecycle integrations differ by runtime. The user accepted all five operational proposals presented with the working design.

## Decision

On first skill use, bootstrap a missing `.herdr-crew/` baseline and offer guided customization. Report missing dependencies with setup instructions instead of installing them automatically. Repeated setup preserves existing files. Pure help, version and inspection paths retain their read-only behavior.

Upgrades present proposed changes for user selection; customized files are preserved unless explicitly selected for replacement. Do not automatically merge local edits. Identify the baseline version used by the project.

Import valid legacy `.herdr-crew.json` assignments into the new project configuration during bootstrap, retaining the old file unchanged. The new directory is authoritative afterwards. If both forms already exist, report the legacy file and use the new directory rather than silently combining them.

Configuration changes apply to new launches. Handoff restarts retain saved definitions, native policy and runtime/model settings; adopting edited definitions requires a fresh launch.

Hooks are registered per crew session, not globally. Use supported native events for context/completion behavior. When an event cannot be supported, report the capability gap and use explicit handoff/result reporting without claiming equivalent automatic coverage.

## Consequences

First use can create project configuration without manual linking. Shared project edits and explicit baseline updates remain separate from an active agent's saved session. Preserving legacy files and avoiding automatic merging reduces migration risk. Runtime capability verification and the complete written design still precede implementation; acceptance of these choices is not live evidence.
