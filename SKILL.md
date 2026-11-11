---
name: herdr-crew
description: Launch an agent crew in Herdr for development or project questions. Usage - /herdr-crew <spec> <instructions>. Spec - lead (starts the crew), or <rank>[@<persona>[+<persona>]] with ranks member or inspector, or a bare job persona including investigator or planner.
allowed-tools: Bash(herdr-crew *)
---

The runtime is `herdr-core` (`hc`) plus the Herdr desktop app. The app owns spaces, tabs and panes; `hc` owns send, read, wait, status and kill. Runtime commands also require `tsk` and `jq`; Git is required for every invocation, including pure-text help. A running app window is required for `launch`, `team`, `say`, `mark`, `status`, `watch`, `close` and `restart`. Headless servers, containers and CI runners are unsupported. `help`, `--version`, `completion`, `init`, `upgrade` and `configure` do not need `hc` or `herdr-app`. Pane splits use the app default ratio; the board divider is not set to 0.3. The storage paths `~/.herdr/crew` and `~/.herdr/worktrees` are unchanged.

The first `launch` or `team` initializes the primary project's `.herdr-crew/` baseline automatically. To initialize without launching agents, run `herdr-crew init`. Initialization preserves existing files and imports valid `.herdr-crew.json` assignments into `.herdr-crew/config.json` while retaining the legacy file. Use `herdr-crew upgrade` to preview baseline changes. Apply a selected path only with the source and target hashes from that preview: `--apply PATH --expect SOURCE_SHA256 --expect-target TARGET_SHA256_OR_absent`. `--json` exposes those values as `sourceHashes` and `targetHashes`. Upgrades do not overwrite customizations unless you select that path.

Project agent guidance is stored in `.herdr-crew/agents/<id>/AGENTS.md`; validated `agent.json` selects an existing permission profile. Project jobs can be launched through a team that references them; native enforcement and live launches remain unverified. When asked to configure runtime assignments, run `herdr-crew configure --show` first, then use `herdr-crew configure <rank-or-job> <claude|opencode|command-code> [--model MODEL] [--effort EFFORT]` with the user's requested assignments. `all` sets profile defaults while preserving job overrides. The human wizard is `herdr-crew configure`; agents use arguments instead of an interactive prompt. Runtime settings are in the main project's `.herdr-crew/config.json`, shared across its worktrees. Unsupported agents fail explicitly. OpenCode requires version 2. For OpenCode effort, supply an explicit `--model` and a variant supported by its project catalog; `--effort inherit` uses the model default. The human wizard lists available models and their variants. Catalog lookup uses a private metadata server without creating an agent session or submitting a prompt. Command Code requires `cmd` 1.88.5 or later, and its configuration token is exactly `command-code`; the wizard's model list comes from `cmd --list-models`, cached for a day at `~/.herdr/crew/command-code-models`. Command Code model IDs may be `provider/model` or plain, such as `claude-sonnet-5-5`, and have no `#variant`, so effort stays in its own field. If that catalog cannot be read, the adapter warns and validates the ID's syntax only. Command Code gets its rank policy from a per-session TypeScript mod started with `--mod`: inspectors run with `--permission-mode plan`, the other ranks with `yolo` plus mod deny rules, and the mod disables the `agent` and `agent_output` tools. It has no transcript hook, so its one-time context warning is best-effort from the mod reading `cmd.getContextUsage()`; a live headless run returned no token count, so monitor context and hand off before compaction. Native `write_file`/`edit_file` blocks cover the manager and inspector only, and the member Git block matches command text, so it is not an OS sandbox. Restarts retain saved runtime selections and definitions, including the saved argv and mod path.

Run the launcher. Pass the instructions on stdin so quoting never breaks:

```bash
herdr-crew launch <spec> - <<'EOF'
<instructions from the user, verbatim>
EOF
```

Spec forms:
- `lead`: starts the crew (lead + manager + board) in a new app tab. Re-running it sends the new instructions to the running lead.
- `<rank>@<job>`, e.g. `member@driver`, `inspector@navigator`.
- `<job>` alone is shorthand: `driver` = `member@driver`, profile taken from its metadata.
- Add domain personas with `+`: `member@driver+nestjs-expert`, `inspector@code-reviewer+security-paranoid`.

