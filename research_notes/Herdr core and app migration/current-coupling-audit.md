# Herdr core and app migration: current `herdr` coupling audit

Read-only audit of `/Users/gok/git/herdr-crew` at `main` (`5f4fb10`, working tree has unrelated docs edits). Goal: establish every runtime dependency on the old `herdr` CLI before a full replacement by `herdr-core` (`hc`) plus a required `herdr-app`. No source file was modified and no agent, pane, workspace or test resource was created.

## Method and evidence limits

Observed command surfaces:

| Command | Result |
|---|---|
| `herdr --version` | `herdr 0.9.5` |
| `hc --version` | `hc 0.1.16` |
| `herdr-app --version` | `herdr-app 0.1.11` |
| `hc --help`, `hc --skill`, `hc run/send/wait/get --help`, `hc schema` | CLI contract quoted below |
| `herdr-app --skill`, `herdr-app commands`, `herdr-app status`, `herdr-app ls` | App contract quoted below; a live window was present |
| `herdr --help`, `herdr agent/pane/tab/workspace --help` | Old CLI contract quoted below |

Evidence classes used below:

- **Observed**: source line or command output reproduced in this audit.
- **Inference**: a conclusion from the two contracts; not executed.
- **Gap**: needs a live crew launch or a disposable fixture.

No test suite was run, because `test/dry-run.sh` executes the real launcher and writes `$HOME/.herdr/...` state; that is outside this read-only scope. Runtime behavior therefore rests on source reading, the old CLI help, and the new CLI help.

## 1. Every `herdr` invocation in the runtime

### Takeaway

`bin/crew` has 30 direct `herdr` call sites. They split into five groups: agent state, agent lifecycle, pane/tab topology, pane process inspection, and one metadata write. All are synchronous CLI calls whose JSON is parsed with `jq`. There is no `herdr` subprocess abstraction; every call is inline in command logic.

### Cited Findings

Binary requirement: `bin/crew:685` requires both `tsk` and `herdr` on `PATH` for every runtime subcommand. No fallback and no version check.

`mut` (`bin/crew:10`) prints and skips mutating calls under `CREW_DRY_RUN`; `mutj` (`bin/crew:12`) also returns fixture JSON. Read calls (`agent get`, `agent wait`, `agent read`, `tab list`, `pane process-info`) are not wrapped, so they still run in dry-run.

| Line | Invocation | Purpose | Fields consumed | Failure handling |
|---|---|---|---|---|
| 109 | `herdr agent get "$1"` | Agent status probe (`status_of`) | `.result.agent.agent_status` (`idle\|working\|blocked\|done\|unknown`) | `2>/dev/null`, `// empty`, `|| true`; missing agent is silent |
| 114 | `herdr agent get "$1"` | Read pane of a possibly stale registry name | `.result.agent.pane_id` | `|| return 0`; failure means "no stale name" |
| 117 | `herdr pane process-info --pane "$pane"` | Detect whether pane foreground is its shell | `.result.process_info.shell_pid`, `.foreground_process_group_id` | `|| return 0`; no clear on failure |
| 119 | `herdr agent rename "$1" --clear` | Release a name only after its pane reached the shell | none | `mut`; stderr suppressed; no error branch |
| 205 | `herdr status server` | Is a Herdr server available outside a Herdr pane? | exit status only | Non-zero falls through to `die` at 213 |
| 206 | `herdr workspace list` | Find reusable workspace by label | `.result.workspaces[].label`, `.workspace_id` | Not checked; `jq` failure yields empty `WS`, then create path |
| 209 | `herdr workspace create --label "crew-$SLUG" --cwd "$REPO" --no-focus` | Create the crew workspace when none exists | `.result.workspace.workspace_id` | `mutj`; empty result later fails as an invalid workspace ID, no explicit check |
| 220 | `herdr agent prompt "$1" "$2"` | Send a brief or message | none | `mut`; no exit check |
| 224 | `herdr agent wait "$1" --until working --until blocked --until done --timeout 8000` | Confirm the prompt left the box | exit status only | Non-zero triggers read/Enter retry; four attempts then warning |
| 225 | `herdr agent read "$1" --source visible` | Inspect current screen for unsent text | plain text matched with `rg -qF` | `|| true`; empty screen skips Enter and warns |
| 228 | `herdr agent send-keys "$1" enter` | Resend only Enter after a lost bracketed-paste submit | none | No check |
| 269 | `herdr agent start "$name" --pane "$pane" --timeout 120000 "${args[@]}"` | Dry-run form of agent start | none | `mut` only |
| 270 | `herdr agent start "$name" --pane "$pane" --timeout 120000 "${args[@]}"` | Start Claude/OpenCode in an existing pane | captured stdout/stderr | Any failure dies unless output contains `agent_not_ready` **and** kind is `claude` |
| 272 | `herdr pane read "$pane" --source recent-unwrapped --lines 40` | Read trust-dialog text after `agent_not_ready` | plain text matched against `trust this folder` | `|| true`; absent text dies with captured output |
| 275 | `herdr agent send-keys "$name" down` | Move trust dialog selection from "No, exit" to "Yes" | none | No check |
| 276 | `herdr agent send-keys "$name" enter` | Accept trust | none | No check |
| 277 | `herdr agent wait "$name" --until idle --until done --timeout 120000` | Wait for agent ready after trust | exit status only | Unchecked; comment notes dialog may briefly report `blocked` |
| 314 | `herdr agent get "$SLUG-lead"` | Detect an already running Lead before topology work | exit status only | `>/dev/null 2>&1`; success routes to `cmd_say`, failure continues |
| 332 | `herdr tab create --workspace "$WS" --cwd "$REPO" --label "crew $SLUG" --no-focus "${EV[@]}"` | Create Lead tab with Lead env | `.result.root_pane.pane_id` | `mutj`; empty pane ID propagates |
| 336 | `herdr pane split "$root" --direction right --cwd "$REPO" --no-focus "${EV[@]}"` | Manager pane right of Lead | `.result.pane.pane_id` | `mutj`; empty propagates |
| 339 | `herdr pane split "$root" --direction down --ratio 0.3 --cwd "$REPO" --no-focus "${EV[@]}"` | Board pane below Lead | `.result.pane.pane_id` | `mutj`; empty propagates |
| 340 | `herdr pane run "$board" "tsk"` | Start the task board in the board pane | none | `mut`; no check |
| 422 | `herdr tab create --workspace "$WS" --cwd "$cwd" --label "$T $team" --no-focus "${EV[@]}"` | Team tab, first member in root pane | `.result.root_pane.pane_id` | `mutj`; empty propagates |
| 427 | `herdr pane split "${panes[0]}" --direction "$dir" --cwd "$cwd" --no-focus "${EV[@]}"` | Additional member panes: second `right`, later `down` | `.result.pane.pane_id` | `mutj`; empty propagates |
| 444 | `herdr agent wait "$to" --until idle --until done --timeout 20000` | Give a busy recipient 20 seconds before queueing on tsk | exit status only | Non-zero queues a task step or warns |
| 476 | `herdr pane report-metadata "${HERDR_PANE_ID:-none}" --source crew --title "$T $ME: $note"` | Pane title update on `mark` | none | `mut`; no check |
| 510 | `herdr tab list --workspace "${CREW_WS:-${HERDR_WORKSPACE_ID:-}}"` | Find tabs to close | `.result.tabs[].label`, `.tab_id` | `jq` filters; empty result dies at 512 |
| 514 | `herdr tab close "$tab"` | Close each matching tab | none | `mut`; no check |
| 626 | `herdr agent prompt "$name" /exit` | Ask agent to exit before restart | none | `mut ... || true` |
| 629 | `herdr pane process-info --pane "$pane"` | Poll up to 30 s for the pane to return to its shell | `.result.process_info.foreground_process_group_id`, `.shell_pid` | `|| true`; each poll may fail; after 30 s dies |

