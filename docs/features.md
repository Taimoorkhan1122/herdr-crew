# Current feature reference

Checked against the implementation worktree on 2026-10-30. The project-owned baseline and agent registry are present; hook integration and final whole-change verification remain in progress. This inventory describes source behavior, not live acceptance. [STATE.md](STATE.md) records evidence and open gaps. The [README](../README.md) provides the user walkthrough.

## Commands and options

The launcher is [bin/crew](../bin/crew). Runtime commands require tsk, jq, and herdr on PATH. Configure only needs jq and the standard local utilities; it does not invoke Herdr/tsk or start agents. Other used utilities include Bash, Git, rg, shasum, readlink, awk, sed, and standard shell utilities. The terminal UX layer is [lib/ux.sh](../lib/ux.sh).

`--help`, `--version`, `help`, `help <command>` and `<command> --help` are pure text. They run before the jq, tsk and herdr checks, so they work on a machine that has none of the three. Repo and slug resolution still runs first, so Git is required for every invocation, help included.

| Command | Inputs and behavior |
|---|---|
| `init [--json]` | Creates the primary project's `.herdr-crew/` baseline, preserving existing files. Imports valid legacy `.herdr-crew.json` assignments only when no new config exists; keeps the old file. First `launch`/`team` initializes automatically. `--dry-run init` writes nothing. |
| `upgrade [--json] [--apply PATH --expect SOURCE_SHA256 --expect-target TARGET_SHA256_OR_absent]...` | Without `--apply`, previews differing baseline paths and their source/target hashes. Applies only explicitly selected paths whose two hashes still match the preview; updates only their provenance entries. |
| `configure [--interactive \| --show \| ROLE AGENT [--model MODEL] [--effort EFFORT]]` | Human wizard or noninteractive per-project assignment; shows effective rank/job settings. Supports Claude and OpenCode 2. EOF cancels the wizard; invalid input leaves the file unchanged. `all` sets four rank defaults and preserves job overrides. |
| `launch <spec> -` | Reads instructions from stdin. Without `-`, remaining words are instructions. Empty instructions fail. `lead` starts Lead, Manager, and board; a job creates a ready tsk task and starts its configured team. |
| `team <team> <T#> [--persona <job>=<domain>[+<domain>]]... ["instructions"]` | Starts an existing task's team. Repeat `--persona` for different slots. Explicit instructions override task notes in the brief. With no instructions, reads task notes. |
| `say <agent> "<message>"` | Sends to idle/done agents, or waits up to 20 seconds. If a task worker stays busy, appends a tagged message to its task. Lead/Manager names have no T number; when busy, their message can remain undelivered despite exit 0. Check the output. |
| `mark <T#> <status> "<note>"` | Runs tsk status, appends the note as a step, and reports pane metadata. These are separate calls, not one atomic transaction. |
| `status` | Prints one line per open task (T number, status, title) and one per known crew agent (name, state), tab separated. Completed tasks are normally excluded by tsk's default list. `status --json` prints the raw task list. |
| `close <T#> [<team>]` | Closes matching tabs in the selected workspace. Without a team, matches the `T# ` label prefix. With a team, matches its exact label. Retains worktrees and prints removal commands for existing paths. |
| `watch` | Polls open and done tasks, known crew agents, and handoff files. Prints status changes, blocked/done/disappeared agents, and new handoffs. A failed task read retains the prior snapshot. |
| `handoff "<status>"` | Reads the multiline body from stdin, or uses the existing handoff file. Adds a task step when CREW_TASK exists and notifies the initiator. Does not terminate the agent itself. |
| `restart <agent\|T#>` | Reads saved rank/job/pane/task/brief and resolved agent/model/effort. The original pane environment preserves OpenCode native session policy. Configuration edits apply only to new launches. Requests exit, waits up to 30 seconds for the pane's shell, then starts again. Adds an existing handoff pointer and archives the handoff after startup. A T number selects all saved agents of that task. |
| `help [<command>]` | Prints the command list, or one command's arguments, options and examples. Same text as `<command> --help`. |
| `completion <bash\|zsh>` | Prints a shell completion script on stdout. Unknown or missing shells fail. |
| `--help`, `-h` | Global, before the command. Prints the command list and exits 0. |
| `--version`, `-V` | Global, before the command. Prints `git describe` for the installation, or `dev`, and exits 0. |
| `--dry-run` | Global, before the command. Same effect as `CREW_DRY_RUN=1`. |

