# Maintainability Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task after user approval. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct the five reviewed lifecycle, worktree, status, and dependency issues with focused Bash changes and regression tests.

**Architecture:** Keep the current launcher, scripts, and Markdown configuration. Change existing functions at their boundaries; add only a small shared worktree validator where two paths need the same checks. Preserve user edits and uncertain runtime state.

**Tech Stack:** Bash 3.2, Git, jq, fake Herdr/tsk fixtures, Markdown; no new dependencies.

**Spec:** [Independent maintainability review](../../maintainability-review-2026-10-14.md), findings 1–5, and [repository instructions](../../../AGENTS.md). This plan defines the proposed behavior for approval; it authorizes no implementation by itself.

## Global constraints

- Preserve command names, output, exit codes, Bash 3.2 compatibility, worktree ownership checks, and launch/restart contracts except for the explicit corrections below. New stale-worktree refusals exit nonzero with a clear diagnostic.
- Preserve staged and unstaged work. There is currently no initial commit; do not create one solely to execute this plan. At execution, recheck Git state and choose an isolated worktree if a committed base exists. Otherwise use a disposable copy for regression fixtures and keep repository edits narrowly scoped without changing the index.
- No framework, launcher split, generic state store, automatic reset/rebase/merge, extra providers, or unrelated cleanup.
- No live agents, real dependency installation, push, publication, or worktree removal under this plan. Existing user requests for separate live acceptance remain parked.
- Each task uses red → minimal fix → green, then review. Keep current behavior outside the reviewed failure boundary. Record direct command exits and evidence in LEAD_STATE/PROGRESS; keep STATE honest about live gaps.
- Existing staged files and the newly added .agents/ skill directory are user work; preserve them. Implementation commits are deferred until a suitable baseline and commit scope are agreed.

## File map

- Modify `bin/crew`: `restart_one`, `cmd_team`, `status_of`/watch boundary, and `brief`.
- Modify `test/dry-run.sh`: fake CLI behavior and lifecycle/status/brief regressions.
- Modify `test/worktrees.sh`: real-Git ownership and source-version regressions.
- Modify `ranks/crew-manager.md`, `ranks/crew-lead.md`, `skills.sources`: declare the plugin where it is invoked and record its verified source.
- Create `test/install-skills.sh`: disposable HOME, plugin registry, fake installer commands; no network or global writes.
- Modify `README.md`, `docs/features.md`, `docs/STATE.md`, `docs/PROGRESS.md`, `docs/LEAD_STATE.md`, and the audit report's resolution notes as each correction lands. Keep original findings as historical review evidence.
- `bin/install-skills` already scans rank and persona frontmatter through `list_key`; reuse it. Change installer code only if a failing fixture demonstrates an additional defect.

## Review focus

1. Startup fails after a handoff snapshot exists: both the snapshot and a usable retry path survive (Task 1).
2. Pair advances while a test branch has its own commits or edits: refusal preserves all work (Task 2).
3. Expected worktree path is a symlink or nested directory in another checkout: refuse before checkout or agent launch (Task 3).
4. CLI transport failure or malformed JSON resembles an absent agent: retain the snapshot and avoid false gone (Task 4).
5. Plugin is absent with no verified marketplace configured: check reports missing without installing or claiming readiness (Task 5).

## Task 1: Preserve a readable handoff across restart

**Files:** `bin/crew:restart_one`; restart fixtures in `test/dry-run.sh`; handoff reference docs.
**Interface:** `restart_one NAME` keeps its command signature. The saved resume brief references an immutable, unique handoff snapshot that remains readable after return and on retry.