Also runtime-adjacent, not a `herdr` call:

- `bin/crew:493` comments that `herdr agent list` has no names, so `cmd_status` probes every possible crew name (`bin/crew:500-503`). `docs/STATE.md:103` says `agent list` shows a name only for named agents.
- `bin/crew:210` prints `attach with: herdr`; `bin/crew:213` tells the user to start `herdr`; `bin/crew:685` prints `install Herdr first`. All become false with `hc` + `herdr-app`.

Error-handling shape overall:

- Fatal lifecycle errors use `die` (`bin/crew:8`): agent start (270-274), missing trusted-pane text (273), no matching tab (512), still-busy pane after restart (630).
- Best-effort calls are silent: prompt, send-keys, metadata, close, rename, process polls.
- No call inspects `herdr`'s structured error object. Only `agent start` matches the literal substring `agent_not_ready` in combined output.

### Inferences

- Most old calls map one-to-one to `hc` or `herdr-app`. The hard ones are topology and process inspection, not messaging.
- `herdr agent get` exit status is used as an existence test at 314. Under `hc`, `hc get` must return a non-zero `not_found` (exit 3 per `hc --skill`) for that check to keep working.
- `agent start` atomically creates a named agent bound to an existing pane. `hc run` creates a **new** terminal; it does not attach an agent to an existing pane. This is the largest structural mismatch in the file.

### Gaps

- Whether `hc get` accepts a terminal **name** that was never started, and which error kind it returns.
- Whether `herdr-app do pane.split` can target a pane by ID from `herdr-app ls`, and whether the reply is exactly `{pane, terminal}` for every path.
- Whether `hc run` can place a new terminal into a specific existing pane or tab without app involvement.

## 2. Runtime lifecycle map

### Takeaway

The launcher owns a single linear lifecycle: **preflight → workspace selection → topology creation → agent start → brief submission → runtime coordination → close/restart**. Topology and process state are both owned by `herdr` today. Under the target split, topology moves to `herdr-app` and process state moves to `hc`, so every phase after preflight crosses two tools instead of one.

### Cited Findings

**Phase 0 — preflight.** `bin/crew:675-706`: source config libraries; pure-text help/completion exits before runtime checks; `jq` required; `tsk` and `herdr` required; `launch`/`team` resolve the project root and auto-run `init`. `parse_spec` (`bin/crew:63-89`) and `agent_check`/`preflight_team` reject bad specs before any mutation. `docs/features.md:7` states runtime commands require tsk, jq and herdr.

**Phase 1 — workspace selection.** `target_ws` (`bin/crew:202-215`):

- Inside Herdr (`HERDR_ENV=1`): require `HERDR_WORKSPACE_ID`.
- Outside Herdr: require `herdr status server`; then reuse the `crew-$SLUG` workspace by label, or create it with `--cwd "$REPO"` and `--no-focus`.
- `cmd_launch` exports `CREW_WS` (`bin/crew:325`). `cmd_team` prefers `CREW_WS`, else calls `target_ws` (`bin/crew:385`).

