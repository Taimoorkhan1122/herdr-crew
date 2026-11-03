# herdr-core capability audit (hc 0.1.16)

This audit is READ-ONLY. All claims below cite exact commands run, direct exit codes, observed JSON/text outputs, schema/manual excerpts, local state, or upstream source (cloned to /tmp/hc-src at commit 5a9de29b). Config dir `~/.config/herdr-core/` did not exist at audit time; state at `~/.local/state/herdr-core/default/` exists (terminals/docs/core). Tests done in an isolated session `HC_SESSION=ra` with scratch XDG paths under /tmp/hcr (socket path too long for the long session name forced using short name `ra`).

## 1) Command surface, machine-readable output, exit codes, error shapes
- Binary/version/help: `hc --version` -> `hc 0.1.16` (exit 0). `hc --help` lists commands/args, notes `Options: --json (default when piped; run and read print text)`, exit codes section, `Settings: ~/.config/herdr-core/config.toml`. `hc --skill` prints full agent manual (see § below). `hc schema` writes OpenRPC JSON Schema (exit 0, ~63KB). Source help in `crates/herdr-core/src/help.txt`.
- Per-command `--help`: confirmed for run/ls/get/attach/read/kill/rm/label/keep/send/keys/interrupt/wait/put/exec/file/templates/events/server/update/machine/connect/schema; `hc api --help` -> usage error exit 2 (no `api` subcommand).
- JSON behavior: CLI says "piped output is JSON except `run`, `exec`, `read`, and `file read` (text)". In isolated test: `ls --json` returns `{"hidden_finished":N,"terminals":[]}` (exit 0); `get` unknown returns `{"error":{"hint":"see `hc ls --all`","kind":"not_found","message":"no terminal \"nosuch\""}}` (exit 3). `run --bg --json` returns `RunResult` (has `address`, `first_message`, etc.) (exit 0). `read` prints text by default even if not piped? Test: `read alpha` printed `hello-audit` (exit 0); `read alpha --json` returned `{"complete":true,"how":"screen","text":"hello-audit"}`. `exec` text by default: `exec -- sh -c 'echo out; echo err >&2; exit 7'` wrote `out`/`err` and exit code 7; `exec --json` returned `{"code":7,"ms":...,"signal":null,"stdout":"","stderr":"","timed_out":false,"truncated":false}` (exit 0). `file read` text by default? `file read --json` returned `{"first":1,"last":5,"lines":5,"text":"..."}` (JSON when `--json`). Errors are JSON on stderr in JSON mode with shape `{"error":{"kind","message","hint"}}` and exit codes as documented.
- Exit codes (observed): not_found -> 3 (get unknown). needs_target -> 7? not observed directly; schema lists. blocked on send -> 9 (`send blocked` gave exit 9). status_mismatch -> 10 (`--if idle` while blocked gave exit 10). finished -> 11 (send/interrupt to finished). usage -> 2 (bad session name, bad api subcommand, bad run args in some cases). run timeout leaves process running and exits 124 with message `[hc] still running as t7: ...`. Normal run exit propagated as exit code of run (e.g. `echo fg-out; exit 3` gave exit 3). Templates bad name gave invalid_params exit 6.
- Error kinds from schema/manual: `invalid_params`, `name_taken`, `spawn_failed`, `unavailable`, `invalid_template`, `not_found`, `machine_unknown`, `config`, `needs_target`, `blocked`, `status_mismatch`, `finished`, `edit_failed`, `not_text`, `io`, `needs_update`, `conflict`, `internal`, `unsupported_generation`.

## 2) Terminal model (IDs/names, uniqueness, stability)
- Addresses/IDs: base36-like scheme with no vowels, no `l`. `address(n)` produces `t1..t9`, `t10` etc (see `terminals.rs`). `id_shaped` true only for `t` followed by 1-9 and chars in `0123456789bcdfghjkmnpqrstvwxyz`. `parse_id` reverses. Names: 1-32 of `[a-z0-9._-]`, must start with letter or digit, not shaped like id (`check_name` in `addr.rs`). Name unique among *live* terminals (`name_taken` if live exists). In test: second `--name alpha` created new terminal `t2` (different address) while first `t1` finished - so name uniqueness is among live; finished terminals keep names/labels but can be reused? Or duplicate name allowed only when previous not live? Observed: created `alpha` as `t1` (finished), then created `alpha` again as `t2` (live) - succeeded (exit 0). So uniqueness is live-terminals only.
- Identification: `<t>` can be address like `t7` or name or `machine/t7`. In a terminal, attach/read/get/kill/rm/wait/interrupt pick one when omitted. Parent relationship stored as address string.
- Stability across restarts: addresses are forever on this core per id counter (`next_id` increments). Names are user-assigned labels for lookup; kept terminals can be restarted as shells after loss (see §6). Terminal identity in env is `HC_TERMINAL_ID` = address.

