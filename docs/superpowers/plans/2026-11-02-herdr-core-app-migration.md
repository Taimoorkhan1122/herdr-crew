# Herdr Core and App Migration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every legacy `herdr` call in `bin/crew` with `herdr-core` (`hc`) for terminal control and `herdr-app` for the visible space, tab and pane frame.

**Architecture:** The app creates the crew space, tabs and panes and returns `t*` terminal IDs. The launcher saves those IDs in agent metadata and uses `hc` for send, read, wait, status, kill and cleanup. The environment travels as an `env CREW_*=... <program>` argv prefix. The app's wrapper shell returns to a prompt after a normal agent exit, so restart reuses the same terminal.

**Tech Stack:** Bash 3.2, existing jq/Git/rg dependencies, `hc` 0.1.16, `herdr-app` 0.1.11, tsk. No new dependency, no `herdr` compatibility shim.

**Spec:** [Migration report](../../../reports/Herdr%20core%20and%20app%20migration.md), [validation note](../../../research_notes/Herdr%20core%20and%20app%20migration/validation-spikes-2026-11-02.md), [ADR 0025](../../adr/0025-herdr-core-app-runtime.md).

## Global Constraints

- Preserve command names, arguments, output, exit codes and Bash 3.2 compatibility except the documented changes: `read` and `wait` are new; headless runs fail; restart after `kill` creates a new pane.
- Keep `~/.herdr/crew/<slug>` and `~/.herdr/worktrees/<slug>`. Keep tsk status, steps and Git worktree ownership unchanged.
- Do not add a `herdr` compatibility shim. Remove the fake `herdr` in the cutover task only after every caller has moved.
- Pure-text paths (`help`, `--version`, `completion`) keep working without `hc`, `herdr-app`, `tsk` or `jq`. Runtime commands require both binaries and a reachable window.
- `launch` and `team` must fail before creating a tsk task or worktree when the app is unavailable.
- Do not bypass a blocked agent. Queue the message on its task and report that a person is needed.
- No installation, publication, merge or live crew launch is authorized by this plan. Each commit needs separate authorization.

## Review Focus

1. A missing or closed app window must fail before any task or worktree exists, with both required commands named. Task 2.
2. A first brief must not be reported as delivered when the agent is booting, showing a trust dialog, or blocked. Task 3.
3. A busy or blocked recipient must receive the message exactly once, through tsk, and must never be typed into a permission dialog. Task 4.
4. A restart after a normal exit must reuse the saved terminal; a restart after `kill` must not pretend the pane still exists. Task 5.
5. `close` must only touch tabs whose names carry the requested `T#` prefix, never another task or the user's tabs. Task 5.

## File and Interface Map

- `test/fixtures/fake-runtime.sh` (new): writes fake `hc` and `herdr-app` into `$FAKE`, using `$STATE` for terminals, statuses, tabs and log entries.
- `test/dry-run.sh`, `test/project-launch.sh`: install the new fakes; add app/core assertions. Keep the legacy `herdr` fake until Task 6.
- `test/partial-init.sh`, `test/test-hook-integration.sh`: source the shared fixture instead of copying a line range from `dry-run.sh` in Task 6.
- `bin/crew`: `ENVV` array; `agent_argv`, `app_argv_json`, `create_space`, `create_tab`, `split_pane`, `wait_ready`, `submit_term`, `terminal_of`; rewrite `target_ws`, `start_agent`, `cmd_say`, `cmd_status`, `cmd_watch`, `cmd_mark`, `cmd_close`, `cmd_restart`.
- `agents/crew-manager/agent.json`, `agents/crew-manager/AGENTS.md`: replace `herdr agent` grants and commands with `herdr-crew read|wait`.
- `README.md`, `SKILL.md`, `docs/features.md`, `docs/STATE.md`: new dependencies, app requirement, headless limit, restart behavior, new commands.
- `docs/adr/0002`, `0007`, `0012`, `0014`, `0015`: only the status line changes where a decision is superseded; bodies stay historical.

### Task 1: Add the core and app fixture

**Files:** Create `test/fixtures/fake-runtime.sh`; modify `test/dry-run.sh`, `test/project-launch.sh`.