Global options must come before the command, so instructions can never be read as an option. `--help`, `--version`, `help`, `help <command>` and `<command> --help` run before the tsk, herdr and jq checks, so they work on a machine that has none of them. Git is still required, because repo and slug resolution runs first.

## Output and help

[lib/ux.sh](../lib/ux.sh) holds the terminal layer. `bin/crew` sources it before the jq, tsk and herdr checks, and the dispatch handles every pure-text path before those checks. So `--help`, `--version`, `help`, `help <command>` and `<command> --help` work with none of the three on PATH. Git is still required for every invocation, because repo and slug resolution runs first.

- Result lines start with `crew:`, progress lines with `->`, warnings with `warning:` on stderr. Warnings never fail a command.
- Colour is used only when stdout is a terminal, and `NO_COLOR` or `TERM=dumb` turns it off. Colour decorates the words; it never replaces them, and no message text changed.
- Errors go to stderr, name the problem, and give the valid values or the next command: the team list for an unknown team, the ranks and personas for an unknown name, and the install hint for a missing runtime.
- `start_agent` prints a progress line per agent, because an agent start can block for minutes.
- `watch` handles Ctrl+C: it prints `crew: watch stopped` and exits 130.
- `status` no longer prints the raw task JSON. Use `status --json` for that form.

Spec forms are `lead`, `<rank>@<job>[+<domain>]`, or a bare job. `lead@<domain>` also uses the parser's domain composition. One job is allowed per spec, and its rank must match. Unknown names and invalid team persona slots fail before launch mutations. A fresh code-reviewer launch is refused because it lacks an existing pair branch.

## Project baseline, definitions and identity

- Installed definitions are in `agents/<id>/{AGENTS.md,agent.json}`. The four `crew-*` directories define the existing permission profiles; bundled jobs reference one of those profiles. Metadata is validated JSON, and job definitions cannot supply tools, permission modes or other policy overrides. `personas/` holds stackable domain guidance.
- `init` copies missing files from `agents/`, `personas/`, `teams/` and `hooks/` into the primary project's `.herdr-crew/`. `.herdr-crew/config.json` stores runtime assignments and `baseline.json` records source version and applied file hashes. Existing custom files are skipped. Valid `.herdr-crew.json` is imported only on first initialization and retained byte-for-byte; if both formats exist, the new directory is used and the legacy file is reported.
- `upgrade` is an explicit preview/apply flow. Preview includes both installed-source and project-target hashes. Every `--apply` must provide both reviewed values (`absent` for a missing target); drift fails before replacement. The selected path and its provenance hash are updated; unselected paths remain untouched. Writes use staging, validation, a project lock and a recovery copy. A recovery directory may remain after successful replacement.
- `launch` and `team` initialize a missing or partial project baseline automatically. Initialization does not install runtimes or skills. `configure` uses `.herdr-crew/config.json` and accepts discovered project agent IDs. Native enforcement and live launches remain unverified.

## Runtime configuration and identity