**Phase 2 — topology.**

- Lead tab: root pane Lead, split `right` Manager, split `down --ratio 0.3` board, then `pane run tsk` (`bin/crew:329-345`). Tab label `crew <slug>`. All panes `--no-focus`.
- Team tab: one pane per member; first member is the tab root, second splits `right`, all later members split `down` (`bin/crew:416-430`). Tab label `<T#> <team>`.
- Worktree selection precedes topology (`bin/crew:386-410`).
- Every pane gets its own `--env` set because splits do not inherit tab env (`bin/crew:93-99`; `docs/STATE.md:97`).

**Phase 3 — agent start.** `start_agent` (`bin/crew:237-290`):

1. Resolve kind/model/effort/definition; snapshot hooks.
2. Build Claude native agent JSON and `--settings` hooks, or OpenCode `--standalone` args.
3. `clear_stale_name` before start (`bin/crew:266`).
4. Start in the existing pane with a 120 s timeout.
5. On `agent_not_ready`, read the pane, require `trust this folder`, send `down`, `enter`, wait `idle|done`.
6. Save `.meta`, `.brief`, `.definition` under `$HOME/.herdr/crew/$SLUG` (`bin/crew:279-285`).
7. `submit` the brief (`bin/crew:286`).

Ordering matters: Manager starts before Lead in the Lead tab (`bin/crew:341-344`) so a Lead re-run never sees a half-built crew. Workers start after the whole tab exists (`bin/crew:431-435`).

**Phase 4 — submission.** `submit` (`bin/crew:219-234`): prompt, then up to four wait/read/Enter cycles. It resends Enter only when the visible screen contains `[Pasted text` or the first 30 characters of the message. Otherwise it warns and leaves the prompt alone. This encodes a known Claude bracketed-paste failure (`docs/STATE.md:98`).

**Phase 5 — runtime coordination.**

- `say`: status probe, 20 s wait for `idle|done`, else append a `[msg from X to Y]` step to the worker's task, or warn for Lead/Manager (`bin/crew:441-456`).
- `status`: tsk list plus name probes for lead, manager, and every job of every open task (`bin/crew:490-503`).
- `watch`: polls tsk twice (open + done), probes the same names, watches handoff files; first poll is baseline only (`bin/crew:532-586`).
- `mark`: writes a result JSON, sets tsk status, appends a step, writes pane metadata, then invokes the completion hook for `blocked|review|done` (`bin/crew:459-486`).

**Phase 6 — close / restart.**

- `close`: requires `CREW_WS` or `HERDR_WORKSPACE_ID`, lists tabs in that workspace, matches `T# ` or exact `T# team`, closes tabs, prints worktree removal commands without running them (`bin/crew:505-525`).
- `restart`: reads saved state, prompts `/exit`, polls process-info for shell foreground up to 30 s, then calls `start_agent` with saved metadata and an optional handoff pointer (`bin/crew:603-641`).
- `handoff`: writes `$SDIR/handoff-<agent>.md`, appends a tsk step, and messages the coordinator (`bin/crew:590-601`).

### Inferences

- The lifecycle is recoverable only because `.meta` stores `pane`. Under `hc`, a terminal address `tN` replaces the pane ID; the saved field and restart contract must change name and meaning.
- The launcher assumes topology exists before agent start. With `herdr-app`, a `tab.new`/`pane.split` reply must supply both the app pane ID and the `hc` terminal ID; the code needs both, not one.
- Close-by-label works because tabs are label-addressable. `herdr-app` has `tab.close --id`; labels are not a close selector. The code must resolve IDs from `herdr-app ls` instead.

### Gaps

- Whether a new terminal created by `herdr-app do tab.new` is visible to `hc ls` immediately, and how long until `hc get` reports a status.
- Whether `hc run --label herdr.space=... --label herdr.tab=...` can attach a terminal to an app tab, or whether only app-created terminals appear.
- Whether `herdr-app do tab.new --argv '["claude", ...]'` supports the full crew argv (agent JSON, settings, hooks), or whether the crew must create the tab then run `hc run --bg` inside it.
- Whether `hc keep` should replace the current `pane process-info` shell-foreground check for restart.

## 3. Injected environment variables

### Takeaway

The crew relies on per-pane environment injection, not on inherited shell environment. Seven `CREW_*` values are passed to every `tab create`/`pane split`; OpenCode adds an eighth. Five ambient `HERDR_*`/`CREW_*` variables drive behavior. `hc` has no per-pane `--env`; it has `--label` and the program's own inherited environment. This contract must be rebuilt.

### Cited Findings

**Written into every created pane** (`set_env`, `bin/crew:94`):

| Variable | Value | Consumer |
|---|---|---|
| `CREW_SLUG` | repo slug | hooks state path (`hooks/context-limit.sh:7,11`), agent identity |
| `CREW_TASK` | task number or empty | `handoff` tsk step (`bin/crew:595`), brief |
| `CREW_AGENT` | agent name | brief, hook handoff filename (`hooks/context-limit.sh:22`) |
| `CREW_MANAGER` | `<slug>-manager` | `mark` fallback coordinator (`bin/crew:480`) |
| `CREW_CTX_LIMIT` | default `135000` | hook threshold (`hooks/context-limit.sh:6`), brief |
| `CREW_REPO` | primary repo path | config discovery across worktrees |
| `CREW_WS` | selected workspace ID | `team` reuse (`bin/crew:385`), `close` (`bin/crew:507-510`) |

