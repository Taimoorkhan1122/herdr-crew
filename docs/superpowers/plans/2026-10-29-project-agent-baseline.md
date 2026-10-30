# Project-Owned Agent Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bootstrap customizable project agents under .herdr-crew/, using AGENTS.md guidance, Agent Skills packaging, and the existing Claude/OpenCode permission adapters.

**Architecture:** Reuse existing rank/job instruction bodies as AGENTS.md files and move their metadata into small local JSON sidecars. Resolve project definitions in the primary checkout, then register the resolved profile through native runtime adapters. Keep project bootstrap/upgrades separate from active session snapshots and existing tsk evidence.

**Tech Stack:** Bash 3.2, existing jq/git/rg/shasum dependencies, Herdr/tsk, Claude Code and OpenCode 2. No new runtime/parser/framework dependency.

**Spec:** [Approved design](../specs/2026-10-29-project-agent-baseline-design.md); [selected-standard research](../../research/2026-10-29-agent-specifications.md).

## Global Constraints

- No memory.md or new memory subsystem. Existing tsk evidence, saved briefs and handoffs remain.
- Worker worktrees share configuration from their primary checkout, including uncommitted configuration edits.
- Setup preserves customization. Upgrades are explicit. Initial runtimes are Claude and OpenCode; capability differences must be visible.
- Job definitions cannot widen their chosen profile's authority.
- Configuration/persona edits affect new launches. Restarts retain saved definitions, native policy, runtime/model selection and handoff continuity; adopting changed definitions requires an explicitly fresh launch.
- Pure help/version/inspection commands remain read-only. Preserve existing commands, output, exit codes and Bash 3.2 compatibility; new interfaces use flags/stdin and documented results.
- No publication, automatic dependency installation, real crew launch, destructive cleanup or Git commit without the user's separate authorization. Verification checkpoints below are not commit authorization.

## Review Focus

1. Primary checkout and linked worktrees with spaces or separate Git metadata must read/write the same project configuration; ambiguous ownership must fail before mutation. Covered in Tasks 2/3.
2. Broken symlinks, partial setup, JSON streams and concurrent initialization must preserve original files and avoid writes outside the target. Covered in Tasks 1/2.
3. A custom inspector name must use the project instructions while retaining native read-only authority, regardless of conflicting job guidance. Covered in Tasks 1/3.
4. Root edits and baseline upgrades must not change active-session definitions or silently alter project snapshots. Covered in Tasks 2/3.
5. Repeated, missing or malformed lifecycle events must not mark a task done, lose evidence, or repeat a notification/restart action. Covered in Task 4.

## File and interface map

- `agents/<id>/AGENTS.md`: plain instruction body. Reserve `crew-lead`, `crew-manager`, `crew-member`, `crew-inspector` for the four profiles; eight existing jobs retain their current names.
- `agents/<id>/agent.json`: local metadata; require `name`, `description`, `profile`. Profile values are exactly `lead`, `manager`, `member`, `inspector`. Names match directory IDs and `^[a-z][a-z0-9-]*$`. Profile metadata retains existing tools/disallowedTools/permissionMode/model/effort/kind defaults; job metadata retains skills/axi/effort. List fields are JSON string arrays. Reject unknown fields; jobs cannot supply tool/policy overrides.
- `personas/*.md`: existing stackable domain guidance; remove the eight migrated job files at final cutover. Do not rewrite domain behavior.
- `.herdr-crew/config.json`: keep `{version:1,roles:{...}}` runtime/model/effort overrides; accept discovered project job names in addition to existing profile aliases. Keep current override and model/variant rules.
- `.herdr-crew/baseline.json`: provenance `{version:1,source:<package-version>,files:{<relative-path>:<sha256>}}`; update only hashes for actually applied files. It is not another runtime-settings layer.
- `lib/agent-definitions.sh`: `definitions_load ROOT_DIR` validates/discovers definitions; `agent_definition ID` emits a resolved JSON record with `id`, `profile`, `description`, `profileInstructions`, `instructions` and existing metadata. Profile aliases map to `crew-<profile>`; no shell sourcing of metadata.
- `lib/project-config.sh`: `project_root` sets the verified primary `CONFIG_ROOT`; `project_init` materializes the baseline; `project_upgrade PATH...` previews or applies explicitly selected relative paths. Reuse the existing config-root discovery logic by extracting it once, rather than maintaining two algorithms.
- `lib/agent-config.sh`: keep selection/catalog validation and OpenCode output; consume the resolved definition instead of frontmatter lookups. `config_load` stays read-only; explicit init/first-use launch performs materialization.
- `bin/crew`, `lib/ux.sh`, `bin/install-skills`: wire lookups, setup/upgrades, per-session native definitions, help/completion and dependency scanning. Keep existing runtime orchestration.
- `hooks/`: baseline context/completion implementations, copied into the project for customization. Keep `bin/ctx-guard` as the compatibility entry point when moving its implementation.
- `evals/evals.json`: three initial model-driven skill cases. Results belong in an ignored local evaluation workspace, never fabricated in tracked docs.

