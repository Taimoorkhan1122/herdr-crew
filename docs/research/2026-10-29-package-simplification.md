# Package simplification interview

Status: interview complete; product design approved. The user's selected guidance/skill standards are researched and incorporated in the implementation plan.

## User objective

Make herdr-crew simpler and plug and play, with one main skill entry point and an `agents/` directory. Named examples are `crew-lead`, `crew-manager`, `crew-member`, and `driver`. The original Persona.md/memory.md suggestion has been revised: the user explicitly removed memory.md and wants specification-guided agent configuration. Include common lifecycle hooks, especially context limits and task completion. Keep the existing canonical `SKILL.md` spelling unless explicitly changed.

## Current baseline

At the start of the interview, `main` is clean at `90876983460bd0b449b495b4c7fdf7e1aa0bd897`. The older checkpoint's commit and ahead/behind statements are historical snapshots.

The main entry point is already `SKILL.md`. Permissions and authority live in `ranks/`; jobs and stackable domain expertise live in `personas/`. This separation is an accepted decision in [ADR 0004](../adr/0004-ranks-and-personas.md). A simpler layout must explicitly decide how that boundary is represented.

The [README](../../README.md) describes manual installation links, dependencies, and Claude/OpenCode support. Claude has automatic crew context warnings; OpenCode currently uses explicit handoff instructions without those automatic warnings. The [feature reference](../features.md) describes hooks and completion. These are current-source constraints, not a commitment to preserve the layout.

## Agreed direction: project ownership

The user clarified that the herdr-crew skill installs the baseline into `.herdr-crew/` in the target project. Subsequent configuration and agents are project-specific. Users may extend existing agents or create new ones. [ADR 0020](../adr/0020-project-owned-crew-baseline.md) records this ownership decision; it does not mark the full design approved or implemented.

The latest user answers, recorded in [ADR 0021](../adr/0021-specification-only-project-agents.md), settle these additional points:

- Remove memory.md; keep agent specification-guided configuration.
- Preserve project customizations when setup runs again; baseline upgrades are explicit.
- Target Claude and OpenCode first and state their hook capabilities.
- Completion hooks report worker results to coordinators; review controls task acceptance.
- Persona updates belong to root configuration; agent updates belong to project configuration. The user's subsequent yes-to-all confirms root means the installed skill's shared baseline; projects receive updates explicitly.
- Prefer promoting/replacing ranks/ with agents/ and filling the remaining gaps, to reduce work. This is a reuse direction, not approval of a concrete implementation.

## Source findings

Read-only inspection confirmed the following at the baseline commit:

- Rank files are executable policy inputs, not just prose. Claude selects `crew-<rank>`, and OpenCode derives its policy from rank frontmatter. Persona discovery, configuration validation and the dependency installer also scan the existing paths directly. Moving folders requires updating these callers together. See [launcher](../../bin/crew), [runtime configuration](../../lib/agent-config.sh), and [dependency installer](../../bin/install-skills).
- Claude's `SessionStart` sets up the session environment. `PostToolUse` and `UserPromptSubmit` call [ctx-guard](../../bin/ctx-guard), which warns once per session at a default 135K tokens and always returns success. It asks for handoff; it does not enforce stopping or restart. OpenCode currently has no equivalent automatic crew context warning.
- There is no task-completion hook. Workers explicitly report through `mark`; the [Manager](../../ranks/crew-manager.md) checks task evidence and, for development, reviewer approval before accepting completion. A runtime stop is a different event from accepted task completion.
- Runtime briefs, metadata and handoffs are already separated from the installation and keyed to project/agent state. Task history lives in tsk. The user removed the proposed bundled memory file; existing runtime evidence is a separate concern.
- Reinspection for the ranks-to-agents proposal confirms the current rank Markdown already holds tools, permissions, model/effort defaults and instructions. It is reusable as an agent specification. However, the launcher/parser hard-codes four ranks, and native policy and lifecycle routing depend on those identities. A new project agent name is not sufficient to establish authority. Current project JSON only accepts known role keys and runtime/model/effort values; new names, instructions and hooks are not supported there today.
- Current hooks are generated inline by the launcher, rather than read from agent metadata. Worker worktrees share primary-project settings. Restart uses the saved brief and resolved runtime selection, so current restart does not automatically reload edited instruction bodies. Reuse must make these contracts explicit rather than assume directory changes implement them.

## Alternatives and corrections

The earlier memory/template/instance-memory recommendations are superseded by removing memory.md. The user did not accept copying an agent folder as the extension mechanism: instead, they distinguished root persona updates from project agent updates. Do not infer file inheritance, copy behavior, automatic root-to-project propagation, or broader runtime support from these answers. Reuse existing rank specifications instead of assuming a new agent framework is required.

## Current decision frontier

The user accepted the previous four recommendations together: root is the installed baseline, new named agents select an existing permission profile, context uses warning/agent-written handoff/coordinator restart, and worktrees share primary-project configuration. [ADR 0022](../adr/0022-shared-baseline-and-project-agent-profiles.md) records these decisions.

The user also accepted all five operational proposals: automatic baseline bootstrap on first use with prerequisite reporting; explicit selected upgrades without automatic merges; non-destructive migration of legacy assignments; saved-definition restarts/new-launch-only config changes; and per-session hooks with explicit fallbacks for unsupported runtime events. [ADR 0023](../adr/0023-project-bootstrap-upgrade-and-session-contracts.md) records these decisions. The [reconciled design](../superpowers/specs/2026-10-29-project-agent-baseline-design.md) captures the complete agreement.

## Interview closure

The frontier is empty. The written design covers file responsibilities, existing-profile authority, persona snapshots, explicit upgrades, hook capabilities/fallbacks, existing context/handoff behavior, review acceptance, migration, compatibility and disposable-project acceptance criteria. No memory design is included. The user then approved the rest of the design and requested researched agent formatting, explicitly naming AGENTS.md, Agent Skills and its evaluation/script guides.

An independent builder-readiness read identified no additional consequential user questions beyond the five operational proposals, all now answered. [The standards research](2026-10-29-agent-specifications.md) resolves Persona.md to agents/<name>/AGENTS.md plus local JSON metadata and native adapters. [ADR 0024](../adr/0024-open-guidance-and-skill-standards.md) records this distinction. The [implementation plan](../superpowers/plans/2026-10-29-project-agent-baseline.md) includes actual skill evaluations and agentic-script requirements. No commit, push, live-fixture or installation authorization is inferred.

## Scope and verification

This session authorizes the interview and its documentation. No runtime changes, installations, crew launches, commits, publication or cleanup have been requested. Source inspection and documentation checks do not establish hook or live-agent acceptance. Existing unresolved runtime gaps remain in [STATE.md](../STATE.md).