Conditional write: `OPENCODE_CONFIG_CONTENT=<json>` for OpenCode panes (`bin/crew:97-99`).

**Restored after Claude resume.** `crew_env_hook` (`bin/crew:123-134`) turns the same `EV` list into `export` lines and writes them through `CLAUDE_ENV_FILE` on `SessionStart`. This is how a resumed Claude session keeps `CREW_*`.

**Read from the ambient environment:**

| Variable | Read at | Meaning |
|---|---|---|
| `HERDR_ENV` | `bin/crew:203` | `1` means the caller is inside a Herdr pane |
| `HERDR_WORKSPACE_ID` | `bin/crew:204,507,510` | Current workspace; also fallback for `close` |
| `HERDR_PANE_ID` | `bin/crew:476` | Pane whose title `mark` updates |
| `CREW_WS` | `bin/crew:94,385,507,510` | Explicit workspace override |
| `CREW_MANAGER` | `bin/crew:480` | Fallback coordinator when `.meta` is missing |
| `CREW_TASK` | `bin/crew:595` | Task for the `[handoff]` step |
| `CREW_CTX_LIMIT` | hook line 6 | Context threshold |
| `CREW_SLUG` | hook line 7 | State directory |
| `CREW_AGENT` | hook line 22 | Handoff filename |
| `CREW_REPO` | `lib/project-config.sh` | Primary checkout override |
| `CREW_DRY_RUN` | `bin/crew:10-12` | Print instead of mutate |
| `CREW_WATCH_SECS`, `CREW_WATCH_ONCE` | `bin/crew:534,585` | Watch interval and test control |
| `CLAUDE_ENV_FILE` | `bin/crew:132` | Claude's persistence hook target |
| `NO_COLOR` | `lib/ux.sh` | Colour off |

`docs/features.md:103-110` documents these, including the explicit warning that `CREW_CTX_LIMIT` is not one of the forwarded values.

### Inferences

- `hc run --label` can carry the crew identity (`CREW_*`) as labels, but labels are not process environment. Hooks and scripts that read `$CREW_*` will see nothing unless the values are exported in the terminal's command line or shell profile.
- The safest port is to stop using ambient env for identity and pass values explicitly in the command argv (for example `env CREW_SLUG=... claude ...`), then keep `SessionStart` restoration only for Claude. That changes `set_env` from a `--env` array to a command prefix.
- `HERDR_ENV`/`HERDR_WORKSPACE_ID` have no `hc` equivalents. Detection must become `HERDR_APP_HOME`/app presence or explicit `HC_TERMINAL_ID`; the workspace concept becomes an app space ID.
- `HERDR_PANE_ID` has no `hc` equivalent; the nearest identity is `HC_TERMINAL_ID`, which is a terminal address, not a pane.

### Gaps

- Whether `hc run` preserves an arbitrary exported environment for the child and for later `hc send`-driven turns.
- Whether `herdr-app do tab.new` accepts environment at all, or only `argv` and `task`.
- Which variable names the app exposes to terminals (the app documents `herdr.space`/`herdr.tab` labels, not env).

## 4. The tsk and git boundary

### Takeaway

The three runtimes have clean ownership today: **tsk owns task state and steps, git owns branches and worktrees, herdr owns processes and topology**, and `bin/crew` owns only local metadata in `~/.herdr/crew/<slug>` and `.herdr-crew/`. The `herdr` migration does not change tsk or git. The only cross-boundary writes are `mark` (tsk + pane title, non-atomic) and `close` (herdr + printed git commands, never executed).

### Cited Findings

**tsk calls**

| Line | Call | Purpose |
|---|---|---|
| 352 | `tsk add --title= --notes= -p "$REPO" --json` | Create a task for a job launch; fields `.number`, `.outcome` |
| 356 | `tsk status "$T" ready` | Mark a new task ready |
| 474 | `tsk status "$T" "$st"` | Set task status on `mark` |
| 451 | `tsk steps "$task" add "[msg from $ME to $to] ..."` | Queue a message on a busy worker |
| 475 | `tsk steps "$T" add "$note"` | Record the mark note |
| 595 | `tsk steps "$CREW_TASK" add "[handoff] $ME: $status"` | Record a handoff |
| 387 | `tsk list "$T" --json` | Fallback instructions from task notes |
| 492, 494 | `tsk list -p "$REPO" --json` | Status and watch board |
| 540 | `tsk list -p "$REPO" --done --json` | Include finished tasks in watch |

Fields read: `.number`, `.status`, `.title`, `.notes`. `docs/STATE.md` records that tsk rejects multiline step text; messages and notes are single-line.

**git calls**

| Line | Call | Purpose |
|---|---|---|
| 20 | repo discovery | `REPO` resolution |
| 107 | `git rev-parse --verify refs/heads/<branch>` | Branch existence |
| 394-408 | `git worktree add`, `worktree add --detach`, `checkout --detach` | Create, attach or detach a team checkout |
| `lib/project-config.sh:5-12` | `git worktree list --porcelain -z` | Resolve the primary checkout for config |
| `lib/ux.sh:32` | `git describe` | Version string |

