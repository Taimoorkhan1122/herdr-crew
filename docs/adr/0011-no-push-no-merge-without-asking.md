# 0011. Nobody on the crew pushes or merges, and the Lead asks before any merge

- Status: Superseded by 0014
- Date: 2026-10-13

## Context

Agents work fast and can make changes that the user has not reviewed. A push or merge changes shared history and cannot be undone easily. Removing a worktree can also lose uncommitted work.

## Decision

Merging, pushing, and removing worktrees are always the user's decision. The member rank disallows `git push` and `git merge` in its tool rules. The inspector and manager ranks have no git write permission. The Lead has no git permission. The Lead asks the user with `AskUserQuestion` before any merge, push, or worktree removal, and asks every time. The Manager never runs `git merge`, `git push`, or removes a worktree. The Lead cannot run git, so the user runs the merge. `herdr-crew close` prints the removal command and never runs it. The user marks a task `done` after review.

## Consequences

- The user keeps control of what reaches shared branches.
- Work waits for the user, so a finished task can sit at `review` for a long time.
- The member rule blocks only `git push` and `git merge`. Other ways to publish work, such as a push through a different command, are not blocked by this rule.
- The rules are written in agent definitions, not enforced by the launcher.