---

### Task 1: Introduce standard guidance and a validated definition registry

**Files:** Create `agents/*/{AGENTS.md,agent.json}`, `lib/agent-definitions.sh`, `test/agent-definitions.sh`. Source instruction/metadata inputs are the four `ranks/crew-*.md` and eight job files in `personas/`. Keep those old files until native cutover in Task 3 so an intermediate checkout still launches correctly.

**Interfaces:** Produces `definitions_load ROOT_DIR` and `agent_definition ID` as defined above. No target-project writes and no live integration calls.

- [ ] Write failing fixture assertions: all 12 existing definitions preserve their instruction bodies and metadata; `driver` resolves profile `member`; `payments-reviewer` with profile `inspector` resolves its own guidance and the inspector's tool policy.
- [ ] Add rejection cases for `../escape`, mismatched `name`, missing AGENTS.md, unknown profile/field, malformed/multiple-document JSON, metadata symlinks, and a custom inspector trying to add member tools. Assert nonzero exit and no changed sentinel files.
- [ ] Run `/bin/bash test/agent-definitions.sh`; record its direct failing exit and relevant assertions before implementing.
- [ ] Implement the registry with jq and ordinary file reads. Preserve current body text and literal model strings; omit native memory configuration. Domain personas keep their existing reader until migrated callers need them.
- [ ] Run the focused suite and individual Bash syntax checks. Record a verification checkpoint; commit only if separately authorized.

### Task 2: Bootstrap, share and explicitly upgrade project configuration

**Files:** Create `lib/project-config.sh`, `test/project-baseline.sh`; modify `lib/agent-config.sh`, `bin/crew`, `lib/ux.sh`, `test/agent-config.sh` and focused fixture setup.

**Interfaces:** Consumes Task 1's validated definitions. `herdr-crew init` creates missing baseline files without overwriting existing files. `herdr-crew upgrade` previews changes; repeatable `--apply RELATIVE_PATH` selects replacements. Both support `--json`; flags/stdin are sufficient, with no TTY prompts. New JSON responses have `{project,action,changed,skipped}`; diagnostics go to stderr. Existing global `--dry-run` must write nothing for these new commands.

- [ ] Write failing tests for first init, retry/no-op init, retained custom guidance, unsupported flags, clean JSON stdout, help without runtimes, and no new files after dry-run.
- [ ] Add real-Git cases for worktrees, paths with spaces, separated metadata and ambiguous primary ownership. Keep the existing explicit CREW_REPO escape hatch; assert no writes into Git metadata or a worker-local .herdr-crew/.
- [ ] Add loss-prevention cases: malformed/stream legacy JSON, invalid baseline/provenance, existing symlink destinations/parents, concurrent setup and partial configuration. Preserve existing bytes on failure; do not mark a partial initialization complete.
- [ ] Add migration assertions: import valid legacy assignments only during initial setup, keep `.herdr-crew.json` byte-identical, use the new directory when both formats exist, and report the old file. Root persona edits must leave project guidance unchanged before a selected upgrade.
- [ ] Run `/bin/bash test/project-baseline.sh` and affected agent-config cases RED; then implement validated staging/atomic replacement and a bounded initialization lock. Never remove an unowned lock or silently replace customized content. Reject absolute/traversing/out-of-tree selected upgrade paths before writes.
- [ ] Confirm preview leaves every file unchanged; selected upgrade changes only selected files and corresponding provenance hashes. An upgrade revalidates source and target before replacement; it must not apply a different file than the one reviewed. Preserve ordinary configure wizard cancellation and model/effort validation.
- [ ] Run focused suites GREEN and update help/completion for init/upgrade. Record the checkpoint without publishing or committing.