No `git push`, `git merge`, or `git worktree remove` is executed. `close` prints removal commands for the user (`bin/crew:515-524`); `docs/adr/0006` confirms worktrees are never removed automatically.

**Boundary rules**

- `launch` for a job creates the tsk task **before** any `herdr` topology (`bin/crew:349-363`), so a failed launch leaves a task.
- `team` reads tsk notes **before** worktree and topology work (`bin/crew:387`).
- `mark` is explicitly non-atomic: tsk status, tsk step and pane metadata are three calls (`docs/features.md:9`).
- `watch` tolerates a failed tsk read by keeping the previous snapshot (`bin/crew:542`).
- `close` requires a workspace but not a tsk or git call; it only prints git commands.
- Local state path is `$HOME/.herdr/crew/$SLUG` (`bin/crew:24`), separate from tsk storage and from `.herdr-crew/`.

### Inferences

- Replacing `herdr` cannot fix tsk/git behavior; a failed `mark` still leaves partial state. Migration should not widen this atomicity bug.
- `close` must change from "list tabs by label, close them" to "resolve app tab IDs, close them"; the printed git commands stay valid.
- `launch`'s task-before-topology order remains valid with `herdr-app` if topology failure is still fatal. If the app call is retried, the existing orphan-task behavior persists.

### Gaps

- Whether tsk has any integration point with `herdr-core` or `herdr-app` that should replace `tsk setup herdr` (`README.md:48`).
- Whether `tsk` can be launched as an app **mod** instead of a pane running the CLI (the app has a `mod` argument for `tab.new`/`pane.split`).

## 5. Test fakes and what the migration breaks

### Takeaway

The tests are hermetic because fake `herdr`, `tsk` and `git` binaries go first on `PATH`. The fakes are not a thin mock; they encode the exact JSON shapes and argv that `bin/crew` expects. Replacing `herdr` invalidates the shared fixture in `test/dry-run.sh:1-88`, which four other suites source or copy. The migration therefore breaks most tests at once, not only assertions that mention `herdr`.

### Cited Findings

**Fake `herdr` branches** (`test/dry-run.sh:17-55`):

`status server`, `tab create`, `pane split`, `workspace list`, `workspace create`, `agent get`, `agent rename`, `agent start`, `agent wait`, `agent read`, `agent send-keys`, `agent prompt`, `pane read`, `pane process-info`, `tab list`, `pane run`, `pane report-metadata`, `tab close`. Unknown subcommands exit 1 with `unhandled`.

The fake also models behavior, not just output:

- `agent start` rejects when `$STATE/stale` exists (`agent_name_in_use`).
- `agent start` writes `--settings` and `--agents` payloads to state files.
- `$TMP/trust` makes one start fail with `agent_not_ready`.
- `agent wait` fails under `$STATE/ambiguous`, succeeds for `--until done` under `$STATE/quick-done`, and models `$STATE/paste` / `$STATE/entered`.
- `pane process-info` returns shell-foreground only after `$STATE/shell`, and is controlled by `$STATE/live` / `$STATE/stale`.
- `tab list` returns fixed labels `T7 pair`, `T7 review`.

**Fake `tsk`** (`test/dry-run.sh:57-76`): `add` returns `{number:7}`; `list` has three shapes (done list, open board with a status sequence, single-task notes); it hides done tasks like real tsk.

**Fake `git`** (`test/dry-run.sh:78-86`): overrides worktree add, detach checkout, branch existence and branch name; other calls go to real git.

**Shared fixtures**:

- `test/partial-init.sh:4-5` and `test/test-hook-integration.sh:4-5` copy `sed -n '1,88p' test/dry-run.sh` and source it. Any change to fixture lines 1-88 changes three suites.
- `test/project-launch.sh:24-35` has its own fake `herdr`, captures `tab create`/`pane split` argv into `PANE_ENV_DIR/p1`/`p2`, and reads `OPENCODE_CONFIG_CONTENT` from the captured `--env`. This test directly asserts per-pane env.
- `test/worktrees.sh:8-14` fake `herdr` returns fixed pane IDs, no status modeling; it uses real git.
- `test/agent-config.sh:189` has another fake `herdr`; line 232 sets `HERDR_ENV=1 CREW_WS=w1`, and lines 284/292 assert no `tab create`/`agent start` mutation on failures.
- `test/dry-run.sh:87` sets `HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 CREW_WS=w1`; lines 198 and 237-238 explicitly test the outside-Herdr workspace path.

**Assertions coupled to old argv/JSON**:

- `panes_ok` (`test/dry-run.sh:97-107`) requires every `tab create`/`pane split` line to contain `CREW_WS=w...` and `CREW_AGENT=...`, and requires `agent start <agent> --pane <pane>`.
- `README.md:470` describes the fake-PATH strategy.
- `docs/STATE.md:75-77` records the suite sizes and that fakes cover launch, team, say, mark, status and close.

### Inferences

- A `herdr` → `hc`/`herdr-app` migration requires a new fake pair, not an adapter fake. The old fake's **branch names are the old API**. Keeping a compatibility shim named `herdr` would let tests pass while production is broken, which is worse than failing tests.
- The smallest coherent test change is to replace `$FAKE/herdr` with `$FAKE/hc` and `$FAKE/herdr-app`, update `panes_ok`, and update `PANE_ENV_DIR` capture in `project-launch.sh`.
- Because `partial-init.sh` and `test-hook-integration.sh` source the fixture, the fake replacement must land before any dependent suite can pass.

