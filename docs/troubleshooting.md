# Troubleshooting herdr-crew

Known limitations and failure modes, with the documented behavior and the next action. For verification evidence and open acceptance gaps, see [STATE.md](./STATE.md).

## The runtime needs a desktop session

`launch`, `team`, `say`, `mark`, `status`, `watch`, `close` and `restart` need a running app window that answers `herdr-app status`. They do not work on a headless server, container or CI runner. `help`, `--version`, `completion`, `init`, `upgrade` and `configure` still work without the app.

## Restart fails after `hc kill` or a finished terminal

Restart reuses the terminal only after a normal agent exit. After `hc kill`, or when the terminal reports `finished`, the pane is gone: relaunch the team. A blocked agent needs a person before it can restart.

## An agent answers /exit as a chat message

`hc` adds `<hc from="...">` note framing when an agent terminal sends to its parent. An older build sent `/exit` through that path, so the agent replied instead of exiting and restart timed out. Current `bin/crew` drops the caller identity for literal input: `/exit`, the saved command, briefs and `say` messages. If an agent receives `/exit` as a message, update the installed launcher. See [ADR 0027](adr/0027-literal-sends-drop-agent-identity.md).

## A message was not delivered

A blocked recipient is never forced. The message is queued once on its task, or reported as not delivered when the agent has no task. A busy Lead or Manager message can be undelivered with exit 0. Read the delivery output and preserve important questions in tsk.

A startup warning does not prove a prompt was lost. Inspect the pane and recorded messages before sending anything again.

## Tab titles show only the latest event

Tab titles replace pane titles. A shared tab shows the latest agent event, not a title for each pane.

## The pane split ratio is not configurable

Pane splits use the app default ratio. `pane.split` has no ratio argument, so the board divider is not set to 0.3.

## Behavior that is unverified on this runtime

These are not confirmed on the current runtime: an app restart with live terminals, pane title behavior, the split ratio, headless use, and a real permission-blocked agent. No live crew has run since the migration.

## Visual planning acceptance is incomplete

Visual planning has automated launch/instruction checks and a browser-checked example. Live Lead/planner approval, revision, offline fallback and restart acceptance remain pending; see [the acceptance checklist](./planning/acceptance.md).

## Live-test findings under investigation

In a live test, the Haiku driver once said it had no shell, and the Manager once used an old, archived task number. Both are under investigation.

## Trust prompts

The launcher answers Claude's "trust this folder" prompt only for agents it starts in an app-created terminal. Any other trust prompt is yours to answer.

## Worktrees are never removed automatically

Run the removal command that `close` prints when you are done. `close` keeps worktrees and prints `git -C <repo> worktree remove <path>`; it never runs that command itself.

## tsk rejects newlines and control characters

`tsk steps add` rejects newlines and control characters. Record one-line answers or notes; handoff files can contain multiline text.

## Test concurrency is research only

Test concurrency limiting is [research only](./research/test-concurrency.md). There is no built `test` or `tests` launcher subcommand or test-rewriting PreToolUse hook.

## Completion delivery has no runtime hook

Automatic completion result delivery is not connected to a runtime hook. Agents report through `mark` or `handoff`; task review remains separate from stopping a process.

## Custom project jobs are only fixture-tested

Custom project jobs have fixture-based launch coverage; native permission enforcement and live launches remain unverified.

## Command Code permissions are not an OS sandbox

Command Code enforcement is native tool hooks and command patterns. A manager or inspector shell command can still write files by redirection, and an alias or wrapper around `git push` can evade the member block. Ranks the mod does not name rely on their injected policy. See [Command Code support](./command-code-support.md).

## Command Code context warnings are best-effort

Command Code has no transcript hook and no asynchronous Monitor tool. `afterToolCall` reads `cmd.getContextUsage()` and injects one handoff instruction at `CREW_CTX_LIMIT`, but a live free-model run returned `tokens: null`, so the warning did not fire. Monitor context and hand off before compaction.

## The Command Code model catalog can be offline or stale

The adapter caches `cmd --list-models` for one day at `~/.herdr/crew/command-code-models`. If the catalog cannot be read, it warns and checks syntax only, so it can accept an ID that the runtime later rejects. Command Code 1.88.5 or later is required.

## Skills with UNKNOWN sources

Some skills in `skills.sources` are `UNKNOWN`: `qa-bug-validator`, `react-production-engineering`, `react-component-engineering`, `react-quality-engineering`, `impeccable`, and `context7-mcp`. `install-skills` cannot fetch them, so install them by hand if they go missing.

## The Manager skill is not detected by `--check`

The Manager requires the `caveman:caveman` plugin skill. `install-skills --check` does not currently detect this requirement, so a passing check alone does not mean all required skills are installed.

## Status and logging

`herdr-crew status` prints one line per open task and one per live agent. An agent with no reported status is omitted. Use `--json` for the raw task list. For verification state, see [STATE.md](./STATE.md); for the feature reference, see [features.md](./features.md).
