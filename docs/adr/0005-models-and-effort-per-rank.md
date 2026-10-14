# 0005. Model and effort are set per rank, with per-job effort overrides

- Status: Accepted
- Date: 2026-10-13

## Context

Each agent role needs a different balance of cost and thinking depth. The Lead plans and talks to the user, so it needs the strongest model. Workers need enough depth to write correct code, and the reviewer needs the most depth. Running every agent at the top setting would cost too much.

## Decision

Each rank file sets `model:` and `effort:`. The values are: lead opus with high effort, manager haiku with max effort, inspector haiku with xhigh effort, and member haiku with high effort. `start_agent` passes them as `--model` and `--effort` on the Claude command line. A job persona can set its own `effort:`, and that value wins over the rank's. The driver uses high, and the code-reviewer uses max. `model: inherit` passes no `--model` flag, so Claude Code's default applies.

## Consequences

- Cost goes mostly to the Lead, and the workers use the cheaper model.
- Effort can be tuned per job without changing the rank.
- The Manager runs at max effort on Haiku.
- The new values are only dry-run tested. Their live behaviour is open (STATE.md, open issue 6).