### Gaps

- No isolated fixture currently models `herdr-app` state, space/tab IDs, or `hc` status transitions. The migration needs at least: tab creation reply, split reply, terminal status sequence, and a blocked/error terminal.
- No test proves a real app window is required. `herdr-app status` was observed live, but the app can be absent in CI.
- No test asserts what happens when `hc run` starts but the program exits within two seconds (the app documents an error toast, not a CLI failure).

## 6. Docs and contracts that become false

### Takeaway

The old `herdr` contract is documented as product behavior, not as an implementation detail. README install steps, the feature reference, agent prompts and tool allowlists, ADRs and the skill description all name `herdr` commands or semantics. A full replacement must update them together, or agents will be told to run commands that no longer exist.

### Cited Findings

**Install and prerequisites**

- `README.md:44`: requires **Herdr** with the `herdr` command on `PATH`.
- `README.md:48-49`: `tsk setup herdr` and `herdr server reload-config`.
- `README.md:143`: "Open a Herdr pane".
- `README.md:265-269`: workspace behavior: inside Herdr uses the current workspace; outside uses `crew-<slug>`; no server prints "start Herdr with `herdr`".
- `SKILL.md:3`: "Launch an agent crew in Herdr".
- `bin/crew:685`: dependency error names `herdr` and the install hint.
- `bin/crew:210,213`: user-facing `attach with: herdr` and `Start Herdr with: herdr`.

**Runtime feature reference**

- `docs/features.md:7`: runtime commands require tsk, jq and herdr.
- `docs/features.md:9`: `mark` reports "pane metadata".
- `docs/features.md:31`: first member gets the root pane; later members split.
- `docs/features.md:35`: saved state at `~/.herdr/crew/<slug>`.
- `docs/features.md:58,61-62`: `HERDR_ENV`, `HERDR_WORKSPACE_ID`, `HERDR_PANE_ID`; "Every created pane explicitly receives ...".
- `README.md:151,157`: "pane titles" and "team tabs" as visible progress.
- `README.md:239-244,254-259`: watch/handoff paths under `~/.herdr/crew`.
- `README.md:359`: worktrees under `~/.herdr/worktrees`.

**Agent contracts**

- `agents/crew-manager/agent.json:15-18`: grants `Bash(herdr agent wait|read|get|list *)`. These four grants become dead or wrong.
- `agents/crew-manager/AGENTS.md:48`: instructs the Manager to run `herdr agent wait <name> --until done --until blocked --timeout 60000` with Monitor, then `herdr agent read <name> --source recent-unwrapped --lines 80`.
- `README.md:239` and `docs/adr/0015:14` describe the Lead's Monitor as `herdr-crew watch`; the watch implementation itself uses `herdr agent get`, so the **command name** stays but the monitoring semantics change.
- `README.md:375` and `docs/features.md:10` describe restart as "waits for the pane to reach its shell".

**ADRs**

- `docs/adr/0002:12`: one tab named `crew <slug>`, Lead root, Manager right, board below at ratio 0.3, `--no-focus`.
- `docs/adr/0007:12`: trust handling via `agent_not_ready`, `down`, `enter`, wait `idle|done`.
- `docs/adr/0012:8`: worktrees, tabs and agent names need a stable short ID.
- `docs/adr/0014:16,20`: `close` by exact tab label.
- `docs/adr/0015:14,18`: watch polling and restart shell wait.

**State and gotchas**

- `docs/STATE.md:64`: split does not inherit tab env.
- `docs/STATE.md:68`: `agent list` shows a name only for named agents; `agent get` returns `.result.agent.agent_status`.
- `docs/STATE.md:77`: hermetic suite has 170 checks and fakes herdr/tsk/git.
- `docs/STATE.md:97`: per-pane `--env` is mandatory.

### Inferences

- The safest documentation change is vocabulary-first: replace "pane" with "terminal" where process identity is meant, keep "pane" only for app layout, and replace "workspace" with "space". Otherwise readers will keep assuming one tool owns both.
- `agents/crew-manager/agent.json` is a **runtime permission contract**, not prose. If the Manager keeps `herdr agent ...` grants after `herdr` is removed, its allowed tools point at a missing binary; if the grants are replaced, the prompt in `AGENTS.md:48` must change in the same commit.
- The old `herdr` command name also appears inside user instructions and tests. A grep-only rename will miss semantic changes such as `--source recent-unwrapped` and `--until blocked`.

### Gaps

- No doc states which app version is required, or how the launcher detects a missing `herdr-app`.
- No doc states whether `hc` and `herdr-app` must be the same version, or how to fail when they are incompatible.
- `README.md:44` has no `herdr-core`/`herdr-app` install path yet.

## 7. Highest-risk couplings and behaviors with no direct equivalent

### Takeaway

Three couplings are structural: **(1)** agent identity is bound to a pane, **(2)** topology is created by the same CLI that starts agents, and **(3)** shell-foreground detection uses pane process groups. The first two have workarounds; the third has no documented `hc` equivalent. The status model also changes: `unknown` disappears, `error` appears, and `blocked` becomes a human-permission state that `hc send` refuses by default.

### Cited Findings

