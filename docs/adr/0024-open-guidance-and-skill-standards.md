# 0024. Follow AGENTS.md for agent guidance and Agent Skills for the main skill

- Status: Accepted (user-selected standards; implementation pending)
- Date: 2026-10-29

## Context

The user approved the project-baseline design except for the proposed Persona.md representation, requesting research into open specifications. They identified https://agents.md/ and https://agentskills.io/specification as the intended standards, then supplied the Agent Skills evaluation and agentic-script guides.

## Decision

Replace the proposed `agents/<name>/Persona.md` with `agents/<name>/AGENTS.md` containing ordinary behavioral guidance. Keep machine-readable metadata in a small `agent.json` beside it, validated with the existing jq dependency. That sidecar is a herdr-crew convention, not part of the AGENTS.md standard. Existing project runtime/model/effort assignments remain in `.herdr-crew/config.json`, with their existing precedence.

The main `SKILL.md` follows the Agent Skills specification. Retain existing bin/ and lib/ paths: the specification permits extra directories and does not require moving working scripts into its optional example layout.

Explicitly supply only the selected agent's guidance through the native adapter/brief while respecting the applicable source repository's instruction scope. A per-agent AGENTS.md outside the source worktree's ancestor path is not an automatic role-registration mechanism. Native Claude/OpenCode policy remains responsible for tool authority.

Use the linked evaluation guide for a small, isolated comparison against the previous skill or no-skill baseline, with evidence-backed results. Use the script guide for flag/stdin inputs, help, actionable failures, structured new-command output and retry-safe behavior. Preserve established Bash 3.2 and CLI contracts. No new framework or YAML parser is introduced.

This settles the user's researched representation qualification. The approved product boundaries remain unchanged. The implementation plan is a separate execution handoff; no runtime change or eval result is implied.

## Consequences

Open-standard instructions, local metadata and native runtime enforcement remain distinct. Removing YAML frontmatter from agent guidance makes the current scalar frontmatter parser unsuitable for agent metadata; callers must migrate together to jq accessors. The main skill and its evaluation cases can be assessed without claiming universal agent-file interoperability.

Primary sources and specific runtime compatibility findings are recorded in [the research note](../research/2026-10-29-agent-specifications.md).
