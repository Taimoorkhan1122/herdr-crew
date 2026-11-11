# 0026. Command Code runtime adapter

- Status: Proposed (implementation on branch `feat/command-code-adapter`; automated checks and live behavior pending)
- Date: 2026-11-11

This is 0026 because 0020 is the project-owned baseline ADR. The next free number after 0025 is 0026, and the adapter decision does not supersede any earlier ADR.

## Context

The crew had two native adapters: Claude and OpenCode 2 ([ADR 0018](0018-project-agent-config.md), [ADR 0019](0019-opencode-model-variants.md)). Users asked for Command Code, an interactive CLI whose command is `cmd` (product written command-code or commandcode), version 1.88.5 or later, as a first-class choice for a role in `.herdr-crew/config.json`.

Command Code does not offer the surfaces the earlier adapters use. Each crew rank needs a policy: a prompt that states the rank, blocked write tools for the manager and inspector, and blocked Git push/merge commands for members.

- `.commandcode/agents/*.md` files are subagents only. There is no selectable primary-agent flag: `cmd` has no `--agent`, `--agents` or `--settings`.
- There is no project settings layer to carry per-role policy, so no file equivalent to Claude's `--settings` snapshot or OpenCode's `OPENCODE_CONFIG_CONTENT`.
- The CLI starts interactively, so the policy has to enter the session at start rather than through a config file it reads on its own.

## Decision

Add `command-code` as a first-class runtime adapter next to `claude` and `opencode`. Existing Claude and OpenCode behavior is unchanged.

- **Configuration token.** The token in `.herdr-crew/config.json` is exactly `command-code`. The runtime's own aliases are rejected in configuration so a project file has one spelling. The executable is `cmd`; binary lookup prefers `cmd`.
- **Version gate.** Launch preflight requires `cmd` 1.88.5 or later, alongside the existing executable and OpenCode major-version checks, before it creates tasks, worktrees or panes.
- **Start command.** The adapter starts `cmd` interactively with `-n NAME --model MODEL --effort EFFORT --permission-mode MODE -t --skip-onboarding --no-auto-update --mod PATH`.
- **Native mod.** The adapter generates a per-session TypeScript mod and passes it with `--mod`; Command Code's bundled jiti compiles it inside the session. The mod calls `cmd.hooks({appendSystemPrompt, beforeToolCall, onPermissionRequest, afterToolCall, onSessionStart})`:
  - `appendSystemPrompt` injects the rank and job instructions from the saved definition, the runtime guidance, and the crew policy into the system prompt.
  - `beforeToolCall` and `onPermissionRequest` block native `write_file` and `edit_file` for the manager and inspector, and block shell commands matching `git push`, `git merge` or `gh pr merge` for members, including the `git -C …` form.
  - `afterToolCall` reads `cmd.getContextUsage()` and injects a one-time handoff warning at `CREW_CTX_LIMIT`.
  - `onSessionStart` removes the `agent` and `agent_output` tools, which disables subagents.
- **Permission modes.** The inspector runs with `--permission-mode plan`, Command Code's native read-only mode. The lead, manager and member run with `yolo`, where the mod's deny rules and blocks still win.
- **Model catalog.** Models come from `cmd --list-models`. IDs may be `provider/model` or plain, such as `claude-sonnet-5-5`, and take no `#variant`, so effort stays in its own field. The adapter validates against that catalog with a one-day cache at `~/.herdr/crew/command-code-models`. If the lookup fails, it warns and falls back to syntax validation, so configuration still works offline.
- **Restart.** The saved argv and mod path are pinned, so restart keeps the policy the session launched with and a policy change reaches new launches only.
- **Completion.** Completion stays explicit through `herdr-crew mark` and `herdr-crew handoff`. No runtime hook reports completion, which matches the other adapters.

## Evidence

- `cmd --version` reports 1.88.5. `cmd --help` for that version lists the flags the adapter passes (`-n`, `--model`, `--effort`, `--permission-mode`, `-t`, `--skip-onboarding`, `--no-auto-update`, `--mod`) and the `--list-models` catalog command.
- The documentation bundled with the installed `cmd` describes `.commandcode/agents/*.md` as subagent definitions, documents the `cmd.hooks` API and its hook names, and documents `getContextUsage`. It records no selectable primary-agent flag, and no project settings file that carries role policy.
- Configuration layering: the session receives its policy from the `--mod` file named on its own command line. Nothing is written to a user-wide or project-wide Command Code settings file, so a crew session cannot change the policy of an unrelated Command Code session in the same project.
- Live headless evidence on `cmd` 1.88.5 with a generated member mod: `beforeToolCall` emitted `tool_hook_blocked` for `git push origin main` and the command did not run, while allowed `git status` and `cat` commands ran; `onSessionStart` removed `agent` and `agent_output` (30 tools to 28) and `getActiveTools()` confirmed it. `getContextUsage()` returned `{tokens: null, contextWindow: 256000, percent: null}` after turns, so the token warning is best-effort and did not fire in that run.
- Not tested: an interactive crew launch on Command Code, so readiness, brief delivery, pane lifecycle and restart in a real Herdr pane remain live-acceptance gaps.

## Consequences

The adapter reaches role parity in intent, not in enforcement mechanism. Its boundaries are native tool hooks and command patterns, not an operating-system sandbox:

- Manager and inspector no-write is enforced for the native file tools. A shell command can still write through redirection.
- Member Git push/merge denial matches command text. An alias or a custom wrapper can evade it.
- Ranks the mod does not name rely on their injected policy, as with the other adapters.

Command Code has no Claude-style `PostToolUse` or `UserPromptSubmit` transcript hook, and no asynchronous Monitor tool. The context warning therefore depends on the mod running, and it is best-effort because `getContextUsage()` can report no token count; the runtime brief discloses the reduced monitoring guarantees. The model cache can be up to a day stale, and the offline fallback checks syntax only, so an accepted model ID is not proof that the runtime will load it.

A per-session mod is also a per-session artifact: it is written next to the crew state under `~/.herdr/crew/<slug>/`, pinned by restart, and must be regenerated to change policy. The mod runs as trusted code inside the session, on the same trust footing as the CLI's own plugins.

Rejected alternatives:

- **Accept renames or the binary name as the token.** `command-code`, `commandcode` and `cmd` would then all mean one adapter while the runtime and its own docs use the other spellings. One canonical token keeps configuration, help text and error messages identical, and stops a typo from silently selecting a different runtime.
- **Write a project settings file.** Command Code exposes no supported project settings layer for a primary-agent policy. A guessed file would be unverified, would leak across unrelated sessions in the project, and would be overwritten by the runtime's own writes.
- **Register Claude-style hooks.** There is no equivalent transcript event to register, so the project context hook would never run. Reporting a warning that cannot fire would overstate the adapter.
- **Use `.commandcode/agents/*.md` as the four ranks.** Those files are subagents and there is no flag to select one as the primary agent. Using them would attach a subagent policy to a session that never runs it.
- **Keep Command Code prompt-only.** Without the mod, the manager and inspector would keep native write tools and members would keep `git push`. Instructions alone would widen every rank.

Follow-up work: an interactive crew launch on `cmd` 1.88.5 or later (readiness, brief delivery, pane lifecycle, restart), and confirmation that a catalog-cached ID loads in a real interactive session.