**Interfaces:** `install_fake_runtime FAKE STATE` writes executable `hc` and `herdr-app`. `hc get <t> --json` prints `{address,state,status,labels,argv,pid}` with `status` either `null` or `{state}`. `hc ls --json` prints `{terminals:[...]}`. `hc send` exits 9 when the terminal status is `blocked` and 3 when missing. `herdr-app do space.new|tab.new|pane.split` prints IDs; `herdr-app ls` prints spaces with tabs and terminals; `herdr-app do tab.close|tab.rename` prints `{"ok":true}`.

- [ ] Write the fake with state files under `$STATE`: `term.<t>` (agent/status/argv), `space`, `tab.<n>`, `ls.json`, and append every call to `$LOG`.
- [ ] Add a `dry-run.sh` section that exercises the fake directly: create a space, tab and split, read a terminal, send to blocked and missing terminals, and close a tab. Assert IDs, exit codes 9 and 3, and the logged argv.
- [ ] Install the fixture from `dry-run.sh` and `project-launch.sh`; do not add it to the real PATH.
- [ ] Run `/bin/bash test/dry-run.sh` and `/bin/bash test/project-launch.sh`; both keep their current pass counts because the launcher still calls `herdr`.
- [ ] Run `/bin/bash -n test/fixtures/fake-runtime.sh test/dry-run.sh test/project-launch.sh`; record exits.

### Task 2: Environment and topology through the app

**Files:** Modify `bin/crew`, `test/dry-run.sh`.

**Interfaces:** `set_env NAME TASK [JOB] [SELECTION]` fills `ENVV` with `K=V` strings, not `--env` flags. `agent_argv` fills `ARGV` with `env "${ENVV[@]}" <program> <native args>`. `app_argv_json` prints the JSON array with `jq -nc --args '$ARGS.positional'`. `create_space NAME FIRST_TAB ARGV` returns `NEW_SPACE NEW_TAB NEW_TERM`; `create_tab SPACE NAME CWD ARGV` and `split_pane PANE DIRECTION ARGV` return `NEW_TAB`/`NEW_TERM` and `NEW_PANE`/`NEW_TERM`. Each `*.meta` gains `space=`, `tab=`, `terminal=`, `label=`.

- [ ] Change `set_env` and `crew_env_hook` to `ENVV`, keeping every current `CREW_*` value and the OpenCode `OPENCODE_CONFIG_CONTENT` case.
- [ ] Extract the native agent arguments from `start_agent` into `agent_argv`; do not change model, effort, settings, definition or hook contents.
- [ ] Rewrite `target_ws` as `target_space`: reuse `CREW_WS` when it names a live space; else use the `herdr.space` label of `$HC_TERMINAL_ID`; else find `crew-<slug>` in `herdr-app ls`; else create it with the first real tab. Never create an extra empty tab.
- [ ] Rewrite the lead path to call `space.new` once, `tab.new` for the lead, `pane.split right` for the manager, and `pane.split down` for the board with argv `["tsk"]`. Build each argv before creating its pane. Save the returned IDs.
- [ ] Rewrite `cmd_team` the same way: one tab, first member in the root, later members split right then down. Keep worktree creation before topology and all preflight failures before any app call.
- [ ] Replace the lead re-run probe (`herdr agent get`) with `terminal_of "$SLUG-lead"` plus a live `hc get`. Remove `clear_stale_name`; app terminals need no name registry.
- [ ] Add assertions: no `--env` appears in the app log; every `--argv` contains `CREW_SLUG`, `CREW_TASK`, `CREW_AGENT` and `CREW_WS`; `CREW_WS` is the space ID; meta contains `space=`, `tab=`, `terminal=`; `--dry-run` prints the same planned commands and writes no meta.
- [ ] Run `/bin/bash test/dry-run.sh` RED, implement, then GREEN. Record direct exits.

### Task 3: Readiness, trust dialog and the first brief

**Files:** Modify `bin/crew`, `test/dry-run.sh`, `test/project-launch.sh`.

**Interfaces:** `wait_ready TERM TIMEOUT` returns 0 on `idle|working|done`, 1 on `blocked`, 2 on timeout; it reads the screen and answers `trust this folder` with `hc keys <t> down enter`. `submit_term TERM NAME TEXT` returns 0 sent, 1 needs a person, and dies on exit 3. `register_agent` writes `meta`, `brief` and `definition` only after readiness, then calls `submit_term`.

