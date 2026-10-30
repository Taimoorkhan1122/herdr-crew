# 0022. Separate shared baseline updates from project agent configuration

- Status: Accepted (design boundaries; implementation pending)
- Date: 2026-10-29

## Context

The user clarified root persona updates versus project agent updates, and proposed promoting ranks/ to agents/ to reuse existing specifications. Custom agent names must remain compatible with the current native permission boundaries and worker worktree model.

## Decision

Root means the installed skill's shared baseline. Persona updates change that root configuration; agent updates change only the target project's `.herdr-crew/`. Existing projects receive root changes through explicit upgrades rather than immediate propagation.

Custom agents select one of the existing Lead, Manager, Member or Inspector permission profiles. Their identity, persona and runtime settings are project-specific. Reuse existing rank specifications and native permission enforcement instead of creating a new permission framework.

All linked worker worktrees use the primary project's `.herdr-crew/` configuration. Context-limit handling retains the warning, agent-written handoff and coordinator-arranged restart flow. Removing memory.md does not remove existing task evidence or runtime handoffs.

The user explicitly answered yes to all four of these interview proposals. The full design, operational details and implementation remain pending.

## Consequences

Shared template maintenance and project customization have distinct destinations. Named agents can vary without treating their names as permission identities. Reuse reduces the scope of policy changes, although parser/discovery/native naming/lifecycle callers still need to distinguish profile from agent identity. Existing project-specific sharing and handoff contracts remain relevant.
