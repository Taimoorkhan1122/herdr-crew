# 0008. Messages never block the sender, and busy recipients get the message as a task step

- Status: Accepted
- Date: 2026-10-13

## Context

Agents message each other with `herdr-crew say`. An early version could deadlock: two agents that each waited for the other to go idle would wait forever. A message sent to a busy agent could also be lost.

## Decision

`cmd_say` never blocks for long, and it never exits with an error because the recipient is busy. If the recipient is idle or done, the message is sent at once. Otherwise `cmd_say` waits at most 20 seconds for the recipient to become idle. If the recipient is still busy, the message is added as a step on the recipient's task, with the prefix `[msg from X to Y]`. The task number comes from the recipient's agent name, which has the form `<slug>-t<n>-<job>`. If there is no task number, the sender gets a message that the message was not delivered. Prompts are sent by `submit`, which presses Enter again, or resends the whole prompt, if the agent does not start working within a few tries.

## Consequences

- Agents cannot deadlock on each other's messages.
- A queued message waits for the recipient to read its task steps. The brief tells agents to check the steps after each step.
- A message to the Lead or Manager, which have no task number, can be lost if they are busy. The sender is told so.
- The `submit` re-send path is not covered by the dry-run test (open issue 7).