- [ ] Add a readiness loop that polls `hc get` at most once per second and reads `hc read --lines 40` only when status is null or the timeout nears.
- [ ] Auto-trust only a pane the launcher created, only when the screen contains `trust this folder`; send `down` then `enter`, and never auto-answer a permission dialog.
- [ ] Rewrite `submit`: use `hc send`; on exit 9 warn that the agent needs a person and return 1; on exit 3 die; then poll `hc get` for a `working` status or a turn change for 8 seconds. If it did not start, read the screen and retry only Enter when the pasted first line is visible.
- [ ] Keep the existing `agent_argv` selection, model/effort, settings and saved definition bytes. Save metadata after readiness, as today, so a rejected startup does not replace old state.
- [ ] Add assertions: null status then idle leads to one `hc send` and a saved meta; a trust screen produces `hc keys <t> down enter` before send; `blocked` returns 1 and sends nothing; a send exit 9 leaves the message unsent; a send exit 3 fails the launch; a swallowed paste gets one Enter retry.
- [ ] Run the focused sections RED then GREEN; record exits.

### Task 4: Say, read, wait, status, watch and mark

**Files:** Modify `bin/crew`, `test/dry-run.sh`, `agents/crew-manager/agent.json`, `agents/crew-manager/AGENTS.md`.

**Interfaces:** `terminal_of AGENT` prints the saved terminal ID or fails. Add `herdr-crew read <agent> [--lines N]` and `herdr-crew wait <agent> [--timeout S]`. `cmd_say` queues on tsk when the recipient is working past the wait, blocked, or has no terminal. `cmd_status` and `cmd_watch` read `hc ls --json` once and map addresses through saved meta. `cmd_mark` renames the saved tab to `"<label> · <agent>: <note>"`.

- [ ] Implement `terminal_of` from `$SDIR/<agent>.meta` and use it in `say`, `read`, `wait`, `status`, `watch` and `restart`.
- [ ] `say`: send when idle/done; for working, `hc wait <t> --timeout 20`; after the wait send only if idle/done. On blocked or still working, add one `[msg from X to Y]` step when the recipient has a task, else warn that the message was not delivered. Never exit non-zero for a busy recipient.
- [ ] `read` and `wait` pass through to `hc read` and `hc wait`; missing agent state fails with the existing "start it with herdr-crew first" wording.
- [ ] `status` keeps the current task rows, then the same agent set (lead, manager, all task jobs) using saved terminal statuses. `watch` takes one `hc ls` snapshot per poll, keeps the existing event rules, and still reads `tsk list --done`.
- [ ] `mark`: keep the result file, `tsk status`, `tsk steps` and completion hook order. Replace `pane report-metadata` with `herdr-app do tab.rename --id "$tab" --name "$label · $ME: $note"`. Save `label="$T $team"` so `close` still matches.
- [ ] Update Manager grants and prompt: remove `Bash(herdr agent ...)`; add `Bash(herdr-crew read *)` and `Bash(herdr-crew wait *)`; change the Monitor command to `herdr-crew wait <agent> --timeout 60` and the screen read to `herdr-crew read <agent> --lines 80`.
- [ ] Add assertions: idle send once; busy send queued once and exit 0; blocked send queues and never calls `hc send`; no task warns and sends nothing; status rows match saved terminals; watch prints one transition and one gone line; tab rename keeps the `T7 pair` prefix.
- [ ] Run `/bin/bash test/dry-run.sh` RED then GREEN; run `/bin/bash test/agent-config.sh` to confirm grants and definitions.

### Task 5: Restart and close

**Files:** Modify `bin/crew`, `test/dry-run.sh`, `test/worktrees.sh` if close validation needs it.

**Interfaces:** `restart_one NAME` reads `terminal=`, `label=` and the saved argv/definition. It sends `/exit`, waits for a shell prompt or null status, sends the saved agent command into the same terminal, waits for readiness, then submits the saved brief with the handoff line. If the terminal is finished, it fails before creating a tab. `cmd_close` resolves tabs from `herdr-app ls` by `label` prefix and calls `herdr-app do tab.close --id ... --confirmed true`.

