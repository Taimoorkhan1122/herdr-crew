# Project-owned agent baseline

Status: product design approved by the user; agent representation resolved using the user's selected AGENTS.md and Agent Skills standards. Implementation planning authorized. Not implemented.

## Intent

Make herdr-crew plug and play: the installed SKILL.md bootstraps a target project into .herdr-crew/, then uses that project's agents and configuration. Users can customize existing agents and add new ones through specification-guided configuration. Keep existing commands, permission enforcement, task review, handoff evidence and Bash 3.2 compatibility.

## Accepted boundaries

- Root configuration is the installed skill's baseline. Persona updates change that baseline; agent updates change the target project only. Root updates reach existing projects through explicit upgrades.
- Promote existing ranks/ definitions into agents/ and reuse their metadata/instructions and native runtime adapters. Custom agent names select existing Lead/Manager/Member/Inspector permission profiles.
- No memory.md or new memory subsystem. Existing tsk evidence, saved briefs and handoffs remain.
- Worker worktrees share configuration from their primary checkout, including uncommitted configuration edits.
- Setup preserves customization. Upgrades are explicit. Initial runtimes are Claude and OpenCode; capability differences must be visible.
- Context handling warns the agent to write a handoff and asks its coordinator to arrange restart. Worker completion reports a result; review controls task acceptance.

See ADRs [0020](../../adr/0020-project-owned-crew-baseline.md), [0021](../../adr/0021-specification-only-project-agents.md), [0022](../../adr/0022-shared-baseline-and-project-agent-profiles.md), [0023](../../adr/0023-project-bootstrap-upgrade-and-session-contracts.md) and [0024](../../adr/0024-open-guidance-and-skill-standards.md).

## Approach and alternatives

The chosen direction reuses existing rank Markdown, persona composition, configuration resolution and native adapters. Move definitions into the requested agent layout and make project-owned definitions discoverable. A new agent/permission framework would duplicate established contracts and increase work. A directory rename alone would leave hard-coded profile identities, known-role validation, native agent names and lifecycle routing unresolved. Neither alternative satisfies the chosen scope.

## Layout

