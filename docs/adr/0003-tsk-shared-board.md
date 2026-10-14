# 0003. tsk is the shared task board

- Status: Accepted
- Date: 2026-10-13

## Context

The Lead, the Manager, and every worker need one place to record tasks, status, and findings. Agents run in separate panes and separate worktrees, so the record must live outside any worktree. tsk (smarzban/tsk) is a small command-line task list that Herdr can show in a pane.

## Decision

tsk stores its data in `~/.tsk`, outside the worktrees. Each call passes the project as the absolute repo path, `-p "$REPO"`, because tsk refuses unknown short project names. Text is passed with `--title=` and `--notes=` so that text starting with `-` is read as a value. Findings are added with `tsk steps add`. `tsk edit --notes` is never used, because it replaces the whole task body. Status moves through `open`, `ready`, `started`, `review`, and `done`, with `blocked` as a side state. Agents set `started`, `review`, and `blocked`. The Manager stops at `review`. The user sets `done` after checking the work.

## Consequences

- Every agent reads the same task, and the history of each task is kept as steps.
- Writing with `steps add` keeps earlier notes safe, at the cost of a longer task history.
- Directly launched tasks start as `open`, not `ready`. Open issue 5 tracks this.
- Absolute paths make the commands longer, but they avoid the short-name failure.
- The storage location is set by tsk, not by this skill. The skill depends on tsk's behaviour in version 0.11.6.
