# herdr-crew reference

Profiles, personas, teams, commands, output conventions, environment variables and AXI tools. For installation, see the [quick start](./quickstart.md). For day-to-day flows, see [usage](./usage.md).

## Profiles

A profile sets what an agent may do. Bundled profiles live in `agents/crew-*/{AGENTS.md,agent.json}` and are copied into each project's `.herdr-crew/agents/`. The launcher passes the selected definition and native permission settings to Claude per session; project job guidance cannot add profile tools or change its permission mode.

| Rank | What it can do | Model | Effort | Communication style | AXI tools |
|---|---|---|---|---|---|
| `lead` | Talks to you, owns the board, asks before any merge. Does not edit code. | opus | high | Simplified Technical English (short, plain sentences) | gh-axi, lavish-axi |
| `manager` | Starts teams, watches workers, reports to the Lead. Does not edit code or merge. | haiku | max | Very terse, with filler words removed | quota-axi |
| `member` | Reads and writes files in its own worktree and commits on its branch. Never pushes or merges. | haiku | high | Default | none |
| `inspector` | Read-only. Reviews, navigates, triages bugs, runs tests. | haiku | xhigh | Default | none (see AXI tools) |

These are bundled defaults. Runtime assignment settings can override agent and model selection. Effort sets how much the model thinks before it answers. A job's `agent.json` can set effort; explicit project settings take precedence.

## Personas

Bundled job agents have an `agent.json` profile and fill a team slot. Their instructions are in `agents/<id>/AGENTS.md`. Domain guidance in `personas/` can be added to any job. If none is given, `pragmatic-senior` is used. A project can define additional agent IDs under `.herdr-crew/agents/` with a matching `AGENTS.md` and validated metadata.

| Persona | Kind | Rank | Skills | AXI tools | Effort | Purpose |
|---|---|---|---|---|---|---|
| `driver` | job | member | tdd, verification-before-completion, karpathy-guidelines, ponytail, systematic-debugging | gh-axi | high | Writes code test-first in its worktree |
| `tester` | job | member | tdd, verification-before-completion | chrome-devtools-axi | none | Writes and runs test files only |
| `qa-bug-reproducer` | job | member | diagnosing-bugs | chrome-devtools-axi, gh-axi | none | Tries to reproduce a bug. May add one failing test file only. |
| `navigator` | job | inspector | ponytail:ponytail-review, verification-before-completion | none | none | Watches the driver live, runs tests, gives a verdict |
| `code-reviewer` | job | inspector | code-review, ponytail-review | gh-axi | max | Reviews a branch against the repo's standards and the task |
| `qa-bug-triager` | job | inspector | qa-bug-validator | gh-axi | none | Decides if a reported bug is real, by reading the source |
| `investigator` | job | inspector | none | none | inherited | Answers project questions and traces flows with source evidence; writes answers to tsk |
| `planner` | job | member | none | lavish-axi | inherited | Writes source-grounded visual plans only; reports draft version for user approval |
| `pragmatic-senior` | domain (default) | any | karpathy-guidelines, ponytail | none | none | Makes the smallest change that solves the task |
| `nestjs-expert` | domain | any | nestjs-best-practices, context7-mcp, supabase, supabase-postgres-best-practices | none | none | NestJS and Node backend work. Postgres or Supabase work loads the two Supabase skills first. |
| `react-expert` | domain | any | react-production-engineering, react-component-engineering, react-quality-engineering, context7-mcp | chrome-devtools-axi | none | React and TypeScript work. Next.js repos also load vercel-react-best-practices. |
| `ui-expert` | domain | any | impeccable, react-component-engineering, react-production-engineering, react-quality-engineering | chrome-devtools-axi | none | Clean UI design and development; desktop/mobile browser evidence. Marketing, motion, and UI review skills load when relevant. |
| `security-paranoid` | domain | any | none | none | none | Treats every input as hostile, with an exploit scenario for each issue |

## Teams

A team is a group of jobs plus a worktree rule. The files live in `teams/`.

| Team | Members | Worktree and branch |
|---|---|---|
| `pair` | driver (member), navigator (inspector) | New branch `crew/T#-pair` in its own worktree |
| `review` | code-reviewer (inspector) | Detached checkout of `crew/T#-pair`. Run `pair` first. |
| `test` | tester (member) | New branch `crew/T#-test`, from `crew/T#-pair` if it exists, else from HEAD |
| `bug-validate` | qa-bug-triager (inspector), qa-bug-reproducer (member) | New branch `crew/T#-bug-validate` in its own worktree |
| `investigate` | investigator (inspector) | Current repo, no new branch or worktree |
| `plan` | planner (member) | New or retained `crew/T#-plan`; documentation artifacts only |

Worktrees live at `~/.herdr/worktrees/<slug>/T<n>-<team>`. The `<slug>` is the first six characters of the repository folder name, plus four hex characters from a hash of the repository path, so two repositories with the same name stay apart. Agent names look like `<slug>-t<n>-<job>`, such as `my-app-3f9c-t7-driver`. The Lead is `<slug>-lead` and the Manager is `<slug>-manager`.

## Commands

Every command explains itself. `herdr-crew help` lists them, `herdr-crew help <command>` and `herdr-crew <command> --help` show one command's arguments, options and examples, and `herdr-crew --version` prints the version. All five help forms work without tsk, `hc`, `herdr-app` or jq on PATH. Git is still required, because repository and slug resolution runs first. Global options go before the command: `--dry-run` (the same as `CREW_DRY_RUN=1`), `--help`, `--version`.

