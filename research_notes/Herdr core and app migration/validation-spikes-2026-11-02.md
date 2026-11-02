# Validation spikes for the core and app migration

Run: 2026-11-02, macOS, `hc` 0.1.16, `herdr-app` 0.1.11. Purpose: replace the contract-level unknowns in [`reports/Herdr core and app migration.md`](../../reports/Herdr%20core%20and%20app%20migration.md) with observed behavior before any launcher rewrite.

## Isolation

- Core-only checks used `HC_SESSION=cs` with scratch `XDG_*` paths under `/tmp/cs`. That core started as a separate process and was stopped at the end.
- App checks cannot use that session. `herdr-app do` creates terminals in the running window's core, so the spikes used a disposable space named `crew-spike` in the user's window. The space was closed, every terminal it created was removed, and the live terminal list returned to the pre-spike set. No existing terminal was read, sent to, or killed.
- A short `HC_SESSION` value is required. A long scratch path pushed the socket path past the 103-byte limit.
- The trust-dialog check accepted trust for the scratch folder. That added the temporary path to Claude's local trust list; the directory is disposable and no project was opened there after the check.

## Results

| # | Check | Result |
|---|---|---|
| 1 | App-created tab is visible to `hc` | Pass |
| 2 | `env CREW_*` prefix reaches the agent | Pass |
| 3 | Status sequence from launch to ready | Pass, with a trust-dialog caveat |
| 4 | Blocked send is distinguishable from a missing terminal | Pass |
| 5 | Kill, keep, and same-terminal restart | Pass for the app wrapper; kill still closes the pane |

### 1. App-created tab, IDs and layout

`herdr-app do tab.new --space <sp> --name spike1 --argv '["sh","-c","echo SPIKE1_READY; sleep 600"]'` returned:

```json
{ "space": "sp6d1e...", "tab": "tbb12f...", "terminal": "t36" }
```

- `tab.new` returns a terminal but not a pane. The pane ID comes from `herdr-app ls`.
- `hc get t36` succeeded 0.27 s after creation. A second measurement returned in 0.008 s.
- `hc get` showed `labels: { "herdr.space": "sp6d1e...", "herdr.tab": "tbb12f...", "where": "crew-spike / spike1" }`, `keep: true`, `die_with_parent: false`.
- `hc ls` and `herdr-app ls` used the same `t36` address. The address is stable for the terminal's life.
- `herdr-app do tab.rename --id <tab> --name "T7 driver: started"` returned `{ "ok": true }` and the new name appeared in `ls`.
- `herdr-app do pane.split --direction right --pane <pane> --argv '["sleep","120"]'` returned `{ "pane": "pe6d...", "terminal": "t3c" }`. Both terminals appeared in the same tab under distinct panes.

### 2. Per-pane environment

`tab.new` with this argv:

```json
["env","CREW_SLUG=spike-slug","CREW_TASK=T7","CREW_AGENT=driver","CREW_WS=sp6d1e00",
 "sh","-c","env | grep ^CREW_; echo HC_TERMINAL_ID=$HC_TERMINAL_ID; sleep 300"]
```

produced this screen:

```text
CREW_AGENT=driver
CREW_SLUG=spike-slug
CREW_WS=sp6d1e00
CREW_TASK=T7
HC_TERMINAL_ID=t37
```

The `env` prefix works. The core also sets `HC_TERMINAL_ID` in the terminal.

### 3. Readiness and status

The app does not execute `argv` directly. `hc get` shows this for every app-created terminal:

```json
["/bin/zsh","-lic","\"$@\"; exec \"$0\" -li","/bin/zsh", ...the original argv...]
```

The wrapper runs the program, then replaces itself with an interactive login shell. This is the keep-alive shell that the report treated as a remaining cost. The app already provides it.

Untrusted folder with a real `claude` launch:

- `status` stayed `null` and `reported` stayed `false` for the full 30 s trust dialog. The screen showed `❯ No, exit / Yes, I trust this folder`.
- `hc keys <t> down enter` accepted trust. Within 1.5 s the status became `idle`, `reported: true`.
- A plain `hc send` then reported `started: true, status: idle, turn: 0`; the next raw status was `done`, `turn: 1`.

Launch with a first task through `tab.new --task "Reply with exactly: READY-OK"`:

```text
 0-4 s  status=null
 6 s    status=working
14 s    status=done  turn=1
```

The scrollback contained `❯ Reply with exactly: READY-OK` and `⏺ READY-OK`. `tab.new` returns only `{space, tab, terminal}` and no first-message delivery result. `hc run` is not a substitute: a trailing argument is passed to the command, not sent as a task.

Synthetic OSC 7501 probes:

- `printf '\033]7501;state=blocked\007'` sets `status.state=blocked`.
- Adding `;kind=permission;msg=...` made the whole report invalid (`status` stayed null). Keep the payload to `state=<word>`.
- `turn` increments when the status leaves `working`. `hc wait` returned `reason: status, status: done, turn: 1`.

### 4. Blocked send

Against a terminal reporting `blocked`:

| Command | Exit | Result |
|---|---|---|
| `hc send <t> hello` | 9 | `kind: blocked`, "typing would answer its dialog" |
| `hc send t99 hello` | 3 | `kind: not_found` |
| `hc send --if idle <t> hello` | 9 | `kind: blocked` |
| `hc send --force <t> FORCED-TEXT` | 0 | `started: false, status: blocked`; text appeared on screen |
| `hc keys <t> enter` | 0 | No refusal |

Exit 9 and exit 3 are distinct. `--force` delivers but does not claim a started turn.

### 5. Kill, keep, restart

| Case | Observed |
|---|---|
| `hc kill` an app-created terminal | App tab and pane disappeared within 1.5 s. `hc get` reported `state: finished`, `reason: killed`, `exit_code: 1`. `keep: true` did not recover it. |
| Normal exit with `keep: true` | Stayed `finished`, `exit_code: 0`. No recovery after 4 s. |
| Signal death (`kill -9` on the program PID) with `keep: true` | Terminal returned to `live` with `reason: signaled`, `signal: 9`, `pid: null`. A new shell accepted `hc send 'echo RECOVERED-SHELL'`. |
| App wrapper after an agent exits | Same tab and pane stayed. A shell prompt appeared in the same terminal. `hc send` of a new command ran it. |

## What this changes in the report

- Spike 1 passes: app-created terminals are immediately addressable, and labels carry the space and tab IDs.
- Spike 2 passes: explicit `env` in argv restores per-pane environment without a new API.
- Spike 3 passes with a caveat: status is usable after the agent is ready, but a trust dialog produces `null`, not `blocked`. Readiness must include a screen read, or setup must trust the folder first.
- Spike 4 passes: the launcher can distinguish "needs a person" from "terminal missing" by exit code.
- Spike 5 changes the restart design: the app's own shell wrapper already preserves the terminal and returns to a shell after a normal agent exit. No custom wrapper is needed. An explicit `hc kill` still ends the pane, so "restart after kill" means a new tab.
- `tab.new --task` does not report delivery. The launcher must confirm delivery from `status`/`turn` and the screen, not from a return field.

Remaining unverified: app restart or update with live terminals, pane title behavior, split ratio, headless use, and a real permission-blocked agent. The blocked check used a synthetic OSC report.

## Cleanup

The `crew-spike` space was closed with `herdr-app do space.close --id <sp> --confirmed true`. All nine terminals it created were finished and removed with `hc rm`. The scratch core was stopped with `hc server stop`. The final live set contained no spike terminal.
