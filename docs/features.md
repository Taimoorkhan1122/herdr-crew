# Current feature reference

Checked against the scripts, team configurations, ranks, and personas on 2026-10-14. This inventory describes built behavior. [STATE.md](STATE.md) records which behavior has automated or live evidence. The [README](../README.md) provides the user walkthrough.

## Commands and options

The launcher is [bin/crew](../bin/crew). It requires tsk, jq, and herdr on PATH before dispatch. Other used utilities include Bash, Git, rg, shasum, readlink, awk, sed, and standard shell utilities. It has no separate help subcommand; missing or unknown commands print usage and fail.

| Command | Inputs and behavior |
|---|---|
| `launch <spec> -` | Reads instructions from stdin. Without `-`, remaining words are instructions. Empty instructions fail. `lead` starts Lead, Manager, and board; a job creates a ready tsk task and starts its configured team. |
| `team <team> <T#> [--persona <job>=<domain>[+<domain>]]... ["instructions"]` | Starts an existing task's team. Repeat `--persona` for different slots. Explicit instructions override task notes in the brief. With no instructions, reads task notes. |
| `say <agent> "<message>"` | Sends to idle/done agents, or waits up to 20 seconds. If a task worker stays busy, appends a tagged message to its task. Lead/Manager names have no T number; when busy, their message can remain undelivered despite exit 0. Check the output. |
| `mark <T#> <status> "<note>"` | Runs tsk status, appends the note as a step, and reports pane metadata. These are separate calls, not one atomic transaction. |
| `status` | Prints open task JSON and states for Lead, Manager, and discovered task jobs. Completed tasks are normally excluded by tsk's default list. |
| `close <T#> [<team>]` | Closes matching tabs in the selected workspace. Without a team, matches the `T# ` label prefix. With a team, matches its exact label. Retains worktrees and prints removal commands for existing paths. |
| `watch` | Polls open and done tasks, known crew agents, and handoff files. Prints status changes, blocked/done/disappeared agents, and new handoffs. A failed task read retains the prior snapshot. |
| `handoff "<status>"` | Reads the multiline body from stdin, or uses the existing handoff file. Adds a task step when CREW_TASK exists and notifies the initiator. Does not terminate the agent itself. |
| `restart <agent\|T#>` | Reads saved rank/job/pane/task/brief. Requests exit, waits up to 30 seconds for the pane's shell, then starts again. Adds an existing handoff pointer and archives the handoff after startup. A T number selects all saved agents of that task. |

Spec forms are `lead`, `<rank>@<job>[+<domain>]`, or a bare job. `lead@<domain>` also uses the parser's domain composition. One job is allowed per spec, and its rank must match. Unknown names and invalid team persona slots fail before launch mutations. A fresh code-reviewer launch is refused because it lacks an existing pair branch.

## Configuration and identity

- [ranks/](../ranks/) sets permissions, model, effort, and communication rules: Lead opus/high, Manager haiku/max, member haiku/high, inspector haiku/xhigh. Model aliases resolve through the native runtime.
- [personas/](../personas/) defines seven jobs: driver, navigator, tester, code-reviewer, qa-bug-triager, qa-bug-reproducer, investigator. Five domains are pragmatic-senior, nestjs-expert, react-expert, ui-expert, security-paranoid. Default domain is pragmatic-senior.
- Persona `rank:` defines a job; domains omit it. Optional `skills:` and `axi:` are merged into the brief. A job's `effort:` overrides rank effort. A domain's effort does not set the launch effort.
- A rank's `model: inherit` omits the model flag. `kind: opencode` selects the alternate backend and `opencode_model:` supplies its model. No current rank uses it; live compatibility is not established.
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
| Standalone jobs | Direct launch creates the task and team, but does not create a Manager. Job results at review require manual acceptance or an existing Manager. |

Members use native edit permissions and session Bash denies for `git push`/`git merge`. Inspectors deny Edit/Write and have a restricted command list. Investigation further excludes test/build commands that may write. These are native tool permissions and instructions, not a separate operating-system sandbox.

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
| `CREW_WATCH_ONCE` | `1` runs two polls and exits; a test control. |
| `HERDR_ENV`, `HERDR_WORKSPACE_ID` | Select the inherited workspace when inside Herdr. Otherwise the launcher finds or creates `crew-<slug>` on a running server. |
| `HERDR_PANE_ID` | Caller pane for metadata updates. Herdr supplies it. |

Every created pane explicitly receives CREW_SLUG, CREW_TASK, CREW_AGENT, CREW_MANAGER, CREW_REPO, and CREW_WS. A split does not inherit those values from the tab automatically.

## Hooks and startup recovery

These hooks are passed as per-session Claude `--settings`; they do not install global hooks.

| Hook | Built behavior and limit |
|---|---|
| SessionStart | Appends shell-quoted exports for the six crew variables to CLAUDE_ENV_FILE when available. Restores Bash environment on startup/resume. |
| PostToolUse | Runs [bin/ctx-guard](../bin/ctx-guard). Reads the last main-thread assistant usage in the last 400 transcript lines: input + cache-read + cache-creation tokens. Subagent usage is excluded. |
| UserPromptSubmit | Runs the same guard. At or above CREW_CTX_LIMIT, writes a per-session marker and emits a handoff instruction once. |

The guard always exits 0. Missing or invalid usage becomes zero; a transcript-format change can therefore suppress warnings. It requests handoff but does not force termination or impose a billing limit. There is no built test-rewriting PreToolUse hook.

Startup uses native rank/model/effort flags. The launcher can answer a recognized Claude trust dialog in a pane it started. Registry names are reclaimed only after the previous pane reaches its shell. Brief submission checks working/blocked/done; visible pasted text can receive another Enter. Ambiguous input is not resent. A warning requires inspection before any retry.

## Dependency installation

[bin/install-skills](../bin/install-skills) accepts `--check`, `-y`/`--yes`, and `-h`/`--help`. Unknown options exit 2. A successful check exits 0; missing, blocked, skipped, or failed required items produce exit 1.

It combines persona skills with all skill names in [skills.sources](../skills.sources), then checks AXI declarations in ranks/personas. It can link a skill from `~/.agents/skills`, replace a broken link after approval, fetch a verified repository skill, install a declared plugin, or install a missing AXI package through npm. Existing paths without SKILL.md are retained and reported blocked. UNKNOWN sources require manual installation. Approval defaults to No and reads `/dev/tty`; `--yes` accepts all prompts. `--check` does not install or link anything.

## Documentation and verification map

- [README](../README.md): usage, rank/persona/team tables, customization, examples, limits.
- [SKILL](../SKILL.md): agent entry point and launch instructions.
- [STATE](STATE.md): current verification scope and open issues. [PROGRESS](PROGRESS.md): dated history.
- [ADRs](adr/): historical decisions, including models, permissions, worktrees, communication, installation, AXI, lifecycle, hooks, and Q&A.
- [Q&A plan](superpowers/plans/2026-10-14-project-qa.md): intended behavior, execution results, and remaining acceptance gaps.
- [Test-concurrency research](research/test-concurrency.md): unimplemented proposal. No test-slot environment controls, `test`/`tests` subcommands, or semaphore are shipped.
- [dry-run tests](../test/dry-run.sh): fake-tool launcher, prompt, hook, and restart checks. [worktree tests](../test/worktrees.sh): real-Git branch/worktree checks. Live answer evidence is recorded separately in STATE.

This documentation audit changes documentation only. It does not extend runtime behavior or settle pending live acceptance.