Profiles (permissions, installed under `agents/crew-*/` and copied into each project's `.herdr-crew/agents/`):
- `lead`: talks to the user, owns the tsk board, asks before any merge.
- `manager`: started by lead. Spawns teams, watches workers. Never edits code.
- `member`: read-write in its own worktree, commits on its branch, never pushes.
- `inspector`: read-only. Investigates, reviews, navigates, triages, tests.

Bundled agents (`agents/`, have `agent.json` metadata and `AGENTS.md` guidance): driver, tester, qa-bug-reproducer, planner (member); navigator, code-reviewer, qa-bug-triager, investigator (inspector). A job sets the team slot and its skills. Projects can add job IDs with one of the existing profiles; the profile's native policy remains authoritative.

Domain guidance (`personas/`, stackable on any job): pragmatic-senior (default when none given), nestjs-expert, react-expert, ui-expert, security-paranoid.

For clean UI design and development, use the `ui-expert` domain. It combines Impeccable with React engineering, preserves existing design systems, and requires desktop/mobile browser verification. The manager selects it for UI tasks and keeps it on each review round:

```bash
herdr-crew team pair T7 --persona driver=ui-expert --persona navigator=ui-expert
herdr-crew team review T7 --persona code-reviewer=ui-expert
```

To create a new task directly, launch `member@driver+ui-expert` with the user's instructions on stdin. That attaches the domain to the driver; use the explicit pair command above when both pair members need it.

Teams (`teams/`), chosen from the job:
- pair: driver, navigator. Own worktree.
- bug-validate: qa-bug-triager, qa-bug-reproducer. Own worktree.
- review: code-reviewer. Detached checkout of `crew/T#-pair`, so run pair first. A review spec on a new task is refused before anything starts.
- test: tester. New branch `crew/T#-test` from `crew/T#-pair` if it exists, else HEAD.
- investigate: investigator. Reads the current repo without a new branch or worktree. Saves answers in tsk.
- plan: planner. Own worktree and planning branch. Writes Markdown/Mermaid plus an uncommitted local review page; product files stay unchanged.

For requested visual planning, Lead sends `Run T<n> (plan)` through Manager. Read the installed `docs/planning/visual-plan-contract.md` and template. Manager's `plan ready:`/done result completes drafting only. Lead presents the page or Markdown, records explicit user approval against commit/hash and scope in tsk, then dispatches implementation. Test/simulation feedback is not authorization. Revisions reopen the same planning task and retain version/approval history; material revisions need new approval. A standalone planner stays at review for manual acceptance. Lead/Manager remain without file-writing tools.

The manager runs pair -> review -> fix rounds (max 3) -> done on its own for authorized development; the user merges.

For project questions, send one question or a numbered batch to the Lead. Quick lookups use a read-only Explore helper with `model: haiku` (expected resolution: Haiku 5.5, `claude-haiku-5-5`) and `effort: medium`. Deeper questions go through the Manager to `investigate`. Answers include source citations, inspected source version, and verification gaps. The Manager checks answer coverage and marks done without the development review loop.

Follow-ups to active investigations become numbered task steps. After completion, fresh exploration uses a linked new task and refreshed evidence. Investigation does not authorize a fix. A direct `herdr-crew launch investigator -` saves answers at `review`; without a running Manager, the user reads them with `tsk list T<n> --json` and accepts them manually.

Examples:
- `herdr-crew launch lead -` starts the crew.
- `herdr-crew launch driver -` creates a task and runs the pair team.
- `herdr-crew launch member@driver+nestjs-expert -` same, with the NestJS persona on the driver.
- `herdr-crew launch investigator -` creates a read-only project investigation task.
- `herdr-crew launch planner -` creates a documentation-only visual planning task; it does not authorize implementation.

The manager can add domain personas to a team slot: `herdr-crew team pair T2 --persona navigator=security-paranoid`.

Invalid input (unknown profile or agent, or a job assigned to an incompatible profile) fails before anything starts.

Then relay the command output to the user in one or two lines (tab label, agents started, or the error).

Other commands: `herdr-crew status`, `herdr-crew read <agent> [--lines N]` and `herdr-crew wait <agent> [--timeout S]` (read or wait on the agent's saved terminal), `herdr-crew close <T#> [<team>]` (closes tabs with matching label prefixes, prints the worktree removal command, never removes it), `herdr-crew watch` (the lead runs it in Monitor: one line per board change), `herdr-crew handoff "<status>" < body` (an agent saves its handoff when it nears the context budget), `herdr-crew restart <agent|T#>` (reuses the same terminal, sends `/exit`, waits for a shell prompt or a null status, then sends the saved command and brief). Restart never creates a tab. A finished terminal means the pane is gone: relaunch the team. A blocked agent needs a person.

`herdr-crew say` sends to an idle or done agent. For a working agent it waits 20 seconds, then sends if the agent is idle or done. A blocked, still-working or no-terminal recipient gets one queued `[msg from X to Y]` task step when its saved task exists; otherwise the command warns that the message was not delivered. An unknown agent only gets a warning. A busy recipient never fails the command, and a blocked send is never forced.

`herdr-crew help` lists the commands, and `herdr-crew help <command>` shows one command's arguments, options and examples. Both work without tsk, `hc`, `herdr-app` or jq on PATH. Result lines start with `crew:`, progress lines with `->`, and warnings with `warning:` on stderr.

Context budget: Claude sessions register the project's `hooks/context-limit.sh` per session and default to 135000 tokens. It is advisory, runs on supported Claude hook events, and requests a handoff once per session; it does not force a stop or cap billing. OpenCode has no automatic crew context warning or asynchronous Monitor tool; its runtime brief specifies direct lookups, portable skills and bounded waits with explicit monitoring limits. Subagents are disabled under its native profile policy. Command Code also has no transcript hook or Monitor tool: its session mod reads `cmd.getContextUsage()` after a tool call and attempts one handoff instruction at `CREW_CTX_LIMIT`; the call can report no tokens, so treat the warning as best-effort and hand off before compaction. Its `onSessionStart` removes the subagent tools; a live headless run confirmed that removal and the member `git push` block. Completion result delivery is not yet an automatic runtime hook; use `herdr-crew mark` or `herdr-crew handoff` and retain task evidence. Agents write a handoff before compaction; their initiator restarts them.

If the output says the app window is unreachable, tell the user to start the Herdr desktop app and rerun there.

AXI tools: bundled or project agents can declare `axi:` in `agent.json`. The brief lists them; the launcher warns if one is not on PATH.

Install: missing persona skills, plugins and AXI tools are reported by `~/.claude/skills/herdr-crew/bin/install-skills [--check] [-y]`; it asks before each install. Sources are in `skills.sources`.