- [agents/](../agents/) defines the four permission profiles and bundled jobs. Profiles carry native tools/permissions and bundled defaults; jobs carry profile selection, skills, AXI tools and effort. Project jobs may customize guidance but not profile policy. The validated registry combines profile policy metadata with job instructions. Native launcher integration for project-specific definitions is still in progress; source presence and fake adapter assertions do not establish that a custom project agent is selected in a runtime.
- [personas/](../personas/) contains five stackable domains: pragmatic-senior, nestjs-expert, react-expert, ui-expert and security-paranoid. Default domain is pragmatic-senior.
- `.herdr-crew/config.json` (`version: 1`, `roles` keyed by profile alias or agent ID) in the primary project checkout sets `agent` and optional `model`/`effort`. Linked worktrees share even uncommitted settings. Separated Git metadata uses the verified primary top-level; ambiguous manually entered linked checkouts require `CREW_REPO` pointing to the primary checkout (already set for crew-created workers). Agent settings override profile defaults. Switching agent clears the previous runtime's inherited model/effort; changing an OpenCode model clears its inherited variant; `inherit` omits the flag explicitly. No user-wide override is read.
- `claude` and `opencode` (major 2) have native adapters. Other Herdr kinds are rejected. OpenCode effort selects a model-specific catalog variant; a non-default effort requires an explicit model. The wizard supports numbered or searchable model selection and offers only that model's variants. Catalog lookup uses `opencode api --standalone model.list` in the primary checkout, without creating an agent session or generating model output. The root model stays unqualified; the crew agent gets `provider/model#variant`. Configuration errors, missing binaries and unsupported versions are checked before new launch resources. `configure --show` does not check credentials/model availability.
- Restart retains the saved resolved definition and runtime selection; edits affect new launches. Legacy OpenCode sessions without a native session policy are refused on restart.
- [teams/](../teams/) defines members and worktree modes. The first member gets the root pane; later members split from it. `launch lead` has a special Lead/Manager/board layout.
- Slug: six normalized repo-name characters plus four path-hash characters, prefixed with `x` if needed. Worker names contain slug, lowercase task number, and job, truncated to 32 characters. Long customized names can collide; uniqueness is checked by Herdr at startup.
- Saved state lives at `~/.herdr/crew/<slug>/`: `<agent>.meta`, `<agent>.brief`, handoff files, and context-warning markers. This is separate from tsk's task storage.

## Flows and worktree rules

| Flow | Built contract and result |
|---|---|
| Development | Lead creates ready tasks; Manager starts pair. Driver uses TDD, commits, and marks review. Navigator gives `nav ok` or `nav fix:`. Manager runs code-review, requests fixes for `changes:`, blocks after three unapproved rounds, or marks done on `approve`. User controls merge/push/removal. |
| Pair | Driver + navigator; `new` creates or attaches `crew/T#-pair` from HEAD. Retained worktrees must match the repo and branch. Unrelated directories or branches held elsewhere are refused. |
| Review | Code-reviewer; `pair-branch` uses a detached checkout of `crew/T#-pair`. Missing pair branch fails. Repeat reviews reuse the checkout and move it to the pair's current commit. |
| Test | Tester writes only test files and commits them, then reports pass/fail at review. `from-pair` creates `crew/T#-test` from the pair branch, or HEAD if absent. Test-team changes are a separate branch. |
| Bug validation | Triager reads source; reproducer runs reproduction and may add one failing test file without committing. `new` creates `crew/T#-bug-validate`. Both report at review. No special automatic bug-validation completion loop is defined. |
| Quick project Q&A | Lead delegates a read-only Explore helper at medium effort, requesting Haiku 5.5. The tested schema uses the haiku alias. Answers include original Q number, source/version evidence, flow, scope, and uncertainty. No task is required for a small lookup. |
| Deep project Q&A (`investigate`) | Investigator in `worktree=none` reads the current repo. Saves numbered single-line answers, marks review with `answers ready:`, and reports to Manager. Manager checks coverage, marks done with `answered:`, and closes the tab. No development review or merge branch. |
| Q&A follow-ups | Active questions append `[question Q<n>]` steps. Investigator and Manager recheck steps before completion. Fresh exploration after completion uses a linked new task and refreshed evidence. A supported clarification can use identified earlier evidence. |
| Visual planning (`plan`) | One planner (member) writes plan Markdown/Mermaid and a local HTML/SVG projection in a new/retained crew/T#-plan worktree. Manager checks drafting coverage and reports plan ready; Lead records explicit versioned approval before development. Revisions reuse the task/worktree and retain approval history. No launcher subcommand or board state was added. |
| Standalone jobs | Direct launch creates the task and team, but does not create a Manager. Job results at review require manual acceptance or an existing Manager. |