- [ ] Save the exact agent command (the `agent_argv` result) in `$SDIR/<name>.cmd` at first launch, so restart does not rebuild model or policy differently.
- [ ] Restart flow: `hc send <t> /exit`; poll up to 30 seconds for `status: null` plus a shell prompt on screen; then `hc send <t> <saved command>`; `wait_ready`; then `submit_term` the brief. Never call `tab.new` or `agent start`.
- [ ] If `hc get` reports `finished`, die with: the agent's pane is gone, relaunch the team.
- [ ] Close: resolve the space from `CREW_WS`; match tab names with exact `"$T $TEAM"` or prefix `"$T "`; close by ID with `--confirmed true`; fail when no match; keep the worktree output unchanged.
- [ ] Add assertions: restart uses the same terminal and no new tab; saved model/effort bytes are reused; a finished terminal fails; close matches only `T7 pair` / `T7 ` tabs and not `T70`.
- [ ] Run `/bin/bash test/dry-run.sh` and `/bin/bash test/worktrees.sh` RED then GREEN; record exits.

### Task 6: Cutover, permissions and documentation

**Files:** Modify `bin/crew`, `test/dry-run.sh`, `test/partial-init.sh`, `test/test-hook-integration.sh`, `test/project-launch.sh`, `README.md`, `SKILL.md`, `docs/features.md`, `docs/STATE.md`, `docs/adr/0002`, `0007`, `0012`, `0014`, `0015`; update `docs/PROGRESS.md` and `docs/LEAD_STATE.md` at the end.

**Interfaces:** Every remaining `herdr` command call is gone. The dependency check names `hc` and `herdr-app`. `help` and `completion` list `read` and `wait`. The Manager permissions match the new commands.

- [ ] Remove the fake `herdr`; replace the `sed` fixture copies with the shared fixture. Run every suite and fix stale assertions.
- [ ] Change the dependency check to require `hc` and `herdr-app`, with install hints, and keep the pure-text paths before it. Add a clear error when no window answers `herdr-app status`.
- [ ] Update `README.md` install and setup flow: install `hc` and the desktop app; drop `tsk setup herdr` and `herdr server reload-config`; state that launch, team and close need a desktop session; document the plain `tsk` board, new `read`/`wait` commands, tab titles and restart behavior.
- [ ] Update `SKILL.md` and `docs/features.md`: dependencies, commands table, headless limit, message refusal, restart limits, split ratio, storage paths unchanged.
- [ ] Update `docs/STATE.md` with the new runtime and remaining live gaps. Mark superseded ADRs by status line only.
- [ ] Grep for `herdr ` in `bin/crew`, `agents/`, `teams/`, `SKILL.md` and `docs/features.md`; only historical ADR text and `herdr-crew` command names may remain.
- [ ] Run the full verification block below once, after the final change. Record each direct exit.

## Required verification

```bash
for script in bin/crew bin/ctx-guard bin/install-skills lib/ux.sh lib/agent-config.sh test/fixtures/fake-runtime.sh test/dry-run.sh test/worktrees.sh test/agent-config.sh test/project-launch.sh test/partial-init.sh test/test-hook-integration.sh test/project-baseline.sh test/hooks.sh; do
  /bin/bash -n "$script" || exit
done
/bin/bash test/dry-run.sh
/bin/bash test/worktrees.sh
/bin/bash test/agent-config.sh
/bin/bash test/project-launch.sh
/bin/bash test/partial-init.sh
/bin/bash test/test-hook-integration.sh
/bin/bash test/project-baseline.sh
/bin/bash test/hooks.sh
git diff --check
```

Run focused tests before the full block. Keep suite runs sequential: this repository's rule forbids one broad parallel pattern. Record direct exits and failed assertion counts. Check Bash and Zsh completion syntax, affected documentation links and the absence of legacy command calls. Separate syntax, hermetic fixtures, real-Git checks and live acceptance in every report. A live crew launch needs separate authorization.

## Execution handoff

Recommended: native task-by-task execution, then one independent whole-change review. The tasks share `bin/crew`, its metadata format and the same fixture, so parallel edits would collide. No execution method has been selected. This plan does not authorize implementation, commits, publication or a live launch.