| Risk | Old behavior | Target evidence | Impact |
|---|---|---|---|
| Agent bound to pane | `agent start --pane <pane>`; status/read/wait/keys all by agent name (`bin/crew:220-277`) | `hc run` creates a **new** terminal; `hc get/send/wait/keys/read` address a terminal (`hc --help`, `hc --skill`) | `start_agent` cannot attach to a pre-created pane. It must either create the terminal or use app-created terminals and discover their IDs. |
| Topology ownership | `tab create`, `pane split`, `pane run`, `tab list/close` all in `herdr` (`bin/crew:332-340,422-427,510-514`) | `herdr-app do space.new/tab.new/pane.split/tab.close`; no topology in `hc` | Requires the app to be running for every `launch`/`team`/`close`. `close` must resolve IDs, not labels. |
| Env per pane | `--env` on every create/split (`bin/crew:94`) | `hc run --label`, no `--env`; app `argv`/`task` | Hooks and `bin/crew` self-identification lose their environment unless values move into argv or labels. |
| Shell-foreground detection | `pane process-info`, compare `foreground_process_group_id` to `shell_pid` (`bin/crew:117,629`) | No `hc` process-group API in help; `hc get` reports `status`/`state`, not foreground pgid | `clear_stale_name` and `restart` cannot prove the pane returned to its shell. Must use `status: idle/done/error` or `state: finished`, which is weaker. |
| Agent name reuse | `agent rename --clear` after shell foreground (`bin/crew:119`) | `hc` names are unique among **live** terminals; no rename command | A stale name blocks `hc run --name`. Workaround: kill/remove the finished terminal, or pick a new name. |
| Status vocabulary | `idle\|working\|blocked\|done\|unknown` (`bin/crew:108`) | `idle\|working\|done\|blocked\|error`; plain programs have none (`hc --skill:150-155`) | `unknown` paths change; `error` needs handling; `done` is a real status, not just idle. |
| Message submission | `agent prompt` + Enter retry (`bin/crew:219-234`) | `hc send` pastes and presses Enter; refuses on `blocked` unless `--force`; `--if idle\|working`; `--wait` | A blocked agent now **rejects** the message instead of receiving it. The retry loop has no direct analogue; first message should go in `hc run` (`hc --skill`). |
| Wait semantics | `agent wait --until working/blocked/done --timeout 8000` (`bin/crew:224`) | `hc wait` waits until "it stops working"; `--children all/any`; `--output` for programs | No per-status wait selector. The `submit` confirmation loop and `say`'s 20 s gate need redesign. |
| Read sources | `agent read --source visible`, `pane read --source recent-unwrapped --lines 40` (`bin/crew:225,272`) | `hc read <t> --lines N` prints screen plus history | Source selection disappears. Trust-prompt detection depends on recent-unwrapped output. |
| Board pane | `pane run "$board" "tsk"` (`bin/crew:340`) | `hc run --bg tsk` or app `tab.new --argv`; app has `mod` support for a board | If board becomes a mod, `tsk` CLI behavior and the `tsk` pane contract change. |
| Pane title metadata | `pane report-metadata ... --title` (`bin/crew:476`) | No equivalent in `herdr-app commands`; app shows terminal status/labels | Progress cue `T7 <agent>: <note>` disappears unless labels or terminal titles are used. |
| Workspace identity | `HERDR_WORKSPACE_ID` / `crew-$SLUG` label (`bin/crew:202-215`) | App space IDs; `hc` has no workspace concept | `CREW_WS`, `close` and re-run-in-place logic need a new identity (`herdr.space` label or app space ID). |
| Trust dialog | `agent_not_ready` + pane text check + `down`/`enter` (`bin/crew:270-277`) | `hc --skill:48-51` says a trust dialog may need `hc keys <t> down enter`; `hc run` with a task returns `first_message.sent` | Detection changes from an error code to reading the terminal. The "only panes we started" safety rule must be re-established. |
| Agent registry | `herdr agent get` by name; `agent list` names (`bin/crew:109,493`) | `hc ls` lists terminals with `name`, `status`, `cwd`; `hc get <t>` by address or name | Name→terminal mapping is still possible, but the probe strategy in `cmd_status`/`watch` should switch to one `hc ls`. |
| Monitor command | `herdr agent wait ...` inside Manager prompt (`agents/crew-manager/AGENTS.md:48`) | `hc wait <t>` / `hc wait --children` | The Manager's Monitor tool invocation is a written contract that breaks. |

### Inferences

- The lowest-risk target shape is: **`herdr-app` creates the visible tab/pane and returns `{pane, terminal}`; `hc run --bg --name ...` starts the agent in that terminal; all later talk uses the `hc` terminal ID.** This preserves the current "pane exists first, agent starts in it" ordering.
- If `herdr-app` cannot return a terminal ID that `hc` accepts, the crew must invert: `hc run` first, then place it in the app with `herdr.space`/`herdr.tab` labels. That inversion changes the topology code more.
- `clear_stale_name` should probably disappear. With `hc`, a finished terminal is `state: finished`; `hc rm` removes it, and live names are unique. Reusing a name is a `kill`/`rm` decision, not a rename.
- The `blocked` refusal is a **safety feature**, not a bug to bypass. `submit`/`say` must surface "agent needs a person" instead of forcing text into a permission dialog. This is a behavior change users will notice.

### Gaps