Claude members use native edit permissions and session Bash denies for `git push`/`git merge`. Inspectors deny Edit/Write and have a restricted command list. Investigation further excludes test/build commands that may write. These are native tool permissions and instructions, not a separate operating-system sandbox.

OpenCode 2 uses `OPENCODE_CONFIG_CONTENT` supplied separately to every agent pane and `--standalone` so the private server reads that pane's policy. A generated primary agent embeds the rank body and runtime guidance. Ordered native permissions deny unknown tools, allow read/search/skills and the rank's shell allowlist, and give members edit/shell access followed by Git push/merge denies. Subagent actions stay denied; member external-directory access asks for approval. Managed runtime settings/trusted plugins remain authoritative. [ADR 0018](adr/0018-project-agent-config.md) records the source references and limits.

OpenCode replaces Claude-only helper/Monitor/plugin instructions with direct read-only lookups, portable skill loading and bounded waits. It has no crew context hook or asynchronous Monitor wakeup equivalent. Runtime prompts disclose that limitation. Full autonomous behavior and native permission enforcement remain live acceptance work.

## Visual planning contract

[Contract](planning/visual-plan-contract.md), [template](planning/visual-plan-template.md), [example](planning/examples/handoff-plan.md), and [acceptance checklist](planning/acceptance.md) define the draft format and review criteria. Canonical plans live in docs/superpowers/plans/ on their planning branches. One-line tsk evidence records source version, paths, commit/hash, checks/gaps, approval and linked work; HTML stays local and out of commits. A target may not ignore .lavish/, so the planner stages only exact Markdown paths and inspects the full index before committing.

The Lead and Manager keep their existing permissions. The planner inherits the broad member tools but is instructed to write planning artifacts only; domain implementation steps do not expand that scope. Approval is a real explicit user decision, distinct from test/simulation feedback, annotations and task completion. Approval metadata is outside the hashed Markdown. Material revisions require renewed approval. Manager drafting completion bypasses development review/test teams. Without Manager/manual acceptance, a standalone draft stays at review.

These are configured job/instruction contracts. Fake launch tests prove composition and declared routing, not agent compliance or live approval behavior. Browser fallback and known restart races remain explicit acceptance limits in STATE.

## Environment controls

| Variable | Default or use |
|---|---|
| `CREW_REPO` | Git root, or current directory if unavailable. Explicit override preserves main-repo identity across worktrees. |
| `CREW_SLUG` | Derived repo identity; explicit override is supported. |
| `CREW_AGENT` | Sender identity; defaults to `user` outside a crew agent. |
| `CREW_TASK` | Worker T number; empty for Lead/Manager. |
| `CREW_MANAGER` | Manager name provided to workers. |
| `CREW_WS` | Selected crew workspace; team uses this before workspace discovery. |
| `CREW_DRY_RUN` | Any nonempty value prints mutating Herdr/tsk/Git calls and uses fixture JSON. Reads and dependency checks still run. Local metadata, briefs, handoffs, and archives can still be written; use disposable HOME for isolation. |
| `CREW_CTX_LIMIT` | Context warning threshold, default 135000. The hook reads the worker environment. This variable is not one of the six exports explicitly forwarded/restored by the launcher; ensure the worker environment has a custom value. |
| `CREW_WATCH_SECS` | Watch interval, default 20 seconds. Applies to the watch process. |
| `NO_COLOR` | Any value turns off colour, like a non-terminal stdout. |
| `CREW_WATCH_ONCE` | `1` runs two polls and exits; a test control. |
| `HERDR_ENV`, `HERDR_WORKSPACE_ID` | Select the inherited workspace when inside Herdr. Otherwise the launcher finds or creates `crew-<slug>` on a running server. |
| `HERDR_PANE_ID` | Caller pane for metadata updates. Herdr supplies it. |

Every created pane explicitly receives CREW_SLUG, CREW_TASK, CREW_AGENT, CREW_MANAGER, CREW_REPO, and CREW_WS. A split does not inherit those values from the tab automatically.

