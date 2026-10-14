# 0009. The Manager writes in caveman ultra, and the Lead writes in ASD-STE100

- Status: Accepted
- Date: 2026-10-13

## Context

Agents send each other short messages, and each message costs tokens. The Manager sends many status lines, so terse output saves the most there. The Lead talks to the user and to every worker, so its text must be clear and unambiguous, not merely short.

## Decision

The Manager's first action is to invoke the Skill tool with `caveman:caveman` and the argument `ultra`. It keeps that level for the whole session. The Lead first invokes `caveman:caveman` with `off`, then writes ASD-STE100 (Simplified Technical English) for the whole session. ASD-STE100 uses one topic per sentence, short procedural sentences, active voice, and one term for one meaning. Commands, paths, task numbers, and error strings stay exact. Both skills are named `caveman:caveman` because the bare `caveman` skill in `~/.agents` is broken for these arguments. Its `ultra` mode points to a missing `ultracave` skill.

## Consequences

- The Manager's messages are very short, which saves tokens.
- The Lead's messages are longer than caveman output, but they are precise.
- Both styles depend on the plugin skill loading. Neither has been verified live (STATE.md, open issue 6).
- Future skills that change output style must use the plugin name, not the bare name.