| Command | What it does |
|---|---|
| `herdr-crew launch <spec> -` | Starts a crew (`lead`), or a new task with its team (a job spec). Instructions come on stdin, or as words after the spec. Needs the app. |
| `herdr-crew team <team> <T#> [--persona <job>=<domain>[+<domain>]]... ["instructions"]` | Starts a team for an existing task. Refuses if a requested agent already has a live saved terminal; use `say` or `restart`. Optional instructions override the task notes for the brief. Uses `CREW_WS`, then the caller app terminal's `herdr.space` label, then `crew-<slug>` outside an app terminal. |
| `herdr-crew say <agent> "<message>"` | Sends when the agent is idle or done. For a working agent it waits 20 seconds, then sends if the agent is idle or done. A blocked, still-working or no-terminal recipient gets one queued `[msg from X to Y]` task step when its saved task exists; otherwise the command warns that the message was not delivered. An unknown agent only gets a warning. A busy recipient never fails the command, and a blocked send is never forced. |
| `herdr-crew read <agent> [--lines N]` | Reads the saved terminal for an agent. Options pass through to `hc read`. |
| `herdr-crew wait <agent> [--timeout S]` | Waits on the saved terminal for an agent. Options pass through to `hc wait`. |
| `herdr-crew mark <T#> <status> "<note>"` | Sets the task status, adds the note as a step, and renames the saved tab to `<label> · <agent>: <note>`. The label keeps its `T# TEAM` prefix. |
| `herdr-crew status [--json]` | Prints one line per open task (T number, status, title) and one per crew agent (name, state), tab separated. States come from the saved terminals. `--json` prints the raw task list for scripts. |
| `herdr-crew close <T#> [<team>]` | Closes tabs by label prefix and tab ID. Without a team, matches `T# ` and never `T70`; with a team, matches `T# <team>` exactly or followed by ` · `, including renamed labels such as `T7 pair · driver: note`. Keeps worktrees and prints removal commands for existing paths. |
| `herdr-crew watch` | Prints one line per board change: task status, a crew agent that became `blocked` or `done` or disappeared, and each new handoff. The Lead runs it with Monitor. Press Ctrl+C to stop. |
| `herdr-crew handoff "<status>"` | Saves the handoff body from stdin, adds a step to the task, and tells the agent that restarts this one. Run by the agent itself. |
| `herdr-crew restart <agent or T#>` | Sends `/exit`, waits for a shell prompt or a null status, then sends the saved agent command and brief in the same terminal. Never creates a tab. A finished terminal fails; relaunch the team. A `T#` restarts every agent of that task. |
| `herdr-crew completion <bash\|zsh>` | Prints a shell completion script on stdout. |

## Output style

Result lines start with `crew:`, progress lines with `->`, and warnings with `warning:`. Colour is used only when stdout is a terminal, and `NO_COLOR` turns it off. Errors go to stderr, name the problem, and list the valid values or the next command to run. Long operations print a progress line for each agent they start, because an agent start can take minutes.

## Environment variables

The launcher sets these in each terminal it creates:

| Variable | Meaning |
|---|---|
| `CREW_SLUG` | The crew id, such as `my-app-3f9c` |
| `CREW_REPO` | Path to the repository |
| `CREW_TASK` | Task number in team terminals, such as `T7`. Empty in Lead and Manager terminals. |
| `CREW_AGENT` | This agent's name. `say` and `mark` use it as the sender. Defaults to `user`. |
| `CREW_MANAGER` | The Manager's agent name |
| `CREW_WS` | The herdr-app space ID that holds the crew |

Claude agents receive a SessionStart hook that restores these variables for Bash commands on startup and resume. Agents started before this hook was added need `herdr-crew restart <agent>` to receive it.

You can set `CREW_REPO` and `CREW_SLUG` yourself to override the repository path and crew id. Set `CREW_DRY_RUN=1` to print mutating app, core, tsk and Git calls instead of executing them. Discovery reads and dependency checks still run; this is a mutation preview, not an offline simulation.

For all environment controls, command options, hook behavior, and completion flows, see [the feature reference](./features.md).

## AXI tools

AXI (Agent eXperience Interface) is a set of command-line tools built for agents. Their output is short and consistent, so an agent spends fewer tokens on it than on raw CLI output. See <https://axi.md>.

Bundled job agents and profiles declare AXI tools in `agent.json`; domain personas may declare them in frontmatter. The tables above show the mapping:

- The lead uses `gh-axi` and `lavish-axi`. The manager uses `quota-axi`. The planner uses `lavish-axi` for the review projection.
- The driver and the code reviewers use `gh-axi`. The driver never pushes, merges, or creates PRs with it.
- The tester and the react-expert use `chrome-devtools-axi`.

Inspectors are read-only. Their tool list allows only read-only `gh-axi` and `chrome-devtools-axi` commands. The inspector rank has no `axi:` line, so its brief does not list them.

The launcher adds the tools to each agent's brief. If a tool is not on PATH, the launcher prints a warning and still launches the agent. `install-skills --check` reports each AXI tool. Without `--check`, it offers to run `npm i -g <package>` for each missing tool, and it does nothing unless you answer yes.

The lead's tool list allows `gh-axi *`, which includes `pr merge`. Only the lead's rule to ask before any merge stops it. The `tasks-axi` tool is not used, because tsk is the task board.
