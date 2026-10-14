# 0007. The launcher answers the workspace trust prompt only for panes it starts

- Status: Accepted
- Date: 2026-10-13

## Context

Claude Code asks "trust this folder" the first time it opens a folder. A new agent in a new worktree stops at this prompt, so it never reads its brief. The user approved automatic trust for crew panes only.

## Decision

`start_agent` first tries to start the agent. If the start fails with `agent_not_ready` and the pane shows "trust this folder", the launcher answers the prompt. It sends Down and then Enter, because the default option is "No, exit". It then waits until the agent is idle or done. The launcher does this only for agents it starts in its own panes. Any other trust prompt is left for the user.

## Consequences

- Crew agents start without manual steps.
- The launcher answers the prompt only for panes it starts, so other folders are not affected.
- The step depends on the prompt's layout. If Claude Code changes the order of its options, Down and Enter could pick the wrong option. This is a known risk.
- Fixed after live test 1, when the default option was found to be "No, exit".