- [ ] Add `restart_handoff_path_survives`: extract the path actually sent in the brief, read it after restart, and compare its contents with the original handoff. Replace the current assertion that approves the obsolete canonical path.
- [ ] Add `restart_failed_start_preserves_handoff` and `restart_twice_same_second`: force startup failure and repeated restart; verify no lost content, no overwritten snapshot, and a readable retry reference. Include a fresh handoff arriving during startup so cleanup cannot remove it.
- [ ] Run `/bin/bash test/dry-run.sh`; capture nonzero exit from the new assertions on the unmodified launcher.
- [ ] Before submitting the brief, create a unique immutable snapshot (using mktemp naming compatible with the watch archive filter) and reference it. Keep the pending canonical handoff available until startup succeeds; clear it only if it still represents the captured handoff. Preserve both retry evidence and any newer handoff on failure. Keep the existing no-duplicate-submission rule.
- [ ] Run the same suite to exit 0/ALL PASS; inspect the saved brief and referenced file. Review the change and update docs/checkpoint before Task 2.

## Task 2: Refuse testing an outdated pair revision

**Files:** `bin/crew:cmd_team` from-pair branch; `test/worktrees.sh`; testing reference docs.
**Interface:** `team test T<n>` reuses the test branch only when the current pair tip is its ancestor. A stale/diverged base is refused before panes or agents start, preserving branch commits and edits. Initial fallback to HEAD when no pair branch exists remains supported.

- [ ] Add `test_refuses_advanced_pair`: create a test branch, advance pair, and verify a second test launch exits nonzero without a new pane, altered HEAD, or lost edits. Repeat with a test-only commit and with a detached/reattached retained branch.
- [ ] Add `test_accepts_current_pair_with_test_commits`: pair is an ancestor, test has extra commits and local edits; launch succeeds and preserves both. Retain the no-pair fallback case.
- [ ] Run `/bin/bash test/worktrees.sh`; confirm the stale-base assertion fails on the current implementation.
- [ ] Check `git merge-base --is-ancestor crew/T<n>-pair crew/T<n>-test` before reusing an existing from-pair branch, including reattachment without a retained directory. Distinguish missing refs/Git errors from ancestry mismatch and refuse both safely. Diagnostic identifies the branches and asks the operator to update the test branch intentionally; perform no automatic history edit.
- [ ] Run worktree and hermetic suites to exit 0. Review and document the new refusal and manual update requirement.

## Task 3: Validate retained worktree identity before use

**Files:** `bin/crew:cmd_team`; `test/worktrees.sh`; relevant fake Git responses in `test/dry-run.sh`.
**Interface:** A small `check_worktree PATH [EXPECTED_BRANCH]` function succeeds only for an exact worktree root registered to REPO's Git common directory. With EXPECTED_BRANCH supplied, also require that attached branch; review accepts a detached worktree and changes its checkout only after validation.

- [ ] Add `review_refuses_foreign_repo`: put an unrelated repository with the same pair branch at the review path; assert failure, unchanged HEAD/files, and no agent launch.
- [ ] Add `review_refuses_nested_or_symlink_path`: a nested directory or link at the expected path is refused. Add a positive case that reuses a genuine detached review worktree after pair advances; it must see the new pair commit. Retain ownership tests for pair/test paths.
- [ ] Run `/bin/bash test/worktrees.sh`; confirm foreign-repository review currently succeeds incorrectly.
- [ ] Share the common-directory and exact-root validation between retained new/from-pair and pair-branch paths; refuse symlink paths. Keep branch attachment and dirty-checkout protections provided by Git. Do not force checkout or remove anything.
- [ ] Run both existing suites to exit 0; adjust fake Git discovery responses to represent valid fixtures rather than weaken validation. Review and update checkpoint/docs.

## Task 4: Keep transient lookup failures distinct from absence

**Files:** `bin/crew:status_of` and `cmd_watch`; watch fixtures in `test/dry-run.sh`. Trace other `status_of` callers before changes.
**Interface:** Preserve existing status text for successful lookups. Give the watch boundary explicit lookup outcomes: known status, confirmed absent, or unknown. A failed/malformed lookup retains that agent's prior snapshot; confirmed absence alone may emit gone.

