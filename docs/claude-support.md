# Claude Code support in herdr-crew

Claude Code is the default runtime for herdr-crew. The launcher starts each role as a Claude Code session in an app-created terminal, passes the selected definition and native permission settings per session, and uses Claude-specific hooks and Monitor behavior. This page collects the Claude-specific behavior; the runtime-neutral flows are in [usage](./usage.md) and [reference](./reference.md).

## Requirements

- **Claude Code** must be on PATH and authenticated. Mixed-agent teams that also use OpenCode need both CLIs on PATH, authenticated separately.
- The default installation registers tsk with Claude Code: run `tsk setup claude` once. `tsk setup herdr` and `herdr server reload-config` no longer apply.
- The Manager requires the `caveman:caveman` plugin skill. `install-skills --check` does not detect this requirement, so install it separately before launching a crew.

## What the launcher passes

The launcher loads definitions from the installed package and supplies them to each Claude session; no global rank-agent links are needed. A project's `.herdr-crew/agents/<id>/AGENTS.md` and `agent.json` customize a named agent, but job guidance cannot expand the profile's native tools or change its permission mode.

Claude agents also receive a SessionStart hook that restores the crew environment variables (`CREW_SLUG`, `CREW_REPO`, `CREW_TASK`, `CREW_AGENT`, `CREW_MANAGER`, `CREW_WS`) for Bash commands on startup and resume. Agents started before this hook was added need `herdr-crew restart <agent>` to receive it.

## Trust prompts

The launcher answers Claude's "trust this folder" prompt only for agents it starts in an app-created terminal. Any other trust prompt is yours to answer.

## Monitor and the board

Claude keeps its hooks, Skill/Explore and Monitor workflow. The Lead runs `herdr-crew watch` in the Monitor tool, which polls every 20 seconds and prints one line for each board change. The Manager also uses Monitor for worker waits, so it can handle messages while workers run.

## Explore sub-agent for quick questions

The Lead delegates quick lookups to a read-only Explore sub-agent using Haiku 5.5 (`claude-haiku-5-5`) with medium effort. The tested Agent schema accepts the `haiku` alias rather than a full model ID; the Lead reports when exact pinning or model resolution cannot be verified. Claude Code 2.1.292 or later supports the per-invocation effort setting; Haiku 5.5 requires 2.1.293 or later. Unsupported or overridden settings are reported instead of silently substituted.

## Context budget and handoffs

Claude agents have a warning budget of 135000 tokens, set with `CREW_CTX_LIMIT`. A saved copy of the project's context hook warns once per session when it reaches the budget. The agent then writes a handoff and stops:

```bash
herdr-crew handoff "half done, tests pass" <<'EOF'
Goal, what is done, what is in progress, next steps, files, task number.
EOF
```

The handoff is saved to `~/.herdr/crew/<slug>/handoff-<agent>.md`, and the task gets a `[handoff]` step. The agent that started it, the manager for a worker, is told. It restarts the agent with `herdr-crew restart <agent>`, or restarts a whole team with `herdr-crew restart T12`. See [usage](./usage.md#context-budget-and-handoffs) for the full restart sequence.

## Skills

`install-skills` checks and installs the persona skills for Claude. Claude plugin skills are not automatically portable to OpenCode. The Manager's `caveman:caveman` plugin skill and several domain skills with `UNKNOWN` sources need manual installation; see [Troubleshooting](./troubleshooting.md#skills-with-unknown-sources).

## Known Claude-specific gaps

- In a live test, the Haiku driver once said it had no shell, and the Manager once used an old, archived task number. Both are under investigation.
- A busy Lead or Manager message can be undelivered with exit 0. Read the delivery output and preserve important questions in tsk.
- A startup warning does not prove a prompt was lost. Inspect the pane and recorded messages before sending anything again.

For the complete limit list, see [Troubleshooting](./troubleshooting.md). For OpenCode behavior, see [OpenCode 2 support](./opencode-support.md).