- Whether `herdr-app do pane.split` returns a terminal address usable by `hc` immediately.
- Whether `hc run` can start a program in an **existing** terminal (not a new one). If not, the "attach agent to pane" model is impossible and must be replaced.
- Whether `hc get` status is populated for Claude/OpenCode quickly enough for `submit`'s 8 s confirmation loop.
- Whether `hc send` on a `blocked` terminal returns exit 9 and whether that is distinguishable from a missing terminal (exit 3).
- Whether `hc read` includes enough recent history to replace `--source recent-unwrapped`.
- Whether the app exposes a title/metadata update equivalent to `pane report-metadata`.

## 8. Migration sequencing implied by the evidence

### Takeaway

The dependency order is forced: **fixtures → identity/env → topology → agent start → messaging/wait → restart/close → docs/prompts**. Doing agent start first leaves no terminal to start in; doing docs first advertises behavior that does not exist.

### Cited Findings

- Fixtures gate every suite (`test/dry-run.sh:1-88`, sourced by `partial-init.sh:4-5` and `test-hook-integration.sh:4-5`).
- Env is set before topology (`bin/crew:94`, used at 332/336/339/422/427), and hooks read it later (`hooks/context-limit.sh:6-22`).
- Topology precedes agent start (`bin/crew:329-345`, `416-435`).
- Agent start precedes submission (`bin/crew:269-286`).
- Messaging and wait are used by `say`, `submit`, `restart` (`bin/crew:219-234,441-456,626-629`).
- Close/restart depend on topology and process inspection (`bin/crew:505-525,603-641`).
- Docs, prompts and allowlists are contracts consumed by agents (`agents/crew-manager/agent.json:15-18`; `agents/crew-manager/AGENTS.md:48`; `README.md:44-49`).

### Inferences

- A dual backend would double every fixture and every behavior branch. The requirement says full replacement, so the migration should introduce `hc`/`app` fakes and delete the `herdr` fake in the same change that changes `bin/crew`.
- Keep `tsk` and `git` untouched. They are the stable half of the system and the easiest way to detect regressions.
- The app requirement should fail early and clearly, like the current `command -v herdr` check (`bin/crew:685`), not at the first split.

### Gaps

- No target-side command yet maps to `pane process-info`; this is the one behavior that may require a different restart strategy (for example, `hc kill` + `hc run` in a new terminal, then re-place it).
- No target-side command yet maps to `pane report-metadata`; progress display may need an app label update or terminal title change.
- Whether `tsk setup herdr` has an `hc` equivalent, or whether the board should run as a plain `hc run --bg tsk`.

## 9. Unknowns that require live validation

### Takeaway

The source and help text settle the API shape but not timing, identity handoff, or failure modes. Five live checks would remove most of the remaining risk.

### Cited Findings

| # | Check | Why it matters | Evidence today |
|---|---|---|---|
| 1 | Start a disposable app tab with `herdr-app do tab.new`, then `hc ls`/`hc get` the returned terminal | Proves the `{pane, terminal}` reply and immediate `hc` visibility | `herdr-app --skill` documents the reply; `hc ls` shows live terminals |
| 2 | `herdr-app do pane.split --pane <id> --direction right` twice, then inspect `herdr-app ls` | Proves split targeting and ID stability | App help; no execution |
| 3 | `hc run --bg --name x claude`, then `hc get x` over 30 s | Measures readiness and status transition to `working` | `hc --skill:40-51` warns sends to booting agents can drop |
| 4 | Send to a `blocked` agent without `--force` | Confirms exit code 9 and message text | `hc --skill:153-155`; `hc send --help` |
| 5 | Trigger a trust dialog in a disposable folder, then `hc keys <t> down enter` | Confirms trust handling without the old `agent_not_ready` signal | `hc --skill:48-51`; `docs/adr/0007` |
| 6 | `hc run --bg --label herdr.space=<id> --label herdr.tab=<id> tsk` and inspect the app | Proves whether labels place a terminal into a tab | `herdr-app --skill` says a terminal opts in with `herdr.space`; unlabeled workers stay hidden |
| 7 | Kill a Claude agent, then inspect `hc get` and restart | Replaces shell-foreground polling | No `hc` process-group API observed |
| 8 | Inspect `hc events` output for status changes | Possible replacement for `watch` polling | `hc --help` lists `events`; no shape captured |

### Inferences

- Checks 1, 3 and 5 are the critical path. If they fail, the whole "pane first, agent second" design must invert.
- A disposable fixture must use its own `HC_SESSION` and scratch XDG paths, per `hc --skill:179`; otherwise it disturbs the user's live terminals.

### Gaps

- No live test was run in this audit, by design. All target-side claims above are contract-level, not acceptance-level.
- No evidence yet for app behavior when `herdr-app` is not running: does `hc run` fail, stay hidden, or create a tab later?

## Bottom line

`bin/crew` is coupled to `herdr` at 30 call sites, but the coupling is concentrated: **topology (8 calls)**, **agent lifecycle (12)**, **inspection (6)**, **workspace (3)**, and **metadata (1)**. `tsk` and `git` are independent and should not change. The replacement is feasible because `hc` covers terminal/agent run, send, wait, read, keys, status, labels, events and kill, while `herdr-app` covers space/tab/pane topology. It is not a drop-in: per-pane env, agent-to-pane binding, shell-foreground detection, pane titles, workspace identity, `unknown` status, and the trust-dialog signal have no direct equivalent. Plan for a coordinated change across `bin/crew`, the shared test fixture, `agents/crew-manager/{agent.json,AGENTS.md}`, README, features, STATE and ADRs — not a command-name rename.
