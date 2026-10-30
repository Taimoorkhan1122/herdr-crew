# 0021. Keep project agents specification-only and preserve customizations

- Status: Accepted (design decisions; implementation pending)
- Date: 2026-10-29

## Context

The baseline-ownership interview initially included a memory.md file for each agent and left update behavior, runtime scope and completion semantics undecided. The user removed memory from the proposal and accepted explicit baseline updates, Claude/OpenCode support and review-gated task acceptance.

## Decision

Agent configuration is specification-guided. Do not add memory.md or a new agent memory subsystem. This supersedes only ADR 0020's inclusion of memory.md; its project-ownership boundary stands. Existing runtime handoff/task evidence remains distinct from this configuration proposal.

Repeated setup preserves project customizations. Baseline upgrades are explicit rather than silent replacements. The first version targets Claude and OpenCode, with runtime hook capabilities stated explicitly. A worker completion hook reports the worker result to its coordinator; review still determines task acceptance.

The user distinguishes persona updates to root configuration from agent updates to project-level configuration. The precise meaning of root remains to be clarified before assigning paths or designing precedence. The user also proposed promoting the existing ranks/ definitions to agents/ to reduce work; reuse is the preferred direction, while the exact layout, naming and preservation of authority boundaries remain under discussion.

## Consequences

Configuration stays focused on agent specifications. There is no new writable-memory lifecycle to implement. Existing rank specifications and native runtime adapters are candidates for reuse instead of rebuilding permission policy. Project customization, baseline upgrade, hook and worktree behavior still need a concrete design and acceptance scenario before implementation.