## 3) Agent launch, templates, first message, delivery failure, trust/readiness
- `hc run --bg` starts and returns immediately. Without `--bg`, streams into caller output (manual warns). 
- Templates: Markdown files in `~/.config/herdr-core/templates/<name>.md` (or platform equivalent). Frontmatter: `description`, `command` (required), `ready` (`quiet` or default report-based), `submit`, `stop`, `paste_gap_ms`. Body is instructions; core appends task after blank line (`first_message(t,prompt)`). `hc templates` lists them. Template resolution happens in `terminal.run`: if argv[0] matches template name, it loads template; command becomes template.command (via `sh -c` in that branch) or runs template directly depending on args. First message sent after readiness check.
- Readiness: default waits for OSC 7501 status report (`ready_timeout()` 30s by default, env `HC_READY_MS`). If not reported and still live -> `first_message.sent=false` with reason "it never reported its status..." and `started/turn` null. If `ready: quiet` waits for output to go quiet (`OUTPUT_SETTLE` 800ms) via `last_output`. In test with fake template that doesn't report status: `run --bg` gave `first_message.sent=false` with reason about checking screen. 
- Delivery: `first_message` in RunResult has `sent`, `started` (bool|null), `reason` (string|null), `turn` (u64|null). If send fails/times out on readiness, task not sent - must read screen, resolve readiness (trust dialog may need keys), then send task; don't blindly resend. 
- Trust/readiness dialogs: manual says "a trust dialog may need `hc keys <t> down enter`". Blocked state means person needed (permission/question). `send` refuses if blocked unless `--force` (exit 9). `keys`/`interrupt` can be used.
- Agent CLIs/status: status comes from OSC 7501 (Program Status Protocol). Words are program's own (`idle/working/done/blocked/error` common). `reported` indicates if ever sent status. `turn` increments each time status leaves `working`. Records for child records stored in `records` map. No translation by core; core just stores/relays.

## 4) Status/waiting/events
- Status source: OSC 7501 parsed by ghostty-vt. `Terminal.status` is root record; `records` has other ids. `reported`, `status_ms` updated on change. `turn` increments on leaving working. `blocked`/`error` trigger news/stuck. 
- `hc wait <t>`: waits until not working or exits/lost; already not working returns immediately. After send from same caller, waits for turn that send started. Message to caller ends it with `ended:false, reason:"message", from:sender`. Timeout is check-in: `ended:false, reason:"timeout", status:current`. For programs with no status, waits for exit. With `--output X` waits for output containing X printed after wait started (plain text, escape sequences stripped); blocked/error/exit end too. With `--children any|all`: `any` gives next news/message to parent; `all` waits until none working (unreported counts as working). WaitResult has `ended`, `reason`, `status`, `turn`, `exit_code`, `signal`, `children[]`, `from`.
- `hc events`: follows fact changes live as JSON lines when piped (subscribe API). Events: created, lost, restarted, keep, finished, removed, status, turn, title, labels, size, doc. Heartbeat every 15s, missed+snapshot if behind. Filters by `--terminal`, `--children-of`, `--label`. In test got snapshot with seq/channel info.
- `send --wait` waits for turn send started (returns SendResult with `wait`).

