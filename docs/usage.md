# Using herdr-crew: teams, tasks and handoffs

This page covers day-to-day use after the crew is installed. For installation, see the [quick start](./quickstart.md). For profiles, personas, teams and every command, see the [reference](./reference.md).

## Start one team directly

For a small job you can skip the Lead. A spec has the form `<rank>@<persona>[+<persona>]`, or it can be a job persona alone. The rank sets what the agent may do, as described in the [reference](./reference.md#profiles).

- `driver` starts a pair team for a new task. The rank comes from the persona, so this means `member@driver`.
- `member@driver+nestjs-expert` does the same, and the driver also gets the NestJS persona.
- `investigator` starts a read-only investigation for a new task.
- Reviews use `herdr-crew team review T<n> --persona code-reviewer=security-paranoid` on an existing pair task. A fresh code-reviewer launch is refused.

```
/herdr-crew driver "Fix the login redirect loop"
```

For an existing task, `herdr-crew team pair T<n>` reuses its branch and retained worktree, preserving uncommitted files. A branch checked out elsewhere or an unrelated directory still causes an error.

The first line of your text becomes the task title, and the full text becomes the notes. The task starts as `ready`, and the selected team opens using its configured worktree rule.

The `review` team checks out the `crew/T#-pair` branch, so it needs a task that already has that branch. A spec such as `inspector@code-reviewer` is refused before anything starts: no task is created and nothing is started. To review a task with a pair branch, ask the Lead, or run `herdr-crew team review <T#>` inside a crew pane.

## Pick personas for a team

A `--persona` flag swaps the persona in a team job. The Manager can do this when the Lead asks. You can also run it yourself inside a crew pane:

```bash
herdr-crew team pair T12 --persona driver=nestjs-expert --persona navigator=security-paranoid
```

The part before `=` is the job, and the part after `=` is the domain persona. Stack several with `+`.

`team` resolves its space in this order: the `CREW_WS` value, the `herdr.space` label on the caller's app terminal, then the `crew-<slug>` space. The `crew-<slug>` fallback applies outside an app terminal. If that space does not exist, the launcher creates it.

## Check status

```bash
herdr-crew status
```

It prints one line per open task in the form `T<number><TAB><status><TAB><title>`, then one line per live agent in the form `<agent name><TAB><state>`. States are `idle`, `working`, `blocked`, and `done`, plus `error` when the runtime reports it. An agent with no reported status is omitted. Add `--json` to print the raw task list instead, for scripts.

## Watch the board

The Lead watches the board on its own. It runs `herdr-crew watch` in the Monitor tool, which polls every 20 seconds and prints one line for each change:

```
T7 ready -> review: fix the login bug
my-app-3f9c-t7-driver blocked
handoff my-app-3f9c-t7-driver /home/you/.herdr/crew/my-app-3f9c/handoff-my-app-3f9c-t7-driver.md
```

Unchanged state prints nothing. Set `CREW_WATCH_SECS` to change the interval. Press Ctrl+C to stop it. The Manager also uses Monitor for worker waits, so it can handle messages while workers run.

## Close a team

```bash
herdr-crew close T12
herdr-crew close T12 review
```

Without a team, this closes tabs whose labels start with `T12 `; it never closes a tab named `T120`. With a team, it closes tabs whose labels start with `T12 <team>`. For example, `close T12 review` also closes a renamed tab such as `T12 review · driver: done`. It resolves each tab by its label, then closes the tab by ID. It keeps the worktrees and prints the command to remove each one, such as `git -C <repo> worktree remove <path>`. It never runs that command itself.

## Talk to a running crew

Run the same command again with new text:

```
/herdr-crew lead "Also add a test for the empty report case"
```

The launcher sees that a Lead is already running. It sends your text to that Lead and does not start a second crew.

## Ask for a visual plan before implementation

Tell the Lead what you want planned:

```text
/herdr-crew lead "Plan the checkout retry change. Show the flow and failure cases before implementing it."
```

The Lead sends a planning task to the Manager, which starts one `planner` in a separate worktree. The planner writes a Markdown plan with Mermaid source and a local visual review page. You see the goal, before/after, a small component/activity overview, optional sequence/state detail, and tasks with exact files, regressions and verification commands.

The planner checks target source against its retained snapshot before drafting or revising. Relevant dirty changes or source drift block progress until you choose the source explicitly; nothing is reset or merged automatically. The Lead rechecks source before implementation dispatch.

The Manager's `plan ready:` completion means the draft is available. The Lead presents it and asks you to approve its commit/hash and scope before implementation starts. Test/simulation feedback, annotations and completed drafting tasks do not authorize implementation. Approval stays in tsk; changing the canonical plan materially requires a new version and approval. If the browser is unavailable, review the Markdown instead.

You can request revisions on the same planning task. The retained planning branch/worktree preserves versions and source evidence across sessions; the handoff records task, paths, commit/hash, approval, gaps and next action. The planning branch does not need to be merged just to read the approved plan. A small explicitly authorized fix or a source-only question keeps its existing route when planning is unnecessary.

For an optional standalone draft, use `/herdr-crew planner "<what to plan>"` or `herdr-crew team plan T<n>` for an existing task. A standalone planner stays at `review` for manual acceptance. It does not create a Manager or authorize implementation. The target repository needs a commit for a planning worktree; an unborn repository is reported as a prerequisite instead of receiving an unsolicited initial commit.

Read the [plan contract](./planning/visual-plan-contract.md), [template](./planning/visual-plan-template.md), [worked example](./planning/examples/handoff-plan.md), and [acceptance checklist](./planning/acceptance.md). The documentation-only worker scope is enforced by instructions and review, not a new filesystem sandbox. Local `.lavish/` output is kept out of commits even if the target does not ignore it. The existing restart handoff-file race remains unresolved; this feature does not establish live restart continuity.

## Ask questions about the project

Send ordinary questions to the Lead: "Does session expiry exist?" or "How does login reach storage?" You can ask one at a time or provide a numbered batch:

```text
1. Does session expiry exist?
2. Is password reset connected to the login screen?
3. How does a login request create a session?
```

The Lead delegates quick lookups to a read-only Explore sub-agent using Haiku 5.5 (`claude-haiku-5-5`) with medium effort. The tested Agent schema accepts the `haiku` alias rather than a full model ID; the Lead reports when exact pinning or model resolution cannot be verified. Claude Code 2.1.292 or later supports the per-invocation effort setting; Haiku 5.5 requires 2.1.293 or later. The Lead reports unsupported or overridden settings instead of silently substituting them.

For deeper investigation, the Manager starts the `investigate` team. Its inspector reads the current repository without creating a branch or worktree. Each question gets a direct answer, a short explanation, `file:line` evidence, the inspected source version, and any verification gaps. The Manager checks answer coverage. The Lead then reports the results.

Source inspection explains what is implemented and connected. It does not establish what is deployed or working in production. Absence claims include the searched scope. An unused definition or disabled feature is reported as partial or unreachable, rather than fully working.

Ask an active follow-up normally, such as "What happens when that session expires?" The Lead adds a numbered question to the task. If the investigation has ended, a follow-up that needs fresh exploration uses a new linked task and rechecks the source. Earlier answers remain in tsk. A discovered bug does not automatically start a fix.

For an optional standalone investigation:

```bash
herdr-crew launch investigator - <<'EOF'
1. Does session expiry exist?
2. How does login reach storage?
EOF
```

Run this inside an app terminal. Read the resulting answers with `tsk list T<n> --json`, using the task number printed by the launcher. Without a running Manager, the task stays at `review` for manual acceptance. It does not claim `done` automatically. You can also ask the Manager to run `herdr-crew team investigate T<n> --persona investigator=nestjs-expert` for a backend investigation.

A separate investigator costs another agent session and coordination. Quick facts stay with the existing helper path. Investigation closes after its answers are accepted; it is not a permanently running project index.

## Context budget and handoffs

Claude agents have a warning budget of 135000 tokens, set with `CREW_CTX_LIMIT`. A saved copy of the project's context hook warns once per session when it reaches the budget. OpenCode agents must monitor context themselves; they do not receive this hook. The agent then writes a handoff and stops:

```bash
herdr-crew handoff "half done, tests pass" <<'EOF'
Goal, what is done, what is in progress, next steps, files, task number.
EOF
```

The handoff is saved to `~/.herdr/crew/<slug>/handoff-<agent>.md`, and the task gets a `[handoff]` step. The agent that started it, the manager for a worker, is told. It restarts the agent with `herdr-crew restart <agent>`, or restarts a whole team with `herdr-crew restart T12`. A restart reuses the same terminal: it sends `/exit`, waits for a shell prompt or a null status, sends the saved exact agent command, waits for readiness, then submits the saved brief with a line that points to the handoff. The launcher drops its own agent identity for these sends, so `hc` does not wrap `/exit` or the saved command in `<hc from=...>` note tags. It never creates a tab. If the terminal reports `finished`, its pane is gone and the restart fails; relaunch the team. A blocked agent needs a person before it can restart.

## Merge the work

Merging is always your decision. Crew instructions require approval before a push, merge, or worktree removal. Member sessions also receive explicit Bash denies for `git push` and `git merge`. A completed development task has passed code review and can have a branch such as `crew/T7-pair` for you to merge. A completed investigation contains answers and has no merge branch. The Lead has no direct Git command access, but its gh-axi allowlist includes merge operations; its approval rule remains necessary.

## Workspace and tab selection

- The launcher first uses `CREW_WS`, then the `herdr.space` label on the caller's app terminal.
- Outside an app terminal, it falls back to a live space named `crew-<slug>`. It creates an empty space if needed, then creates the first real tab with the space ID in its environment.
- Without a running app window, runtime commands stop with a clear error. Headless use on a server, container or CI runner is unsupported.
