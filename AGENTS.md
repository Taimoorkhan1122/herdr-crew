# Working on herdr-crew

These instructions govern maintenance of this repository. Runtime crew roles also follow `ranks/` and `personas/`; keep their permissions intact. A restricted Lead routes file updates through an authorized worker.

## Start or resume a session

1. Read `docs/LEAD_STATE.md` for the current objective, approvals, work in hand, and next action.
2. Read `docs/STATE.md` for verified behavior and unresolved gaps, then the newest entries in `docs/PROGRESS.md`.
3. Check `pwd`, `git status --short --branch`, and relevant staged and unstaged diffs. Preserve existing edits and staging. On an unborn branch, use `git diff --cached` and report that no commit exists.
4. Reconcile the checkpoint with current files and evidence before acting. Treat recorded processes, tasks, panes, branches, and tests as snapshots requiring revalidation. Resume the next unfinished step; reuse existing tasks and owned resources after checking identity.
5. For product behavior, consult `README.md`, `docs/features.md`, and the relevant source. Read an ADR or plan when the task touches its decision. Historical ADRs and research do not establish current behavior.

## Project map and engineering rules

- `bin/crew`: Bash launcher and Herdr/tsk coordination. `bin/ctx-guard`: context hook. `bin/install-skills`: dependency checks and prompted installation.
- `ranks/`, `personas/`, `teams/`, and `skills.sources`: agent permissions, instructions, layouts, and dependencies. `SKILL.md` is the user-facing skill entry point.
- Prefer the smallest complete change. Reuse existing shell functions and conventions; add dependencies, abstractions, and configuration only for a demonstrated need.
- Preserve command names, output, exit codes, Bash 3.2 compatibility, worktree ownership checks, and launch/restart contracts unless the task explicitly changes them.
- Before writing, debugging, or reviewing shell scripts, read the [shell-scripting skill](.agents/skills/shell-scripting/SKILL.md). Apply its quoting, arrays, argument handling, error handling, and file-safety guidance within these project contracts. Choose strict mode and traps per script; preserve `ctx-guard`'s always-successful hook contract. Keep Bash scripts compatible with Bash 3.2 and add tools only for a demonstrated need.
- For a behavior change, trace callers and add a meaningful failing regression before the fix. Update affected prompts, fixtures, README, feature reference, and dependency manifest as needed.
- Use `rg` for search and `dust` for disk usage, with the documented fallbacks. Read relevant available skills before their workflows.
- Keep public docs portable and free of credentials, private prompts, and personal machine paths. `.superpowers/` and `.lavish/` are ignored local artifacts; durable handoff information belongs in the docs below.
- Preserve user work. Pushes, publication, merges, destructive cleanup, and worktree removal require explicit user authorization for that action. Preparing a public repository is not authorization to publish it.

## Verification

For shell or launcher/configuration changes, run:

```bash
for script in bin/crew bin/ctx-guard bin/install-skills test/dry-run.sh test/worktrees.sh; do
  /bin/bash -n "$script" || exit
done
/bin/bash test/dry-run.sh
/bin/bash test/worktrees.sh
```

The first suite uses fake integrations. The second uses real Git in disposable repositories with fake Herdr/tsk. Neither proves live agent behavior. Run focused checks first; record direct exit codes and relevant output. For documentation-only changes, check references and consistency; avoid launching agents or rerunning runtime suites solely for prose edits.

Use a disposable fixture for live acceptance only when authorized. Inspect ambiguous launches before resending prompts. Distinguish syntax checks, hermetic tests, real-Git tests, independent review, and live acceptance in every status report. Keep untested behavior explicit.

## Durable state and work in hand

The coordinating agent owns these records. Workers report results to it; avoid concurrent edits to the shared checkpoint.

- `docs/LEAD_STATE.md`: replace the active checkpoint with the latest objective, approved scope, decisions, work in hand, and exact resume steps. This is the first read for a replacement session.
- `docs/STATE.md`: update when product behavior, verification evidence, or an open issue changes. Preserve unresolved live acceptance gaps.
- `docs/PROGRESS.md`: append an entry under the newest date, newest work first. Record what changed, why, checks and exits, and remaining limits. Preserve older history.
- `docs/adr/`: follow `docs/README.md` for architectural decisions and supersession rules.

Update the checkpoint when scope or approval changes, after a meaningful milestone or failed approach, before delegating work that outlives the turn, and before ending a turn, switching sessions, or reaching the context limit. Write progress as work proceeds; a final chat response alone is insufficient.

Every checkpoint must include:

1. Timestamp with timezone; repo-relative paths, branch and commit (or no commit yet), and relevant staged/unstaged work.
2. User objective, authorized scope, decisions, and any pending approval or unanswered question.
3. Completed work and evidence; checks with commands, direct exit codes, and limits.
4. Work in hand: task, owner, status, changed files, remaining work, blockers, failed attempts, and any live resources requiring reconciliation. Use existing task IDs when applicable.
5. Ordered next actions, starting with a concrete command or file to inspect. Mark parked or unauthorized work explicitly.

Keep the checkpoint concise and public-safe. Store private operational details only in ignored local state and reference their purpose without copying sensitive content. If a file is missing on resume, report the missing evidence and reconstruct from Git and the progress log; do not invent prior completion or authorization.

When running inside an actual crew, also save the runtime handoff with `herdr-crew handoff "<status>"` and its body on stdin, as described in `docs/features.md`. Preserve tsk task evidence. The runtime handoff and this repository checkpoint serve different resume paths; neither substitutes for the other. Respect stop/handoff requests immediately after saving state, and do not restart parked workers.
