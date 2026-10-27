# Project Agent Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Give each project an easy, persistent agent/model assignment per rank and job.

**Architecture:** A small sourced Bash helper owns JSON configuration, selection resolution and configure interaction; the existing launcher owns lifecycle and adapters. Main-checkout configuration is shared across linked worktrees, and resolved runtime selections are pinned in saved metadata.

**Tech Stack:** Bash 3.2, existing jq/Git, Markdown; no added dependencies.

**Spec:** [Per-project agent configuration](../specs/2026-10-27-project-agent-config-design.md).

## Global Constraints

- Preserve Bash 3.2, current commands, rank permissions, worker ownership and ctx-guard's always-successful hook behavior.
- No global defaults, dependencies, live agents, pushes, publication, merges or cleanup.
- Preserve existing main-checkout edits and staging; work in the isolated feature worktree.
- Initial native adapters: Claude and OpenCode. Reject unsupported runtimes rather than weaken permissions.

## Review Focus

- Provider changes must not inherit Claude model aliases or job effort values.
- Malformed, unknown, symlinked or interrupted config writes must not cause side effects or corrupt the original.
- Calls from linked worktrees must use the main project's configuration, independently of current directory.
- A team must preflight every slot before creating tasks/worktrees/panes, including missing executables.
- Restart must retain the running agent's selection across later config changes.

### Task 1: Configure and resolve project selections

**Files:** Create `lib/agent-config.sh`, `test/agent-config.sh`; modify `bin/crew`.

**Interfaces:** `agent_selection RANK JOB` fills `AGENT_KIND`, `AGENT_MODEL`, `AGENT_EFFORT`; `cmd_configure` handles interactive setup, `ROLE AGENT [--model MODEL] [--effort EFFORT]`, and `--show`.

- [x] Write failing CLI tests for defaults, atomic project edits, validation, no-dependency show, wizard EOF, literal values, other-project isolation and real-Git worktree sharing.
- [x] Run `/bin/bash test/agent-config.sh`; confirm missing configure behavior fails.
- [x] Implement validated JSON reading/writing and rank/job selection, keeping config commands ahead of runtime dependency checks.
- [x] Re-run focused tests and existing suites; inspect direct exits.

### Task 2: Launch adapters and pinned restart

**Files:** Modify `bin/crew`, `lib/agent-config.sh`, rank bodies, relevant persona guidance, `test/agent-config.sh`, and existing fixtures where dependency detection now needs fake executables.

**Interfaces:** Launch consumes resolved kind/model/effort, OpenCode session config and per-slot environment; saved metadata adds resolved kind/model/effort for restart.

- [x] Write failing tests for mixed-agent teams, rank/job precedence, full-team preflight before mutation, native permissions, instructions/skills, provider hook limits and restart pinning.
- [x] Verify failure before implementing each behavior.
- [x] Implement Claude/OpenCode adapters, provider-aware brief/env/restart, and safe preflight. Keep unsupported runtimes actionable.
- [x] Run focused suite, all five required syntax checks, `test/dry-run.sh` and `test/worktrees.sh`; require exit 0.

### Task 3: Documentation, review and handoff

**Files:** README.md, SKILL.md, docs/features.md, docs/STATE.md, docs/PROGRESS.md, docs/LEAD_STATE.md, docs/adr/0018-project-agent-config.md.

- [x] Document exact configure examples/schema, worktree sharing, native policy differences, installer/skill paths and unverified live behavior.
- [x] Request an independent whole-change source review; fix important findings through focused regressions.
- [x] Run final verification and whitespace/reference checks, then update checkpoint with exact evidence and remaining limits. Keep work local for review; no commit/push was requested.
