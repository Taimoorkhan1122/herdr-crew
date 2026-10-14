# 0001. A single deterministic bash launcher named herdr-crew

- Status: Accepted
- Date: 2026-10-13

## Context

Starting a crew means many steps in a fixed order. The script creates tabs and panes, sets environment variables for each pane, creates worktrees, starts Claude agents, and sends each one its brief. An LLM that runs these steps by hand would get them wrong sometimes. The command name `crew` was already taken: `~/.local/bin/crew` is a symlink into a Python tool's virtualenv, and that tool is unrelated.

## Decision

All logic lives in one bash script, `bin/crew`. It is exposed as `herdr-crew` through the symlink `~/.local/bin/herdr-crew`. `SKILL.md` calls only the launcher, with `allowed-tools: Bash(herdr-crew *)`. The skill never runs herdr, tsk, or git directly. Setting `CREW_DRY_RUN=1` prints each mutating command with a `+` prefix on stderr instead of running it.

## Consequences

- The steps are reproducible and can be tested with fake commands on the PATH. The test in `test/dry-run.sh` depends on this.
- The skill is small, and the behaviour lives in one file that is easy to review.
- The name `herdr-crew` is longer to type, and users must make the symlink themselves. The README documents the symlink.
- The launcher is bash, so its logic is harder to extend than a Python or Go program would be. We accept that for a tool this size.
