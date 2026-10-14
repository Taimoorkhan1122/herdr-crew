# 0015. The Lead watches the board with Monitor, and every agent has a context budget

- Status: Accepted
- Date: 2026-10-13

## Context

Before this change, the Lead had no way to notice a change on the board. It checked progress only when the user asked, so a blocked task or a finished task could wait unseen. Agents also ran until their context filled. Claude Code then compacted or lost the work in progress, and nothing recorded what the agent had done.

The user wants the Lead to react as events happen, and wants every agent to stop at a known size with its state written down. A restart then continues the work from that record instead of from a compacted context.

## Decision

The Lead runs the Monitor tool on `herdr-crew watch`. The `watch` subcommand polls the board every 20 seconds, and it prints one line for each change. It prints a line for a task whose status changed, for a crew agent that became `blocked` or `done` or disappeared, and for each new handoff file. It prints nothing for unchanged state. The Lead re-arms the Monitor whenever it expires, for as long as any task is open. `CREW_WATCH_SECS` sets the interval, and `CREW_WATCH_ONCE=1` runs two polls and exits, for the test.

Every agent has a context budget of 135000 tokens, set by `CREW_CTX_LIMIT`. The script `bin/ctx-guard` is a Claude Code hook. The launcher registers it for `PostToolUse` and `UserPromptSubmit` with the `--settings` flag of `claude`, so the setting applies only to the agents that the launcher starts. The hook reads the usage fields of the last main-thread assistant turn in the transcript. When the total reaches the budget, it adds a message to the agent's context once per session. The message asks the agent to finish its current step and to write a handoff.

The agent writes the handoff with `herdr-crew handoff "<status>"`, and the body arrives on stdin. The file goes to `$HOME/.herdr/crew/<slug>/handoff-<agent>.md`. The command adds a `[handoff]` step to the agent's task, and it tells the agent that restarts it. Workers tell the manager, the manager tells the lead, and the lead tells the manager. The restarting agent runs `herdr-crew restart <agent>`, or `herdr-crew restart T<n>` for a whole team. The restart sends `/exit`, waits until the pane returns to its shell, and starts the agent again from its saved rank, job, pane, task and brief. The brief gets a line that points to the handoff file. Afterwards the old handoff is renamed with an epoch suffix, so the watch does not report it again.

The Lead's rank and the manager's rank get the new commands in their tool lists. The manager restarts workers and the lead. The lead restarts the manager. The inspectors and members can run `herdr-crew handoff`, because their tool lists allow it.

## Consequences

The Lead reacts to blocked tasks and finished tasks without a user nudge. The cost is a poll every 20 seconds and the Lead's tokens while it monitors.

The hook reads the transcript format. It depends on the `usage` fields of assistant turns, and on the `isSidechain` flag. If Claude Code changes either format, the hook stops warning, and the budget stops working without any error. The `ctx-guard` script always exits 0, so it never blocks an agent, but a silent failure is possible.

A restart loses any in-context state that the agent did not write into the handoff. The brief tells the agent what to include, but the agent can still leave something out. A restarted agent also starts a new session, so it has no memory of the earlier conversation beyond the handoff file.

The budget is per agent, and it counts only the main thread of each session. Sub-agent turns do not count, so an agent that spawns many sub-agents can exceed the budget in total tokens without a warning.

Follow-up work: run the Monitor and the budget live, check the actual transcript size where the hook fires, and decide whether the 135000 limit is right for each model.