## Hooks and startup recovery

The launcher snapshots project-owned hooks per session and registers the Claude context hook with `--settings`; it does not install global hooks. Explicit `mark` saves a result and invokes the saved completion hook to notify the coordinator. Failed delivery remains retryable. A crash after delivery but before the success marker can repeat a notification; a stale lock can also require intervention.

| Hook | Built behavior and limit |
|---|---|
| SessionStart | Appends shell-quoted exports for the six crew variables to CLAUDE_ENV_FILE when available. Restores Bash environment on startup/resume. |
| PostToolUse | Runs the saved project context hook. Reads the last main-thread assistant usage in the last 400 transcript lines: input + cache-read + cache-creation tokens. Subagent usage is excluded. |
| UserPromptSubmit | Runs the same guard. At or above `CREW_CTX_LIMIT`, writes a per-session marker and emits a handoff instruction once. The launcher default is 135000 tokens. |

The registered guard always exits 0. Missing or invalid usage becomes zero; a transcript-format change can therefore suppress warnings. It requests handoff but does not force termination or impose a billing limit. OpenCode has no registered context hook. Task completion is still explicit via `mark`/`handoff`; a process stop or a standalone result file is not accepted completion. There is no built test-rewriting PreToolUse hook.

Startup uses native rank/model/effort flags. The launcher can answer a recognized Claude trust dialog in a pane it started. Registry names are reclaimed only after the previous pane reaches its shell. Brief submission checks working/blocked/done; visible pasted text can receive another Enter. Ambiguous input is not resent. A warning requires inspection before any retry.

## Dependency installation

[bin/install-skills](../bin/install-skills) accepts `--check`, `-y`/`--yes`, and `-h`/`--help`. Unknown options exit 2. A successful check exits 0; missing, blocked, skipped, or failed required items produce exit 1.

It combines skill/AXI metadata in `agents/*/agent.json` with domain persona declarations and all skill names in [skills.sources](../skills.sources). It can link a skill from `~/.agents/skills`, replace a broken link after approval, fetch a verified repository skill, install a declared plugin, or install a missing AXI package through npm. Existing paths without SKILL.md are retained and reported blocked. UNKNOWN sources require manual installation. Approval defaults to No and reads `/dev/tty`; `--yes` accepts all prompts. `--check` does not install or link anything.

## Documentation and verification map

- [README](../README.md): usage, rank/persona/team tables, customization, examples, limits.
- [SKILL](../SKILL.md): agent entry point and launch instructions.
- [STATE](STATE.md): current verification scope and open issues. [PROGRESS](PROGRESS.md): dated history.
- [Project-agent evaluation procedure](research/project-agent-evaluation.md) and [evaluation cases](../evals/evals.json): three unrun model-driven comparisons; fixtures are not evaluation results.
- `test/agent-definitions.sh`, `test/project-baseline.sh`, `test/project-launch.sh`, and hook fixtures: automated validation of metadata, setup/upgrade safety, fake native adapter output and hook behavior. These do not prove a live provider session or native enforcement.
- `test/agent-config.sh`: real Git and disposable HOME with fake runtime executables; configuration, wizard cancellation, policy/argv, preflight and pinned restart coverage. No live agent behavior.
- [ADRs](adr/): historical decisions, including models, permissions, worktrees, communication, installation, AXI, lifecycle, hooks, and Q&A.
- [Q&A plan](superpowers/plans/2026-10-14-project-qa.md): intended behavior, execution results, and remaining acceptance gaps.
- [Test-concurrency research](research/test-concurrency.md): unimplemented proposal. No test-slot environment controls, `test`/`tests` subcommands, or semaphore are shipped.
- [dry-run tests](../test/dry-run.sh): fake-tool launcher, prompt, hook, restart, help/version/status/completion and dry-run-flag checks. [worktree tests](../test/worktrees.sh): real-Git branch/worktree checks. Live answer evidence is recorded separately in STATE.

The feature inventory includes configured planning behavior; automated and live verification remain separately recorded in STATE.
