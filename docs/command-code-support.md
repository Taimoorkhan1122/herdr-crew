# Command Code support in herdr-crew

Command Code is the third runtime a crew role can use, after Claude Code (the default) and OpenCode 2. The configuration token is exactly `command-code`. The executable is `cmd`; the launcher also tries `command-code` and `commandcode`. The minimum version is 1.88.5.

The product is also written command-code or commandcode. Those spellings belong in your shell and your prompt; `config.json` accepts only `command-code`.

## Select Command Code for a rank or job

```bash
herdr-crew configure tester command-code --model claude-sonnet-5-5 --effort high
herdr-crew configure --show
```

`--model` is the exact ID that `cmd --list-models` prints. IDs may be `provider/model` or plain, such as `claude-sonnet-5-5`, and they have no `#variant` form: keep any effort in `effort` and never append it to the model string.

The adapter checks the ID against that catalog and caches the response for one day at `~/.herdr/crew/command-code-models`. If the catalog cannot be read, it prints a warning and falls back to checking the ID's syntax, so an offline machine can still save an assignment that the runtime later rejects. Launch preflight checks the Command Code minimum version before creating tasks, worktrees or panes.

The wizard reads the same catalog: choose a number, enter a full model ID, or type a search term. Command Code model IDs carry no variant, so effort is a separate value.

## How a role starts

The launcher writes a per-session TypeScript mod to a file and starts `cmd` with `-n`, `--model`, `--effort`, `--permission-mode`, `--skip-onboarding`, `--no-auto-update` and `--mod`. The bundled jiti compiles the mod inside the session.

The mod appends the crew rank and runtime policy to the system prompt, and it hooks `beforeToolCall`, `onPermissionRequest`, `afterToolCall` and `onSessionStart`.

## Permissions

- Inspectors run with `--permission-mode plan`, Command Code's own read-only mode.
- The lead, manager and member run with `yolo`, and the mod's deny rules still win there.
- Native `write_file` and `edit_file` are blocked for the manager and inspector.
- Member shell commands matching `git push`, `git merge` or `gh pr merge` are blocked, including `git -C …` and other global options such as `--git-dir` and `--no-pager`.
- `onSessionStart` reads the active tools with `getActiveTools()` and removes the `agent` and `agent_output` tools, so no subagent can bypass the rank.
- Command Code's `.commandcode/agents/*.md` files are subagents and have no primary-agent selector, so the crew does not use them as rank definitions.

These are native tool hooks and command patterns, not an operating-system sandbox. A manager or inspector shell command can still write through redirection, and an alias or wrapper script around `git push` can evade the member block. Ranks the mod does not name rely on their injected policy.

## Context and handoff

The context warning is best-effort. `afterToolCall` reads `cmd.getContextUsage()` and injects one handoff instruction at `CREW_CTX_LIMIT`. There is no transcript hook like Claude's `PostToolUse` or `UserPromptSubmit`, and a live free-model run returned `tokens: null`, so the warning did not fire. Monitor context and hand off before compaction.

## Restart

Restart reuses the saved argv and mod file, so a change to the adapter's policy reaches new launches only. Literal input such as `/exit` is sent with the caller's agent identity removed; see [ADR 0027](adr/0027-literal-sends-drop-agent-identity.md).

## What is not available

- Command Code starts interactively, so it has no `--agent`, `--agents` or `--settings` flag and no project settings file to layer role policy from.
- There is no asynchronous Monitor wakeup. Completion stays explicit through `mark` or `handoff`.
- An interactive crew launch and full cross-agent orchestration remain unverified. A live headless `cmd` 1.88.5 run loaded a generated member mod and confirmed the `git push` block and the removal of `agent` and `agent_output`; automated fixtures are not that evidence.

[ADR 0026](adr/0026-command-code-adapter.md) records the adapter decision and its limits. For configuration inheritance, see [Configuring herdr-crew](./configuration.md#configure-runtime-assignments). For the other runtimes, see [Claude Code support](./claude-support.md) and [OpenCode 2 support](./opencode-support.md).
