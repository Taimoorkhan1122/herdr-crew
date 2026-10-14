# 0002. The invoker always spawns, and the Lead builds the crew tab

- Status: Accepted
- Date: 2026-10-13

## Context

When someone types `/herdr-crew`, the agent that runs the command could take on a role itself. That would mix the invoker's own context with a crew role, and it would blur who is responsible for what. The crew needs a fixed shape: a Lead that talks to the user, a Manager that starts teams, and a board.

## Decision

The invoking agent only runs the launcher. It never adopts a role. For `lead`, `cmd_launch` creates one tab named `crew <slug>` in the workspace. The Lead goes in the root pane, the Manager goes in a split to its right, and the board (`tsk`) goes in a split below the Lead at a ratio of 0.3. The tab opens with `--no-focus`, so the user must switch to it. Running `lead` again while `<slug>-lead` exists sends the new text to the running Lead and starts nothing new.

## Consequences

- The user always gets the same layout, and the Lead is the single point of contact for the user.
- Keeping the invoker out of the crew means one command can start the whole crew without the invoker's context leaking into it.
- The rule "the invoker never adopts a role" is enforced by the skill's instructions and the narrow `allowed-tools`, not by code.
- Job teams (for example `driver`) skip the Lead and Manager. They create a task and start their team directly, so their tabs carry no Lead.
