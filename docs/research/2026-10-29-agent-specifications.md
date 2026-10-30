# Agent definition specifications and native runtime formats

Checked: 2026-10-29. Scope: primary-source research for the proposed `agents/<name>/Persona.md` layout. The user subsequently identified both required standards: [AGENTS.md](https://agents.md/) and [Agent Skills](https://agentskills.io/specification). The rest of the project-baseline design is approved. No runtime, installation or conformance test was run.

## Finding

Follow the user's selected [AGENTS.md format](https://agents.md/) for behavioral guidance: replace the proposed `Persona.md` with `agents/<name>/AGENTS.md`. Keep structured agent identity, permission profile and runtime configuration separate. AGENTS.md is an open Markdown instruction format, not a named-agent registration schema or native permission system.

Follow the selected [Agent Skills specification](https://agentskills.io/specification) for the main `herdr-crew/SKILL.md` package. The two standards cover different responsibilities; neither replaces native runtime permission enforcement.

The per-agent folder is herdr-crew's organization of the project baseline. A file under `.herdr-crew/agents/<name>/AGENTS.md` does not automatically govern a source-code worktree elsewhere. The launcher must explicitly supply only the selected agent's guidance while preserving the target repository's applicable instruction scopes. This discovery implication follows from AGENTS.md's root/nested-directory model and the distinct native runtime registration formats below; it is not an additional requirement imposed by the AGENTS.md format.

## Chosen standards and excluded alternatives

| Source | Documented scope | Relevance to herdr-crew |
| --- | --- | --- |
| [AGENTS.md](https://agents.md/) | Repository instructions and context for coding agents; ordinary Markdown with no required schema. | Keep project guidance separate from named runtime-agent definitions. It does not define tool permissions, model settings or named-agent registration. |
| [Agent Skills specification](https://agentskills.io/specification) | The user's second selected standard: a skill directory requires `SKILL.md`, with YAML frontmatter and Markdown instructions. | Governs the main herdr-crew skill package; it does not define named-agent native policy. |
| [Oracle Open Agent Specification](https://oracle.github.io/agent-spec/26.1.2/agentspec/language_spec_26_1_0.html) | A component language for agents, flows, tools and their semantics; representations can be serialized to JSON/YAML and consumed by supporting runtimes. | A different interchange/execution contract, rather than a coding-agent Markdown filename convention. Adopting it requires choosing and validating a real component representation and execution integration. |
| [Prime Vector Open Agent Spec, formal specification](https://raw.githubusercontent.com/prime-vector/open-agent-spec/main/spec/open-agent-spec-1.6.md) | A separate YAML document format with typed tasks, prompts, engine/model configuration and obligations for conforming runtimes. The [project README](https://github.com/prime-vector/open-agent-spec) describes its `oa` runner. | Distinct from Oracle's similarly named project. Adding OA execution/schema support would expand this launcher change; renaming a Markdown file does not implement it. |
| [AGENT.md informational proposal](https://github.com/agentmd/agent.md) | A July 2025 repository-guidance proposal, with project conventions, commands and directory scoping. | Another guidance document, not a cross-runtime schema for named worker policy. Do not confuse the singular filename with native agent definition files. |

The user selected AGENTS.md and Agent Skills, not Oracle Agent Spec or Prime Vector OA. The similarly named formats above explain the original ambiguity only; no adoption decision for them remains open. Do not add their SDKs, runners or schemas to this work.

## Main skill requirements

The main `SKILL.md` requires YAML frontmatter followed by Markdown. Its `name` must be 1-64 lowercase alphanumeric/hyphen characters, match the skill directory, and have no leading, trailing or consecutive hyphens. `description` must be non-empty and at most 1024 characters. Retain `name: herdr-crew` in the `herdr-crew` package. Optional fields include `license`, `compatibility`, `metadata` and experimental `allowed-tools`; the last is not portable native permission enforcement. [Agent Skills specification](https://agentskills.io/specification)

Additional files/directories are permitted. `scripts/`, `references/` and `assets/` are optional organization conventions, so compliance does not require moving existing `bin/` or `lib/`. Keep relative references and disclose supporting material only when needed. [Agent Skills specification](https://agentskills.io/specification)

## Additional practical guides selected by the user

These are creator guides, separate from the two normative document formats above.

[Evaluating skill output quality](https://agentskills.io/skill-creation/evaluating-skills) recommends starting with 2-3 realistic cases, including a boundary case, each with a prompt, expected outcome and any input files. Run each in fresh isolated context with the skill and without it, or against a frozen previous version. Keep outputs and evidence-backed assertion results; record measured duration/tokens when available. Use mechanical checks for objective properties and human review for subjective quality. For herdr-crew, cover baseline bootstrap, project-specific customization, and a malformed/conflicting configuration. Store proposed eval inputs separately from run results. Mark unrun cases as unrun; do not invent grades, timing or improvement claims.

[Designing scripts for agentic use](https://agentskills.io/skill-creation/using-scripts#designing-scripts-for-agentic-use) calls for noninteractive flags/environment/stdin, concise help, errors describing corrective action, structured stdout with diagnostics/progress on stderr, retry-safe operations, input validation and dry-run support. Apply these to new bootstrap/upgrade/configuration paths while preserving this repository's Bash 3.2, existing command names, documented exits and output contracts. Existing human-facing wizards may remain, but agent routes must not wait for TTY input. Use current helpers and jq; no script relocation or unconditional dependency installation follows from the guide's examples.

## Claude Code native definition

[Claude Code's subagent reference](https://code.claude.com/docs/en/sub-agents) specifies YAML frontmatter followed by a Markdown system prompt. `name` and `description` are required. Configuration includes `tools`, `disallowedTools`, `model`, `permissionMode`, `skills`, `hooks` and `effort`, among other supported fields. Unknown frontmatter fields are ignored, so crew metadata must be validated by herdr-crew rather than assumed enforced by Claude.

Native locations include project `.claude/agents/` and user `~/.claude/agents/`; these directories are scanned recursively. Agent identity comes from frontmatter `name`, not the filename. A file at `.claude/agents/driver/Persona.md` can therefore have identity `driver`, but the proposed `.herdr-crew/` location is not a documented auto-discovery root. Session-local JSON definitions via `--agents` are also documented. Use the verified registration mechanism appropriate to the installed version; do not assume copying a file into an arbitrary folder registers it. [Source](https://code.claude.com/docs/en/sub-agents)

## OpenCode V2 native definition

[OpenCode V2's agent reference](https://opencode.ai/v2/docs/agents/) documents `.opencode/agents/<name>.md` and `~/.config/opencode/agents/<name>.md`. A nested filename contributes to identity: `team/reviewer.md` becomes `team/reviewer`. Consequently, copying `driver/Persona.md` into the native directory would produce a nested identity rather than the intended simple `driver` identity.

The Markdown body becomes `system`; frontmatter accepts agent configuration fields such as `description`, `mode`, `model` and `permissions`. JSON/JSONC definitions live under plural `agents`. Crew panes are primary sessions, so the adapter must choose primary-capable definitions rather than blindly copy documentation examples marked `mode: subagent`. Models use `provider/model` with an optional `#variant`. The default-agent setting does not replace an existing session's stored selection. [Source](https://opencode.ai/v2/docs/agents/)

V2 permissions are ordered `{action, resource, effect}` rules, with the last matching rule winning. V1 spellings `permission`, `bash` and `task` are replaced by V2 `permissions`, `shell` and `subagent`. Preserve explicit native enforcement; prose such as “read-only” is not a substitute. [OpenCode V2 permissions](https://opencode.ai/v2/docs/permissions/)

## Representation following the selected standards

Use plain AGENTS.md guidance, the Agent Skills main entry point, and existing native adapters for registration and authority. This follows the user's two selected document formats; it is not a claim that either standard defines native runtime policy or conforms to Oracle Agent Spec/Prime Vector OA.

The proposed source layout is `agents/<name>/AGENTS.md`, mirrored under the target project's `.herdr-crew/agents/<name>/AGENTS.md`. Keep main `SKILL.md` under the actual Agent Skills convention. Keep a small `agent.json` beside each AGENTS.md for machine-readable identity/profile and configuration references, using the project's existing jq-based validation. That sidecar is a local herdr-crew convention, not a field or filename mandated by AGENTS.md. The parent design/plan owns its exact fields and precedence.

Neither `.herdr-crew/` nor the AGENTS.md guidance filename registers a named native agent. Resolve the sidecar, selected guidance, applicable repository instructions and approved permission profile; pass the result through the existing runtime-specific adapter. Do not copy a per-agent tree unchanged into both native discovery locations and assume identical identity or policy.

Keep the schema small:

- Keep AGENTS.md focused on the selected agent's behavioral guidance, using ordinary Markdown; do not turn it into an invented YAML policy schema.
- Keep name/description, existing crew profile association and persona/skill references in validated herdr-crew metadata. Choose one of the existing Lead/Manager/Member/Inspector profiles; a custom name must not imply a new authority level.
- Keep existing project runtime/model/effort assignments authoritative under the approved precedence. Do not duplicate them into another competing source of truth merely to make files look portable.
- Resolve a definition once for launch, then generate the selected runtime's actual native policy/definition. Claude tool/permission fields and OpenCode V2 ordered rules are separate adapter outputs. Validate sidecar metadata with jq rather than trusting ignored or unknown runtime fields.
- Pin saved resolved definitions and policy for restart, as already approved. Root persona edits reach projects only through explicit baseline upgrades.

AGENTS.md defines guidance discovery and scoping; agent.json defines herdr-crew configuration; native adapters enforce runtime policy. These are separate responsibilities, not a new universal agent schema. No new YAML parser is needed for this representation.

## Implications for implementation planning

1. Decide and document the source path separately from native discovery/registration; update all lookup, installer, configuration-validation, team-composition and fixture callers together.
2. Add a regression proving a project-customized named agent is the definition actually registered/launched, rather than the global bundled rank selected under the same name.
3. Check duplicate/mismatched identities, invalid profile associations, unknown sidecar fields, malformed JSON and missing AGENTS.md before creating launch resources. Prove the agent receives only its selected role guidance while the target repository's AGENTS.md remains applicable. Do not accidentally inject the Lead and every worker's guidance into each session.
4. Verify equivalent profile restrictions in each runtime's native output, especially inspector edits and worker publication/merge restrictions. Do not test only prompt wording.
5. Recheck installed runtime versions and official schemas before changing adapters. Current documentation is not proof that an older installed CLI accepts every documented field or registration option.
6. Include a small realistic skill-evaluation corpus and a documented isolated baseline-comparison procedure. Keep agent-output evaluation separate from hermetic launcher tests and live fixture acceptance; report which checks actually ran.

## Limits

The user resolved the original terminology ambiguity by naming AGENTS.md and then explicitly adding the Agent Skills specification and its evaluation/script guides. This note follows those choices. No live agent, skill evaluation, billing/model request, package installation, SDK integration, runtime-discovery experiment or cross-runtime conformance check was performed. Only this research note was written by the research helper. Native registration and permission preservation still require implementation checks.
