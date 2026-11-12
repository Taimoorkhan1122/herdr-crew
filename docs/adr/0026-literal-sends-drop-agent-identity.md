# 0026. Drop the caller agent identity for literal terminal input

- Status: Accepted
- Date: 2026-11-12

## Context

`hc send` adds note framing when an agent terminal messages its parent. A live crew showed the result: the Manager restarted the Lead, and the Lead received `<hc from="t53">/exit</hc>` as a chat message. It answered instead of exiting, so `restart` waited for a shell prompt that never appeared and then failed.

`hc` 0.1.20 has no per-send raw or no-notes flag. The documented `notes = false` setting is config-level, and a scoped `XDG_CONFIG_HOME` config did not suppress the framing in a controlled test. The sender identity, `HC_TERMINAL_ID`, is what makes `hc` wrap the text.

A controlled reproduction used two status-reporting stub terminals (`state=done:app=claude-code`), with one started as the other's child. With `HC_TERMINAL_ID` set, the parent received `<hc from="t6b probe-child3">NOTETEST2</hc>`. With `HC_TERMINAL_ID` unset for the send, the parent received `RAWTEST2`. `HC_TERMINAL_SOCKET` stayed set, so the call still reached the same core.

## Decision

Add `hc_send` in `bin/crew`. In a real run it executes `hc send` in a subshell after `unset HC_TERMINAL_ID`. It keeps `HC_TERMINAL_SOCKET` and `HC_SOCKET`, so the client reaches the same core.

Use `hc_send` for every literal input path:

- the first and restart briefs, including `say` messages, through `submit_term`;
- `/exit` during restart;
- the saved agent command during restart.

Dry runs keep the existing `+ hc send ...` plan output. The helper uses the shell builtin `unset`, not the external `env` command, because launcher tests exercise a restricted PATH.

## Consequences

`/exit` and the saved command reach the agent as literal input. Briefs and `say` messages no longer carry an extra `<hc from="...">` wrapper; crew messages keep their own `[from <agent>]` prefix.

`hc`'s automatic sender tag is lost for crew sends. That tag is redundant for this protocol and was the cause of the failure. If `hc` adds a per-send raw mode, the helper should use it instead of clearing the identity.

The fix is covered by a hermetic launcher check: the fixture records `HC_TERMINAL_ID` for each `send` call, and the restart test asserts every entry is empty. `test/dry-run.sh`, `test/worktrees.sh`, `test/agent-config.sh`, `test/project-launch.sh` and `test/review-regressions.sh` pass.

No live restart has run after the fix. The live crew used an installed copy at `~/.agents/skills/herdr-crew`, which is not a git checkout; that copy was patched in place. Live acceptance remains pending.