- [ ] Inspect the installed CLI's read-only help/schema for a documented not-found signal; do not infer absence from arbitrary nonzero exits or empty stdout. If no reliable signal exists, treat those cases as unknown and retain the snapshot; document that gone detection remains conservative until absence can be proven.
- [ ] Add `watch_failed_lookup_keeps_agent`, `watch_malformed_lookup_keeps_agent`, and `watch_confirmed_missing_emits_once`: simulate successful poll, failure, recovery and confirmed absence. Assert no false gone/done event and one event for proven disappearance. Retain startup duplicate-name and messaging regressions.
- [ ] Run `/bin/bash test/dry-run.sh`; capture the false-gone regression on the current code.
- [ ] Preserve per-agent previous status on unknown reads and validate successful JSON status shape. Keep the existing task-read failure policy. Use a narrow helper or explicit return codes at the watch boundary; preserve other callers' output/exit contracts. Do not add retries that restart or resend prompts.
- [ ] Run the hermetic suite to exit 0; review absence evidence, all status_of callers, and snapshot transitions. Update docs and checkpoint.

## Task 5: Declare and test rank skill requirements

**Files:** `ranks/crew-manager.md`, `ranks/crew-lead.md`, `skills.sources`, `bin/crew:brief`, `test/dry-run.sh`, new `test/install-skills.sh`, setup/reference docs.
**Interface:** Rank `skills:` and persona `skills:` form one deduplicated list in generated briefs. The existing installer discovers both. Missing required plugins make --check exit 1 without mutation; verified installed fixtures pass.

- [ ] Revalidate the locally registered Claude plugin `caveman@caveman` and marketplace source `JuliusBrussee/caveman` before recording `caveman:caveman plugin caveman@caveman`. Local registry evidence supports this identifier; marketplace provisioning on a fresh machine still needs explicit instructions, not assumed configuration.
- [ ] Add `brief_includes_rank_skills_once` and `brief_deduplicates_rank_and_persona`: ensure Manager and Lead's invocation requirements appear once alongside existing skills. Preserve Lead's normal-mode fallback and Manager's ultra instruction.
- [ ] Create disposable installer fixtures with fake claude/npm/npx and isolated HOME/PATH: missing plugin exits 1 with no install calls; installed registry exits 0 when all other declared requirements are satisfied; unconfigured marketplace still reports missing. Run `/bin/bash test/install-skills.sh` and the hermetic suite; capture the missing-declaration failures before edits.
- [ ] Add the rank frontmatter declarations and verified manifest entry; merge rank skills into brief generation using the existing deduplication pattern. Reuse list_key in the installer. Keep install prompts and --check nonmutation behavior.
- [ ] Run installer and hermetic suites to exit 0. Replace the manual-undetected-prerequisite README warning only once discovery is covered; document any remaining marketplace setup and UNKNOWN skill limitations. Review the task.

## Final gate and handoff

- [ ] Check every script separately: `for script in bin/crew bin/ctx-guard bin/install-skills test/dry-run.sh test/worktrees.sh test/install-skills.sh; do /bin/bash -n "$script" || exit; done`.
- [ ] Run `/bin/bash test/dry-run.sh`, `/bin/bash test/worktrees.sh`, and `/bin/bash test/install-skills.sh` separately and record direct exits, expected 0. Run `git diff --check` and review staged/unstaged changes against the preserved baseline.
- [ ] Request independent review covering all five fixes, failed startup, stale refs, ownership, unknown reads, and installer side effects. Resolve material findings with focused regressions; record approval separately from tests.
- [ ] Update the original audit with resolution evidence, STATE verification limits, PROGRESS, and LEAD_STATE. Preserve unresolved live acceptance issues. Summarize any remaining gaps; do not call full live acceptance or publication complete.
- [ ] Hand back the tested changes for review. No push, release, merge, or cleanup follows automatically.

## Execution choice

Recommended: native sequential implementation with one independent final review. The tasks share bin/crew and its fixtures, so concurrent edits offer little benefit. Alternatively use one fresh implementer and reviewer per task, still sequential. User approves the plan and execution approach before either begins.
