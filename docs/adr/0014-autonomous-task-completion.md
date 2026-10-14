# 0014. The crew finishes each task on its own, up to approval

- Status: Accepted
- Date: 2026-10-13

## Context

Before this change, a task stopped at `review` until the user nudged the crew. The Lead had to summarize the work, and the user had to mark the task `done`. Each step waited for a person, so one task could sit for a long time between the pair and the review.

The user wants tasks to finish without nudges. The user still merges every branch, because a merge changes shared history. ADR 0011 says the user marks `done`. This change moves only that mark to the Manager, after the reviewer approves.

## Decision

Autonomous task completion is always on. It has no switch.

The Manager chains the teams for each task. When the driver marks `review`, the Manager runs the `review` team. The reviewer's `mark` note starts with `approve` or `changes:`. On `approve`, the Manager marks the task `done` with the note `approved: branch crew/T<n>-pair`, closes the team tabs with `herdr-crew close T<n>`, and reports to the Lead. On `changes:`, the Manager sends the findings to the driver. The driver fixes them, commits, and marks `review` again. The Manager then closes the review tab with `herdr-crew close T<n> review` and runs `herdr-crew team review T<n>` again. The loop runs at most 3 review rounds. After round 3 without approval, the Manager marks the task `blocked` and tells the Lead.

The reviewer runs the project's test command and reports the result in its note. No separate test team is part of the loop.

`herdr-crew close <T#> [<team>]` takes an optional team. With a team, it closes only the tab labelled exactly `T# <team>`, and it prints a removal command only for that team's worktree. Without a team, it behaves as before.

A review re-run reuses the review worktree when it already exists. The launcher moves it to the pair's new commit with `git checkout --detach crew/T<n>-pair`, instead of adding a second worktree.

Nobody pushes or merges. The user merges every branch. The Lead still asks with `AskUserQuestion` before any merge, push, or worktree removal. The Lead lists each `crew/T<n>-pair` branch for the user when a task reaches `done`.

This supersedes ADR 0011 only on who marks `done`. The Manager now sets it, after review approval. The rules on merge, push, and worktree removal in ADR 0011 still hold.

The changes are in `bin/crew` (`close` and the `pair-branch` case of `team`), `ranks/crew-manager.md`, `ranks/crew-lead.md`, `personas/code-reviewer.md`, and `personas/driver.md`. The dry-run test in `test/dry-run.sh` covers the launcher parts and the prompt text.

## Consequences

- Tasks finish without waiting for a nudge from the Lead or the user.
- `done` now means "approved, ready to merge". It no longer means "merged". The user still merges each branch.
- No separate test team runs in the loop. The reviewer runs the tests, so a failing test can hold up approval, but the review does not write new tests.
- Each task uses more agent runs: the pair, one review per round, and one fix per `changes:` round.
- The round limit is enforced by the Manager's prompt, not by the launcher. A Manager that miscounts could run more rounds than 3.
- Dry-run tests cover the launcher and prompt text only. The loop has not run live.