## 5) Process ownership/parent-child, outlive-parent
- Parent set at start: default is calling terminal (if exists), or `--parent`, or `--no-parent`. In env of child: `HC_TERMINAL_ID` is child's address; child can see parent via `parent` in terminal info. 
- Children end with parent by default (`die_with_parent` true unless `--outlive-parent`). Orphaned children when parent finishes trigger `notes::Job::Orphaned` -> core kills them (adds to `killing`, does kill sequence). Scope/sweep: each terminal gets `HC_SCOPE` token stamped with time; descendants inherit even if leave session (agents' tool shells). `sweep::sweep` on Unix finds processes with that scope token (and descendants) excluding hc/runtime processes, sends SIGHUP/SIGTERM/SIGKILL over time. On Windows uses job objects. When holder exits/shuts down, it sweeps scopes of its terminals. 
- Grandchildren: inherit scope from child, so they are in same sweep tree (sweep walks descendants by parent pid among scoped processes). 
- Crew leads/managers: if started as children without `--outlive-parent`, they die when parent dies. 
- App-attached terminals: same rules apply based on parent relationship; `herdr-app` uses labels/arrangement but ownership is core/hc model.
- Long-lived crew: need to start leads/managers with `--outlive-parent` if they must survive orchestrator restart/crash, or manage lifecycle explicitly. Default is coupled to parent.

## 6) Layout/visibility in herdr-app
- hc has no workspace/tab/pane layout. Layout is in herdr-app (`herdr-app --skill`). 
- Terminal becomes visible in herdr-app via labels: `herdr.space=<spaceId>`, `herdr.tab=<tabId>`. `herdr-app` creates tab in that space if tab not specified. 
- Unlabeled terminals stay hidden (manual says "Unlabeled workers stay hidden. Do not add labels just to run a background worker."). 
- `hc label` sets labels (key=value, key= removes). Labels are stored on terminal.

## 7) Recovery/keep/restart/shutdown
- `hc keep <t>` or `run --keep`: replaces lost program with a shell in place, never reruns task. `keep` off via `--off`. Signal death without exit code is loss too. Recovery runs on every OS after grace delay (including after host shutdown). On macOS shutdown warnings preserve kept programs even if they catch signal and exit with code; on Linux systemd stops core before its holders. Ordinary exits/explicit kills remain final. 
- Streams end on loss; reattach after restarted event. Pending input/attach may be unavailable - retry after recovery.
- `hc update` restarts older running core if installed binary current; terminals keep running (JSON `restarted:true`). Managed installs must use package manager.
- `hc server stop`: parks kept terminals; next core start gives them shells. Affects every terminal. `hc server restart`: planned restart, programs keep running, next core adopts them (screens saved).
- State persistence: terminals.json, docs.json, core.json in state dir. Screens saved to snapshots on finish/loss. On restart/handover, core adopts terminals; kept terminals get recovery shells. 
- Recovery behavior: if holder lost and terminal kept/live with no pid/reason -> marked spawn_pending/lost, scheduled restart with backoff (1500,3000,6000,12000,30000,60000...). Recovery spawns shell with original cwd/env/labels (template cleared), resets status/title/full_screen etc. `program_started_ms` reset; backoff resets if program ran stable >=10s.

## 8) Config/env/templates
- Config file: `~/.config/herdr-core/config.toml` (Linux/macOS), `%APPDATA%\herdr-core\config.toml` (Windows). Missing file means defaults. Settings: `shell` (array of exe+args, default platform shell; changes apply to next new shell/keep recovery), `detach_key` (default `ctrl+\`), `wait_timeout` (default 180), `notes` (bool, default true), `notes_quiet` (seconds, default 3), `headless` (`COLSxROWS`, default `200x120`), `history_mb` (default 5), `socket` (override), `machine_timeout` (default 30). 
- Env vars: `HC_SESSION` selects isolated core/session (socket path name). `HC_SOCKET` overrides socket. `XDG_STATE_HOME`/`XDG_CONFIG_HOME`/`XDG_DATA_HOME`/`XDG_CACHE_HOME` affect paths. Inside terminal: `HC_TERMINAL_ID` set to address, `HC_TERMINAL_SOCKET`, `HC_SCOPE` (sweep token), `HC_RUNTIME` marks hc cores/holders (never swept). `HC_SESSION` propagated. `HC_READY_MS`, `HC_SPAWN_MS`, `HC_HOLDER_GRACE_MS`, `HC_HEARTBEAT_MS`, `HC_STITCH_MS`, `HC_FOREGROUND_MS` affect timings (from strings). 
- Templates dir: `~/.config/herdr-core/templates/` (alongside config). Format as in §3.

## 9) Remote/machine/exec/file/connect/api schema
- Machines: `hc machine add/list/login/update/rename/rm`. Stored in core state; `hc ls` shows local + each connected machine's terminals as `machine/t7`. Run on machine with `--on <machine>`. `hc machine update` copies hc there and restarts. SSH or custom via `--via`. Windows SSH elevated session notes apply.
- `hc exec`: run without terminal, here or `--on`, returns exact output and exit code. `argv` runs as given (no shell) or `line` via shell. `-i` feeds stdin. Timeout default 60s max 600s; everything it started ends with it. Exit/nonzero/timeout is result not error. JSON gives `code`, `ms`, `signal`, `stdout`, `stderr` (base64 in API?), `timed_out`, `truncated`.
- `hc file`: `read`/`write`/`edit` here or `--on`. Read gives lines with offset/limit (max 8MB). Write replaces whole file, creates parents, follows symlink. Edit requires each `old` found exactly once, all-or-none, repeatable pairs. Paths relative to cwd or absolute; remote paths relative to machine home unless cwd set.
- `hc put`: send local file beside terminal on its machine to a temp folder (name kept), prints path; removed with terminal. Types nothing - paste path yourself.
- `hc connect`: speak protocol over stdin/stdout (for SSH). `hc schema`: OpenRPC JSON Schema of API.
- `hc api` does not exist as subcommand. API methods per schema: hello, server.status/stop/restart, terminal.run/list/get/kill/rm/keep/label/read/attach/send/wait/keys/interrupt/put, templates.list, events.subscribe, machine.add/list/connect/rename/rm, machine.exec, file.read/write/edit, doc.get/set, rpc.discover. Framed mode supported via hello.

## 10) Capabilities missing for crew launcher vs workarounds
Crew launcher needs (from problem): terminal lifecycle, agent launch, naming, status, messaging, waiting, reading, environment, working directory, recovery/restart, events, labels, discovery, programmatic API.

**Available:** all above covered well via CLI + JSON API/schema. Strong: status from OSC 7501, wait/children/wait semantics, events stream, templates with first message + readiness, parent-child + notes, labels, machines/remote exec/file, keep/recovery, scoped sweep, addresses/names.

**Gaps / limitations:**
- No workspace/tab/pane layout in hc (must use herdr-app) - fine as long as app handles visibility via labels.
- No built-in "group/crew" object API beyond parent-child links, labels, and `wait --children`. Orchestration is implicit.
- Status depends on agents emitting OSC 7501; programs with no status report as "working until exit" and wait behaves differently (no agent status). 
- `send` blocked by permission/question unless `--force` (correct safety) - launcher must handle via `keys` or user intervention.
- First message can fail to send if not ready (returned in result) - launcher must check and retry after readiness.
- Name uniqueness only among live terminals - can reuse names after finish (observed). Addresses always unique per core.
- Kept terminals become shells on recovery (never rerun task) - launcher must track intent separately.
- `events` is a stream (needs long-running connection); CLI can follow but for programmatic use need API client over socket/connect.
- `hc server stop/restart` affects all terminals (dangerous globally) - need isolated session for tests.
- Socket path length limits HC_SESSION on some systems (observed error) - need short session names or config socket.
- Windows specifics (elevated SSH, shell env refresh) noted.
- No direct "list agents by role/template" beyond labels/templates; discovery is via ls/get/events.
- `doc` API exists (opaque JSON) - could be used for shared state but not a first-class crew DB.
- `attach` is interactive TTY attach (not headless capture) - use `read`/`events`/`get`.

**Closest workarounds:** use labels for crew membership/role, parent-child for hierarchy, `wait --children` for coordination, events for state changes, templates for agent roles, `doc` for shared metadata, isolated `HC_SESSION` for testing, `keep` only if intentional recovery desired.

## Evidence index (key)
- CLI: `hc --help`, `hc --skill`, all `* --help` (exit codes recorded)
- Schema: `hc schema` -> /tmp/hc-schema.json, inspected methods/schemas
- State: `~/.local/state/herdr-core/default/{core.json,docs.json,terminals.json}` (live data)
- Source: cloned /tmp/hc-src (commit 5a9de29b) - templates.rs, config.rs, status.rs, notes.rs, addr.rs, terminals.rs, api/run.rs, sweep.rs, kept.rs, runtime.rs, holder.rs
- Live tests (isolated HC_SESSION=ra): ls/run/get/wait/read/label/kill/rm/send/keys/interrupt/put/exec/file/events/templates/blocked/OSC7501/foreground-timeout