### Task 3: Launch project definitions with existing native permissions

**Files:** Modify `bin/crew`, `lib/agent-config.sh`, `bin/install-skills`, `test/dry-run.sh`, `test/agent-config.sh`, `test/worktrees.sh`, affected teams/prompts and installation docs. Remove superseded `ranks/crew-*.md` and the eight old job persona files only after callers have switched. Keep domain personas.

**Interfaces:** Consumes validated primary-project definitions and existing `agent_selection` results. Preflight resolves every team slot before creating tasks/worktrees/panes. Existing `member@driver`, bare job names and four profile aliases remain compatible. New jobs must belong to an appropriate project team, preserving current team launch behavior.

- [ ] Add failing behavioral fixtures proving a project-customized `payments-reviewer` is the actual registered/launched definition; its instructions differ from the root baseline, and it keeps Inspector native permissions in both runtimes. A mismatched explicit profile, unknown job or missing team must fail before launch resources.
- [ ] Add captured-native-config assertions: Claude receives a session-local `--agents` JSON definition and `--agent` selection; OpenCode receives V2 plural `agents` and ordered `permissions`, primary mode and the current model/variant encoding. Profile rules override conflicting job guidance. Keep member push/merge denies, read-only allowlists and disabled OpenCode subagents.
- [ ] Run affected suites RED. Verify selected installed runtime versions/official schemas before using newly documented fields; do not assume the installed CLI matches the latest docs. No model generation is necessary for this schema check.
- [ ] Wire the existing start/brief/config paths to resolved project metadata. Eliminate dependence on globally linked rank files, and do not install global runtime agents. Inject only the selected profile/job/domain guidance; explicitly retain applicable target-repo AGENTS.md instructions. Keep source cwd, worktree ownership and fixed Lead/Manager topology unchanged.
- [ ] Snapshot resolved guidance, native policy and runtime selection after successful startup. Add restart tests: edit both project and root definitions, restart and verify saved bytes/settings; then perform a new launch and verify current project content. Preserve saved state if startup fails. Ensure the handoff pointer remains readable after restart; retain historical gaps separately unless the changed path actually resolves them.
- [ ] Switch installer skill/AXI scanning to the registry plus domain metadata, preserve its check-only and prompted human install behavior, and update canonical source/fixture/docs references. Remove obsolete source copies after proving no live caller needs them.
- [ ] Run definition, baseline, agent-config, dry-run and worktree suites GREEN; verify native outputs rather than prompt text alone. Record the checkpoint.

### Task 4: Make context and completion hooks project-owned and session-scoped

**Files:** Create `hooks/context-limit.sh`, `hooks/task-complete.sh`, `test/hooks.sh`; modify `bin/ctx-guard`, `bin/crew`, `lib/agent-config.sh`, relevant baseline agent guidance and `test/dry-run.sh`.

**Interfaces:** Preserve ctx-guard's always-successful advisory contract and default threshold 135000. `mark` records the current worker result `{agent,task,status,note}` in per-crew runtime state before invoking completion reporting. The completion handler reads a validated result and notifies the saved coordinator through existing `say`; it never sets `done`. A runtime stop alone supplies no valid result. Notifications are idempotent for identical agent/task/status/note, with the success marker written after delivery/queueing succeeds.

- [ ] Verify official events and installed adapter capabilities before selecting a native completion event. Document unsupported events as capabilities, not universal runtime limitations. Wire only supported per-session events; explicit mark/handoff reporting supplies the approved fallback.
- [ ] Add failing tests for one context warning per session, configured threshold propagation, missing usage, selected project hook path with spaces, and unchanged always-successful ctx behavior.
- [ ] Add completion cases: valid review result notifies once; duplicate stop/mark does not notify twice; blocked result remains blocked; no/malformed/mismatched result cannot mark done; delivery failure leaves evidence retryable. Assert no global settings writes and no inferred task acceptance from agent exit.
- [ ] Run `/bin/bash test/hooks.sh` RED; implement by reusing ctx-guard and say/mark/handoff paths. Keep coordinator identity explicit in saved metadata so arbitrary new agent names do not break routing. Do not build another event bus, watcher or restart service.
- [ ] Verify repeated events cannot create task duplicates, lost evidence or repeated restart actions. Run focused and affected existing suites GREEN; record each runtime's automatic versus explicit coverage honestly.