The user selected [AGENTS.md](https://agents.md/) for agent guidance and the [Agent Skills specification](https://agentskills.io/specification) for the main skill package. Agent guidance is plain Markdown, without an invented frontmatter schema. Small local JSON sidecars preserve current metadata with jq-based validation. See [the primary-source research](../../research/2026-10-29-agent-specifications.md).

```text
installed skill/
  SKILL.md
  agents/
    crew-lead/{AGENTS.md,agent.json}
    crew-manager/{AGENTS.md,agent.json}
    crew-member/{AGENTS.md,agent.json}
    crew-inspector/{AGENTS.md,agent.json}
    driver/{AGENTS.md,agent.json}
    navigator/{AGENTS.md,agent.json}
    ... other existing jobs
  personas/                 # reusable domain expertise
  teams/
  hooks/                    # common lifecycle hook implementations
  bin/ and lib/             # existing launcher and native adapters

target project/
  .herdr-crew/
    config.json             # project settings and baseline provenance
    agents/<name>/AGENTS.md
    agents/<name>/agent.json
    personas/               # project snapshot of baseline domain guidance
    teams/
    hooks/
```

Promote rank instruction bodies and existing job persona bodies into AGENTS.md, preserving metadata in agent.json. Keep permission-profile identity distinct from agent name. Root domain-persona guidance remains reusable and stackable. Setup materializes the project baseline, so launched project agents do not silently load updated root persona bodies. No runtime state or credentials are copied into the baseline.

agent.json is local configuration, not an AGENTS.md schema. Reserve crew-lead/crew-manager/crew-member/crew-inspector for the existing profile definitions. Job definitions name their existing profile and carry name/description plus current skills/AXI/default-effort metadata. Tool allowlists, disallowed tools and native permission modes remain profile metadata. Job definitions cannot widen their chosen profile's authority. Existing runtime/model/effort overrides remain in config.json rather than duplicated into job metadata.

The launcher explicitly reads and supplies the selected agent/profile guidance. It does not assume automatic discovery of .herdr-crew/agents/ from the source worktree, load every agent's instructions, or replace the target repository's applicable AGENTS.md instructions.

config.json relocates existing runtime/model/effort settings rather than introducing a competing configuration layer. It must not duplicate authoritative agent instructions. Preserve the current precedence and supported model/variant validation.

## Guided configuration

The skill explains and guides specification creation/editing. Existing agents can be customized; new names must be valid, unique, and select a known permission profile. Validate all referenced definitions before starting tasks, worktrees or panes. An unknown name or invalid profile fails explicitly. Internal historical rank identifiers may remain to preserve adapter behavior; users interact with named agents.

Editing a root persona targets the installed baseline; editing a project agent targets the primary project's configuration. These operations must not be confused. A project-local configuration or guidance edit must not modify the installed baseline.

## Accepted operational behavior

The user accepted all five proposals in this round. [ADR 0023](../../adr/0023-project-bootstrap-upgrade-and-session-contracts.md) records their rationale and consequences.

1. First skill use bootstraps a missing .herdr-crew/ with the baseline automatically, checks prerequisites, and offers guided customization. Missing runtimes/tools are reported with setup steps rather than installed automatically. Re-running setup retains existing files. Pure help/version/inspection commands remain read-only.
2. Upgrade presents proposed changes for user selection; customized files are never silently overwritten. Track the installed baseline version so the proposal identifies its source. Do not introduce automatic text merging in the first version.
3. On a project with existing .herdr-crew.json, import valid assignments when bootstrapping, retain the old file unchanged, and use .herdr-crew/ thereafter. If both formats already exist, use the new directory and explicitly report the legacy file; do not silently combine them.
4. Configuration/persona edits affect new launches. Restarts retain saved definitions, native policy, runtime/model selection and handoff continuity; adopting changed definitions requires an explicitly fresh launch.
5. Register hooks per crew session, preserving the current lack of global hook installation. Provide context-limit and completion behaviors through each runtime's supported integration. When a runtime cannot provide the event, report the capability gap and use explicit handoff/result reporting; do not imply equivalent automatic coverage.

## Hook semantics

Context notifications are advisory and do not establish a hard token or billing cap. The agent records evidence and remaining work before restart. Completion reports carry the agent/task identity, result status, evidence pointer and verification limits; a stop/exit without a valid result is not accepted completion. Repeated notifications must not duplicate acceptance or trigger repeated restart actions. Preserve task history and pending review on failure.

Common hooks do not authorize publication, merges, destructive cleanup or additional task scope. Keep profile permissions authoritative. Exact supported runtime events must be verified before implementation; the current source only wires Claude context hooks and explicit status reporting.

## Compatibility and scope

Retain current launch/configure/team/status/mark/handoff/restart contracts and existing rank@job syntax as compatibility forms. Add named project-agent discovery without rebuilding teams or adopting another task store. Keep task evidence in tsk and current runtime state separate from shareable project configuration.

Root/project permissions must remain enforceable by the native adapters. No new permission profile, background daemon, memory service, generic plugin framework or runtime beyond Claude/OpenCode is included. Hook capability reporting is part of acceptance; current missing OpenCode automatic context behavior is a baseline gap, not proof that the runtime can never support it.

## Skill packaging, scripts and evaluation

Follow the [Agent Skills specification](https://agentskills.io/specification) for SKILL.md metadata, skill naming and portable references. Keep established bin/ and lib/ locations; extra package directories are permitted. The main entry point stays short and routes to the actual installed scripts and project-owned definitions.

Apply the [agentic-script guide](https://agentskills.io/skill-creation/using-scripts#designing-scripts-for-agentic-use) to new setup/upgrade operations: flags or stdin instead of TTY prompts; concise help; actionable errors; structured data separate from diagnostics; idempotent retries and an honest no-write preview. Keep existing command stdout/exit contracts and the explicit human configure wizard. Do not add automatic dependency installation or a new script runtime.

Apply the [evaluation guide](https://agentskills.io/skill-creation/evaluating-skills): start with three realistic workflow cases, compare isolated candidate runs with the previous skill, and assess observed artifacts/actions with evidence. Record available time/token measurements honestly. Do not manufacture benchmark results or mistake shell fixtures for model-driven skill evals. A fixture-based evaluation mode can stub integrations; real crew launches remain separately authorized acceptance.

## Acceptance criteria for the eventual implementation

1. A fresh disposable target project can receive the baseline through the agreed first-use flow. Repeated setup leaves customized files intact.
2. Project agent edits leave the installed baseline and another project unchanged. A custom agent with an existing permission profile is discoverable/configurable/launchable through the appropriate existing team flow; invalid names/profiles fail before launch resources.
3. A linked worker worktree reads its primary project's project configuration, including uncommitted edits. Ambiguous ownership fails conservatively.
4. Existing valid runtime assignments migrate without data loss under the agreed migration flow. Unrelated files and legacy configuration are preserved.
5. Root persona updates affect new project bootstrap or an explicit project upgrade, not an existing project's next launch without that upgrade.
6. Each supported runtime has verified native policy and an accurate hook capability report. Context handling preserves evidence/handoff flow; completion notification cannot bypass review. Unsupported hook events use explicit handoff/result reporting, with no false automatic-coverage claim. Unsupported runtimes remain refused.
7. Restart/config-edit behavior matches the selected contract. Failed or repeated hooks do not produce accepted completion, lose evidence or repeatedly restart an agent.
8. Meaningful failing regressions precede source changes; required syntax, hermetic, real-Git and agent-config suites pass. Live acceptance uses a disposable fixture only with authorization and is reported separately from automated coverage.
9. Main skill packaging follows Agent Skills, selected agent guidance uses AGENTS.md, and the local sidecar/native-policy distinction is documented. Three initial evaluation prompts and expected outcomes are saved; actual runs compare the candidate with the previous skill in clean fixture contexts, with evidence and unrun cases explicit.

## Known limits

An independent read-only builder-readiness review found the five operational proposals covered the remaining consequential user decisions; it did not identify another required interview question. The user subsequently accepted all five. The review did not validate source, runtime capabilities or live behavior.

Primary-source agent/skill research is complete for the user's selected standards. No runtime capability experiment, implementation, migration run, model-driven eval or live acceptance has run for this design. Existing source-review/restart gaps in [STATE.md](../../STATE.md) remain open; reuse is not evidence that they are solved. The user approved the product design and supplied the standards qualification; the next artifact is the implementation plan.
