# 0006. Each worker team gets its own worktree, with fixed branch rules per team

- Status: Accepted
- Date: 2026-10-13

## Context

Several teams can work on the same repo at the same time. Two agents editing one checkout would overwrite each other's changes. Git also refuses to check out the same branch in two worktrees at once, so the review team cannot open the pair team's branch directly.

## Decision

Each team's worktree is at `~/.herdr/worktrees/<slug>/<T#>-<team>`. The rule for each team comes from its `worktree=` line in `teams/*.conf`. `new` creates a branch `crew/<T#>-<team>` from HEAD, which is used by `pair` and `bug-validate`. `from-pair` creates `crew/<T#>-test` from `crew/<T#>-pair` when that branch exists, and from HEAD otherwise, which is used by `test`. `pair-branch` makes a detached checkout of `crew/<T#>-pair`, which is used by `review`, and it fails if the branch is missing. `none` makes no worktree, which is used only by the Lead tab. Worktrees are never removed automatically. `close` keeps them and prints the `git worktree remove` command for the user to run.

## Consequences

- Teams cannot overwrite each other's files, and the review team can read the driver's commits without a second checkout of the same branch.
- Worktrees accumulate on disk until the user removes them. The user must run the printed command.
- A review on a task with no pair branch fails. Open issue 3 covers the orphan task this leaves behind.
- The branch names depend on the task number, so a wrong task number (open issue 2) would send work to the wrong branch.