### Task 5: Finish the main skill and evaluate actual agent behavior

**Files:** Modify `SKILL.md`, `README.md`, `docs/features.md`, `skills.sources` as needed and repository checkpoints. Create `evals/evals.json` and `docs/research/project-agent-evaluation.md`. Retain existing script locations and portable skill-relative references.

**Interfaces:** Consumes Tasks 1-4. Follow the user's selected [skill specification](https://agentskills.io/specification), [evaluation guide](https://agentskills.io/skill-creation/evaluating-skills) and [script guide](https://agentskills.io/skill-creation/using-scripts#designing-scripts-for-agentic-use). Do not add an evaluation service or dependency.

- [ ] Update main skill metadata and routing: valid matching name/description, exact setup/configure/upgrade invocations, root-persona versus project-agent edit destinations, guidance/JSON/policy distinction, missing-dependency instructions and explicit hook limits. Run configuration scripts in the target-project context, not accidentally in the installed skill checkout. Document the bundled bin/crew invocation without assuming a global link; before launching workers, verify their required herdr-crew command resolves to the intended installation or report the existing setup steps. Restricted roles route file writes through authorized workers.
- [ ] Add three realistic prompts and expected outcomes in `evals/evals.json`: fresh-project setup without touching another project; creating/customizing an Inspector agent without elevating permission; upgrading a customized legacy project while accurately reporting unsupported automatic hooks. Include fixture inputs and an instruction prohibiting real Herdr/tsk integration calls or launching provider-backed crew agents; the isolated evaluation agent itself is the only model execution.
- [ ] Snapshot the previous skill and run candidate versus previous version in clean, isolated fixture contexts using stub integrations. Compare observable artifacts and command logs; add/check evidence-based assertions after inspecting outputs. Record available timing/token measurements or mark them unavailable. Test skill routing separately from explicit-invocation output quality; do not infer trigger accuracy from runs forced to load the skill.
- [ ] Write the evidence report with per-case results and inspected paths; do not claim model-driven evaluation from merely parsing evals.json or running shell tests. If an isolated model evaluation cannot be executed in the available harness, leave that criterion explicitly pending with the exact repeatable procedure.
- [ ] Self-review the plan/spec coverage, then run every required check below and inspect the complete diff. Obtain one independent whole-change review before completion; fix material findings with focused regressions. No live acceptance is implied.
- [ ] Update LEAD_STATE/STATE/PROGRESS with changed behavior, exact commands/direct exits, evaluation evidence, runtime capability limits and remaining live acceptance. Commit/publication remain separate authorization.

## Required verification

Run focused tests first, then the repository-required suites once after the final changes:

```bash
for script in bin/crew bin/ctx-guard bin/install-skills lib/ux.sh lib/agent-config.sh lib/agent-definitions.sh lib/project-config.sh hooks/context-limit.sh hooks/task-complete.sh test/dry-run.sh test/worktrees.sh test/agent-config.sh test/agent-definitions.sh test/project-baseline.sh test/hooks.sh; do
  /bin/bash -n "$script" || exit
done
/bin/bash test/agent-definitions.sh
/bin/bash test/project-baseline.sh
/bin/bash test/hooks.sh
/bin/bash test/dry-run.sh
/bin/bash test/worktrees.sh
/bin/bash test/agent-config.sh
git diff --check
```

Record direct exits per command; suite success is exit 0 with no failed assertions. Check Bash/Zsh completion syntax, affected documentation links and canonical references, main skill constraints, eval-case JSON and the actual recorded evaluation artifacts. Separate syntax, hermetic fixtures, real-Git checks, independent review, model-driven evals and any separately authorized live acceptance in the final report.

## Execution handoff

Recommended: native implementation task-by-task, followed by one independent whole-change review. Definition resolution, materialization, adapter output and saved-session data share interfaces, so sequential implementation avoids parallel edits to the launcher and configuration files. No execution method has yet been selected. Research/design approval is not a claim that implementation or evaluations have already run.
