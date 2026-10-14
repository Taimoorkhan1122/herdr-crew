#!/usr/bin/env bash
# Hermetic test for bin/crew. Fake herdr, tsk and git go first on PATH: they log argv to $LOG and print canned JSON.
# The real launcher code runs (jq parsing included). No live Herdr, agents or tasks.
set -euo pipefail

CREW="$(cd "$(dirname "$0")/.." && pwd)/bin/crew"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FAKE="$TMP/fake"; STATE="$TMP/state"; export LOG="$TMP/log" STATE TMP
mkdir -p "$FAKE" "$STATE" "$TMP/home"; : >"$LOG"
export REAL_GIT; REAL_GIT=$(command -v git)
REPO="$TMP/crew-demo"; mkdir -p "$REPO"; "$REAL_GIT" -C "$REPO" init -q
REPO=$(cd "$REPO" && pwd -P)
cd "$REPO"
S="crew-d-$(printf %s "$REPO" | shasum | cut -c1-4)"

cat >"$FAKE/herdr" <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  "status server") exit 0 ;;
  "tab create"|"pane split")
    n=$(( $(cat "$STATE/n" 2>/dev/null || echo 0) + 1 )); echo "$n" >"$STATE/n"; p="w1:p$n"
    echo "herdr $* -> $p" >>"$LOG"
    if [[ "$1" == tab ]]; then echo "{\"result\":{\"tab\":{\"tab_id\":\"w1:t$n\"},\"root_pane\":{\"pane_id\":\"$p\"}}}"
    else echo "{\"result\":{\"pane\":{\"pane_id\":\"$p\"}}}"; fi ;;
  "workspace list") echo "{\"result\":{\"workspaces\":[{\"workspace_id\":\"w9\",\"label\":\"$(cat "$STATE/ws" 2>/dev/null)\"}]}}" ;;
  "workspace create") echo "herdr $*" >>"$LOG"; echo '{"result":{"workspace":{"workspace_id":"w9"}}}' ;;
  "agent get") echo "herdr $*" >>"$LOG"
    [[ -f "$STATE/$3" ]] || { echo '{"error":{"code":"agent_not_found"}}'; exit 1; }
    echo "{\"result\":{\"agent\":{\"pane_id\":\"w1:p1\",\"agent_status\":\"$(cat "$STATE/$3")\"}}}" ;;
  "agent rename") echo "herdr $*" >>"$LOG"; rm -f "$STATE/stale" "$STATE/$3" ;;
  "agent start") echo "herdr $*" >>"$LOG"
    if [[ -f "$STATE/stale" ]]; then echo '{"error":{"code":"agent_name_in_use"}}'; exit 1; fi
    for ((j=1; j <= $#; j++)); do
      if [[ "${!j}" == --settings ]]; then j=$((j+1)); printf '%s' "${!j}" >"$STATE/settings.json"; fi
    done
    echo idle >"$STATE/$3"
    if [[ -f "$TMP/trust" ]]; then rm -f "$TMP/trust"; echo '{"error":{"code":"agent_not_ready"}}'; exit 1; fi ;;
  "agent wait") echo "herdr $*" >>"$LOG"
    if [[ -f "$STATE/ambiguous" ]]; then exit 1; fi
    if [[ -f "$STATE/quick-done" ]]; then [[ " $* " == *" --until done "* ]]; exit $?; fi
    if [[ -f "$STATE/paste" ]]; then [[ -f "$STATE/entered" ]]; else [[ "$(cat "$STATE/$3" 2>/dev/null)" =~ ^(idle|done)$ ]]; fi ;;
  "agent read") [[ ! -f "$STATE/paste" ]] || echo '[Pasted text #1 +80 lines]' ;;
  "agent send-keys") echo "herdr $*" >>"$LOG"; [[ "$4" != enter ]] || touch "$STATE/entered" ;;
  "agent prompt") echo "herdr $*" >>"$LOG"
    if [[ "$4" == /exit ]]; then touch "$STATE/shell"; [[ ! -f "$STATE/gone" ]]; else :; fi ;;
  "pane read") printf '%s\n' "❯ No, exit" "  Yes, I trust this folder" ;;
  "pane process-info") echo "herdr $*" >>"$LOG"
    if [[ -f "$STATE/live" || ( ! -f "$STATE/stale" && ! -f "$STATE/shell" ) ]]; then echo '{"result":{"process_info":{"foreground_process_group_id":2,"shell_pid":1}}}'; exit 0; fi
    echo '{"result":{"process_info":{"foreground_process_group_id":1,"shell_pid":1}}}' ;;
  "tab list") echo '{"result":{"tabs":[{"tab_id":"w1:t1","label":"T7 pair"},{"tab_id":"w1:t2","label":"T7 review"}]}}' ;;
  "pane run"|"pane report-metadata"|"tab close") echo "herdr $*" >>"$LOG" ;;
  *) echo "herdr $*" >>"$LOG"; echo "unhandled: herdr $*" >&2; exit 1 ;;
esac
SH
cat >"$FAKE/tsk" <<'SH'
#!/usr/bin/env bash
echo "tsk $*" >>"$LOG"
case "$1" in
  add) echo '{"number":7,"outcome":"created"}' ;;
  list) if [[ " $* " == *" -p "* && " $* " == *" --done "* ]]; then
          # done list: T7 only once the open list read it as done (like the real tsk, which hides done tasks)
          if [[ "$(cat "$STATE/tsk-last" 2>/dev/null)" == done ]]; then echo '[{"number":7,"status":"done","title":"fix the login bug","notes":""}]'; else echo '[]'; fi
        elif [[ " $* " == *" -p "* ]]; then
          # board read: T7 status comes from $STATE/tsk-seq (one status per poll), T8 stays ready. Done T7 is left out.
          st=ready
          if [[ -f "$STATE/tsk-seq" ]]; then st=$(head -1 "$STATE/tsk-seq"); tail -n +2 "$STATE/tsk-seq" >"$STATE/tsk-seq.n"; mv -f "$STATE/tsk-seq.n" "$STATE/tsk-seq"; fi
          echo "$st" >"$STATE/tsk-last"
          if [[ "$st" == done ]]; then echo '[{"number":8,"status":"ready","title":"other","notes":""}]'
          else echo "[{\"number\":7,\"status\":\"$st\",\"title\":\"fix the login bug\",\"notes\":\"\"},{\"number\":8,\"status\":\"ready\",\"title\":\"other\",\"notes\":\"\"}]"; fi
        else echo '[{"number":7,"notes":""}]'; fi ;;
esac
SH
cat >"$FAKE/git" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"rev-parse --path-format=absolute --git-common-dir"*) echo "$TMP/crew-demo/.git" ;;
  *"symbolic-ref --short HEAD"*) echo crew/T7-pair ;;
  *"rev-parse --verify"*) [[ -n "${BRANCH_EXISTS:-}" && "${*: -1}" == refs/heads/crew/T7-pair ]] ;;
  *"worktree add"*|*"checkout --detach"*) echo "git $*" >>"$LOG" ;;
  *) exec "$REAL_GIT" "$@" ;;
esac
SH
chmod +x "$FAKE"/*
export PATH="$FAKE:$PATH" HOME="$TMP/home" HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 CREW_WS=w1
unset CREW_SLUG CREW_REPO CREW_AGENT CREW_TASK CREW_MANAGER CREW_DRY_RUN BRANCH_EXISTS

fails=0
pass() { echo "PASS: $1"; }
flunk() { echo "FAIL: $1"; fails=$((fails+1)); }
reset() { : >"$LOG"; }
cnt() { grep -c -- "$1" "$LOG" || true; }
in_log() { if grep -qF -- "$2" "$LOG"; then pass "$1"; else flunk "$1 (missing: $2)"; fi; }
in_out() { if grep -qF -- "$2" <<<"$3"; then pass "$1"; else flunk "$1 (missing: $2)"; fi; }
# panes_ok LABEL: every pane split / tab create carries CREW_WS and CREW_AGENT, and that agent starts in that pane
panes_ok() {
  local bad=0 line pane agent
  while IFS= read -r line; do
    pane=${line##*-> }; agent=$(sed -n 's/.* CREW_AGENT=\([^ ]*\).*/\1/p' <<<"$line")
    [[ "$line" == *" CREW_WS=w"* ]] || bad=$((bad+1))
    [[ "$agent" == *-board ]] && continue
    grep -qF -- "agent start $agent --pane $pane " "$LOG" || bad=$((bad+1))
  done < <(grep -E 'pane split|tab create' "$LOG")
  if (( bad == 0 )); then pass "$1"; else flunk "$1 ($bad bad panes)"; fi
}
# reject LABEL WANT STDIN ARGS...: must fail with WANT and must not reach herdr, tsk or git worktree
reject() {
  local label=$1 want=$2 input=$3 out rc=0 before; shift 3
  before=$(wc -l <"$LOG")
  out=$(printf '%s\n' "$input" | "$CREW" "$@" 2>&1) || rc=$?
  if (( rc != 0 )) && grep -qF -- "$want" <<<"$out" && [[ $(wc -l <"$LOG") == "$before" ]]; then pass "$label"; else flunk "$label (rc=$rc, out: $out)"; fi
}

# 1. lead tab: tab + 3 panes, lead in the root pane, manager and board split off it, no worktree
reset
out=$(echo "add hello.txt" | "$CREW" launch lead - 2>&1)
in_out "lead: ready" "ready: $S-lead" "$out"
in_log "lead: tab create with the lead's env" "tab create --workspace w1 --cwd $REPO --label crew $S --no-focus --env CREW_SLUG=$S"
in_log "lead: lead starts in root pane with crew-lead" "agent start $S-lead --pane w1:p1 --timeout 120000 --kind claude -- --agent crew-lead -n $S-lead"
in_log "lead: manager starts with crew-manager" "--agent crew-manager -n $S-manager"
in_log "lead: board pane runs tsk" "pane run"
[[ $(cnt 'pane split') == 2 ]] && pass "lead: 2 splits (3 panes)" || flunk "lead: expected 2 splits"
[[ $(cnt 'worktree add') == 0 ]] && pass "lead: no worktree" || flunk "lead: unexpected worktree"
panes_ok "lead: every pane carries its agent env and CREW_WS"

# 2. team pair on a job persona: task, own branch worktree, driver (member) + navigator (inspector)
reset
out=$(echo "fix the login bug" | "$CREW" launch driver - 2>&1)
in_out "pair: task created" "created task T7" "$out"
in_log "pair: tsk add with --title/--notes/-p repo" "tsk add --title=fix the login bug --notes=fix the login bug -p $REPO --json"
in_log "pair: new branch in its worktree" "worktree add -b crew/T7-pair $HOME/.herdr/worktrees/$S/T7-pair HEAD"
in_log "pair: tab in the worktree" "tab create --workspace w1 --cwd $HOME/.herdr/worktrees/$S/T7-pair --label T7 pair"
in_log "pair: driver is member rank" "--agent crew-member -n $S-t7-driver"
in_log "pair: navigator is inspector rank" "--agent crew-inspector -n $S-t7-navigator"
in_log "pair: default domain persona" "Persona (pragmatic-senior)"
in_log "pair: job skills loaded" "Load these skills now: /tdd /verification-before-completion"
panes_ok "pair: every pane carries its agent env and CREW_WS"

# 3. review checks out the pair branch; test branches from it (or from HEAD when no pair branch)
reset
out=$(BRANCH_EXISTS=1 "$CREW" team review T7 "check it" 2>&1)
in_log "review: detached checkout of crew/T7-pair" "worktree add --detach $HOME/.herdr/worktrees/$S/T7-review crew/T7-pair"
in_log "review: reviewer starts as inspector" "--agent crew-inspector -n $S-t7-code-reviewer"
panes_ok "review: every pane carries its agent env and CREW_WS"
reset
out=$(BRANCH_EXISTS=1 "$CREW" team test T7 "write tests" 2>&1)
in_log "test: new branch from crew/T7-pair" "worktree add -b crew/T7-test $HOME/.herdr/worktrees/$S/T7-test crew/T7-pair"
in_log "test: tester is member rank" "--agent crew-member -n $S-t7-tester"
reset
out=$("$CREW" team test T8 "write tests" 2>&1)
in_log "test: falls back to HEAD without a pair branch" "worktree add -b crew/T8-test $HOME/.herdr/worktrees/$S/T8-test HEAD"
reject "review: refuses without the pair branch" "no branch crew/T8-pair" "" team review T8 "check it"

# 4. text starting with a dash
reset
out=$(echo "-fix parser" | "$CREW" launch driver - 2>&1)
in_log "dash text: = form keeps the title" "tsk add --title=-fix parser --notes=-fix parser -p $REPO --json"

# 5. say: idle agent gets a prompt from the real sender; busy agent gets a queued step, exit 0
reset
CREW_AGENT=$S-t7-navigator "$CREW" say "$S-t7-driver" "hello there" >/dev/null
in_log "say idle: prompt from the real sender" "agent prompt $S-t7-driver [from $S-t7-navigator] hello there"
echo working >"$STATE/$S-t7-driver"; reset
out=$(CREW_AGENT=$S-t7-navigator "$CREW" say "$S-t7-driver" "hold on" 2>&1)
in_out "say busy: queued" "queued on T7" "$out"
in_log "say busy: step on the recipient's task" "tsk steps T7 add [msg from $S-t7-navigator to $S-t7-driver] hold on"
[[ $(cnt 'agent prompt') == 0 ]] && pass "say busy: no prompt sent" || flunk "say busy: prompted a busy agent"

# 6. mark uses the real CREW_AGENT
reset
CREW_AGENT=$S-t7-driver "$CREW" mark T7 review "tests pass" >/dev/null
in_log "mark: status change" "tsk status T7 review"
in_log "mark: note as a step" "tsk steps T7 add tests pass"
in_log "mark: real agent name in the pane title" "T7 $S-t7-driver: tests pass"

# 7. status: names probed per task, state from herdr agent get
out=$("$CREW" status 2>&1)
in_out "status: driver name and state" "$S-t7-driver"$'\t'"working" "$out"

# 8. lead re-run: say, no tab
reset
out=$(echo "more work" | "$CREW" launch lead - 2>&1)
in_out "lead re-run: sends to the running lead" "already running" "$out"
in_log "lead re-run: prompt from the user" "agent prompt $S-lead [from user] more work"
[[ $(cnt 'tab create') == 0 ]] && pass "lead re-run: no tab created" || flunk "lead re-run: created a tab"

# 9. trust dialog: agent_not_ready, then select Yes (down), Enter, wait, brief
reset; touch "$TMP/trust"
out=$(echo "fix trust" | "$CREW" launch driver - 2>&1)
in_log "trust: select Yes first (down)" "send-keys $S-t7-driver down"
in_log "trust: then Enter" "send-keys $S-t7-driver enter"
[[ "$(grep -m1 send-keys "$LOG")" == *" down" ]] && pass "trust: down comes before enter" || flunk "trust: wrong key order"

# 10. outside Herdr: reuse the crew workspace instead of creating another
reset; echo "crew-$S" >"$STATE/ws"
out=$(echo "reuse" | env -u HERDR_ENV "$CREW" launch driver - 2>&1)
in_log "outside herdr: reuses crew workspace w9" "tab create --workspace w9"
[[ $(cnt 'workspace create') == 0 ]] && pass "outside herdr: no new workspace" || flunk "outside herdr: created a workspace"
rm -f "$STATE/ws"

# 11. same-prefix repos get different slugs
for r in client-portal-web client-portal-api; do mkdir -p "$TMP/$r"; "$REAL_GIT" -C "$TMP/$r" init -q; done
slug_of() { (cd "$1" && echo "hi" | "$CREW" launch lead - 2>&1 | sed -n "s/.*tab 'crew \(.*\)' ready.*/\1/p"); }
a=$(slug_of "$TMP/client-portal-web"); b=$(slug_of "$TMP/client-portal-api")
[[ "$a" == client-* && "$a" != "$b" ]] && pass "slugs: same-prefix repos differ ($a, $b)" || flunk "slugs: ($a, $b)"

# 12. rejects: validation fails before any command runs
reject "reject: unknown persona" "unknown persona 'nope'" "x" launch driver@nope -
reject "reject: unknown rank" "unknown rank 'wizard'" "x" launch wizard@driver -
reject "reject: rank mismatch" "use member@driver" "x" launch inspector@driver -
reject "reject: team unknown domain" "unknown persona 'nope'" "" team pair T3 --persona driver=nope
reject "reject: team job not in team" "has no job 'tester'" "" team pair T3 --persona tester=react-expert

# 13. AXI: driver brief names gh-axi, navigator brief has no AXI line, a missing tool warns and does not fail
brief_of() { awk -v n="herdr agent prompt $1 " 'index($0,n)==1{p=1;next} /^herdr /{p=0} p' "$LOG"; }
reset
out=$(echo "axi check" | "$CREW" launch driver - 2>&1)
drv=$(brief_of "$S-t7-driver"); nav=$(brief_of "$S-t7-navigator")
in_out "axi: driver brief lists gh-axi" "AXI tools (prefer these over raw CLIs; run with no args for a dashboard, follow help[] hints): gh-axi" "$drv"
[[ -n "$nav" && "$nav" != *"AXI tools"* ]] && pass "axi: navigator brief has no AXI line" || flunk "axi: navigator brief empty or has an AXI line"
# PATH without any *-axi tool: symlink farm of the current PATH minus the AXI CLIs (first dir wins)
NOAXI="$TMP/noaxi"; mkdir -p "$NOAXI"
( IFS=:; for d in $PATH; do for f in "$d"/*; do b=${f##*/}; case "$b" in *-axi) ;; *) ln -s "$f" "$NOAXI/$b" 2>/dev/null || true ;; esac; done; done )
reset
rc=0; out=$(echo "axi missing" | env PATH="$NOAXI" "$CREW" launch driver - 2>&1) || rc=$?
in_out "axi missing: warns" "warning: AXI tool 'gh-axi' not on PATH" "$out"
in_out "axi missing: launch still creates the task" "created task T7" "$out"
(( rc == 0 )) && pass "axi missing: does not fail" || flunk "axi missing: rc=$rc"

# 14. review spec on a new task: dies before any tsk, herdr or git call (reject checks the log is unchanged)
reject "review launch: refuses before creating a task" "review needs an existing pair task" "review me" launch code-reviewer -

# 15. team outside crew panes (no CREW_WS): the tab goes in HERDR_WORKSPACE_ID
reset
out=$(env -u CREW_WS HERDR_ENV=1 HERDR_WORKSPACE_ID=w5 "$CREW" team pair T7 "do it" 2>&1)
in_log "team fallback: tab in HERDR_WORKSPACE_ID" "tab create --workspace w5 --cwd $HOME/.herdr/worktrees/$S/T7-pair --label T7 pair"
panes_ok "team fallback: every pane carries CREW_WS=w5"

# 16. launch sets the new task to ready after tsk add
reset
out=$(echo "mark ready" | "$CREW" launch driver - 2>&1)
in_log "launch: task set to ready" "tsk status T7 ready"
[[ $(grep -n 'tsk add' "$LOG" | cut -d: -f1) -lt $(grep -n 'tsk status T7 ready' "$LOG" | cut -d: -f1) ]] && pass "launch: ready comes after tsk add" || flunk "launch: ready before tsk add"

# 17. autonomous completion: review re-runs reuse the worktree, close takes a team, prompts carry the review loop
reset; mkdir -p "$HOME/.herdr/worktrees/$S/T7-review"
out=$(BRANCH_EXISTS=1 "$CREW" team review T7 "again" 2>&1)
in_log "review reuse: checkout --detach of crew/T7-pair in the existing worktree" "checkout --detach crew/T7-pair"
[[ $(cnt 'worktree add --detach') == 0 ]] && pass "review reuse: no new worktree add" || flunk "review reuse: added a worktree"
rmdir "$HOME/.herdr/worktrees/$S/T7-review"
reset
out=$("$CREW" close T7 review 2>&1)
in_log "close team: closes the T7 review tab" "tab close w1:t2"
[[ $(cnt 'tab close w1:t1') == 0 ]] && pass "close team: leaves the T7 pair tab" || flunk "close team: closed the T7 pair tab"
in_out "prompt: manager runs the review team" "herdr-crew team review T<n>" "$(cat "$(dirname "$CREW")/../ranks/crew-manager.md")"
in_out "prompt: manager marks done after approval" "mark T<n> done" "$(cat "$(dirname "$CREW")/../ranks/crew-manager.md")"
in_out "prompt: reviewer approves with approve" '"approve"' "$(cat "$(dirname "$CREW")/../personas/code-reviewer.md")"
in_out "prompt: navigator verdict uses nav fix:" "nav fix:" "$(cat "$(dirname "$CREW")/../personas/navigator.md")"

# 18. context budget and Monitor: ctx-guard hook, --settings and saved state, handoff, restart, watch, rank prompts
GUARD="$(dirname "$CREW")/ctx-guard"
CTXDIR="$TMP/ctx"; mkdir -p "$CTXDIR"
# transcript with a main-thread turn of 140000 tokens (split over three usage fields), then a sub-agent turn that must be ignored
printf '%s\n' '{"type":"user","message":{"content":"hi"}}' \
  '{"type":"assistant","message":{"usage":{"input_tokens":10000,"cache_read_input_tokens":120000,"cache_creation_input_tokens":10000}}}' \
  '{"type":"assistant","isSidechain":true,"message":{"usage":{"input_tokens":999}}}' >"$CTXDIR/big.jsonl"
printf '%s\n' '{"type":"assistant","message":{"usage":{"input_tokens":1000}}}' >"$CTXDIR/small.jsonl"
hook() { printf '{"transcript_path":"%s","session_id":"%s","hook_event_name":"PostToolUse"}' "$1" "$2"; }
out=$(hook "$CTXDIR/big.jsonl" s140 | CREW_SLUG=$S "$GUARD")
in_out "ctx-guard: warns at the limit" "additionalContext" "$out"
in_out "ctx-guard: reports the 140000 size" "Context is 140000 tokens" "$out"
out=$(hook "$CTXDIR/big.jsonl" s140 | CREW_SLUG=$S "$GUARD")
[[ -z "$out" ]] && pass "ctx-guard: once per session" || flunk "ctx-guard: warned twice ($out)"
out=$(hook "$CTXDIR/small.jsonl" s1000 | CREW_SLUG=$S "$GUARD")
[[ -z "$out" ]] && pass "ctx-guard: silent under the limit" || flunk "ctx-guard: warned at 1000 tokens"
out=$(hook "$CTXDIR/missing.jsonl" s404 | CREW_SLUG=$S "$GUARD"); rc=$?
(( rc == 0 )) && [[ -z "$out" ]] && pass "ctx-guard: missing transcript exits 0 and stays silent" || flunk "ctx-guard: missing transcript (rc=$rc)"

# the launched driver is registered with ctx-guard, and its meta and brief are saved for restart
reset
out=$(echo "budget check" | "$CREW" launch driver - 2>&1)
in_log "budget: start passes --settings" "--settings"
in_log "budget: settings register ctx-guard" "$GUARD"
[[ -f "$HOME/.herdr/crew/$S/$S-t7-driver.meta" ]] && pass "budget: meta file saved" || flunk "budget: no meta file"
[[ -f "$HOME/.herdr/crew/$S/$S-t7-driver.brief" ]] && pass "budget: brief file saved" || flunk "budget: no brief file"
in_out "budget: brief names the context budget" "Context budget" "$(cat "$HOME/.herdr/crew/$S/$S-t7-driver.brief")"

# handoff: stdin becomes the file, the task gets a step, and the manager is told
reset; echo idle >"$STATE/$S-manager"
out=$(echo "Goal: fix login. Done: test written." | CREW_AGENT=$S-t7-driver CREW_TASK=T7 "$CREW" handoff "half done" 2>&1)
[[ -f "$HOME/.herdr/crew/$S/handoff-$S-t7-driver.md" ]] && pass "handoff: writes the handoff file" || flunk "handoff: no file"
in_log "handoff: step on the task" "tsk steps T7 add [handoff] $S-t7-driver: half done"
in_log "handoff: prompts the manager for a worker" "agent prompt $S-manager [from $S-t7-driver] $S-t7-driver hit the context limit"
reject "handoff: refuses with no body and no file" "no handoff at" "" handoff "x"

# restart: /exit, wait for the shell, start again in the same pane with the resume line, rename the old handoff
reset
out=$("$CREW" restart "$S-t7-driver" 2>&1)
in_log "restart: /exit the agent" "agent prompt $S-t7-driver /exit"
in_log "restart: starts the agent again" "agent start $S-t7-driver --pane"
in_log "restart: brief resumes from the handoff" "Resume from your handoff: $HOME/.herdr/crew/$S/handoff-$S-t7-driver.md"
set -- "$HOME/.herdr/crew/$S"/handoff-$S-t7-driver.*.md
[[ -f "$1" ]] && pass "restart: old handoff renamed with an epoch" || flunk "restart: handoff not renamed"

# watch: a status change prints one line, unchanged tasks print nothing (two polls)
reset; printf '%s\n' ready review >"$STATE/tsk-seq"
out=$(cd "$REPO" && CREW_WATCH_ONCE=1 CREW_WATCH_SECS=0 "$CREW" watch 2>&1)
in_out "watch: prints the change" "T7 ready -> review: fix the login bug" "$out"
[[ $(printf '%s\n' "$out" | grep -c .) == 1 ]] && pass "watch: unchanged T8 prints nothing" || flunk "watch: extra lines ($out)"

# watch: a task that reaches done leaves the open list; the done list still shows it as review -> done
reset; printf '%s\n' review done >"$STATE/tsk-seq"
out=$(cd "$REPO" && CREW_WATCH_ONCE=1 CREW_WATCH_SECS=0 "$CREW" watch 2>&1)
in_out "watch: review -> done from the done list" "T7 review -> done: fix the login bug" "$out"

# rank prompts: the lead watches the board, the manager restarts on handoff
in_out "prompt: lead has the Monitor tool" "Monitor" "$(cat "$(dirname "$CREW")/../ranks/crew-lead.md")"
in_out "prompt: lead monitors with herdr-crew watch" "herdr-crew watch" "$(cat "$(dirname "$CREW")/../ranks/crew-lead.md")"
in_out "prompt: manager restarts a worker on handoff" "herdr-crew restart <agent>" "$(cat "$(dirname "$CREW")/../ranks/crew-manager.md")"

# 19. Restart survives an agent that already exited.
reset; touch "$STATE/gone"
rc=0; out=$("$CREW" restart "$S-t7-driver" 2>&1) || rc=$?
(( rc == 0 )) && pass "restart gone: succeeds" || flunk "restart gone: rc=$rc"
in_log "restart gone: reaches start" "agent start $S-t7-driver"
rm -f "$STATE/gone" "$STATE/shell"

# 20. A stale name is reclaimed only when its old pane is at the shell.
reset; touch "$STATE/stale"
rc=0; out=$("$CREW" team pair T7 "reclaim name" 2>&1) || rc=$?
(( rc == 0 )) && pass "stale name: launch succeeds" || flunk "stale name: rc=$rc"
in_log "stale name: cleared" "agent rename $S-t7-driver --clear"
rm -f "$STATE/stale" "$STATE/shell"
reset; touch "$STATE/stale" "$STATE/live"
cp "$HOME/.herdr/crew/$S/$S-t7-driver.meta" "$TMP/live.meta"
cp "$HOME/.herdr/crew/$S/$S-t7-driver.brief" "$TMP/live.brief"
rc=0; out=$("$CREW" team pair T7 "keep live name" 2>&1) || rc=$?
(( rc != 0 )) && pass "live name: refused" || flunk "live name: replaced"
[[ $(cnt 'agent rename') == 0 ]] && pass "live name: not cleared" || flunk "live name: cleared"
cmp -s "$TMP/live.meta" "$HOME/.herdr/crew/$S/$S-t7-driver.meta" && pass "live name: restart meta preserved" || flunk "live name: restart meta corrupted"
cmp -s "$TMP/live.brief" "$HOME/.herdr/crew/$S/$S-t7-driver.brief" && pass "live name: brief preserved" || flunk "live name: brief overwritten"
rm -f "$STATE/stale" "$STATE/live"

# 21. Existing branches are attached; retained worktrees are reused.
reset
out=$(BRANCH_EXISTS=1 "$CREW" team pair T7 "reuse branch" 2>&1)
in_log "pair branch: attached without -b" "worktree add $HOME/.herdr/worktrees/$S/T7-pair crew/T7-pair"
mkdir -p "$HOME/.herdr/worktrees/$S/T7-pair"
reset
out=$(BRANCH_EXISTS=1 "$CREW" team pair T7 "reuse worktree" 2>&1)
[[ $(cnt 'worktree add') == 0 ]] && pass "pair worktree: retained" || flunk "pair worktree: added again"
rmdir "$HOME/.herdr/worktrees/$S/T7-pair"

# 22. Visible pasted input gets Enter; ambiguous input is never resent.
reset; touch "$STATE/paste"; rm -f "$STATE/entered"
out=$("$CREW" say "$S-t7-navigator" "paste me" 2>&1)
in_log "paste: extra Enter" "agent send-keys $S-t7-navigator enter"
[[ $(cnt 'agent prompt') == 1 ]] && pass "paste: submitted once" || flunk "paste: duplicate prompt"
rm -f "$STATE/paste" "$STATE/entered"
reset; echo unknown >"$STATE/$S-t7-navigator"
touch "$STATE/ambiguous"
out=$("$CREW" team pair T7 "ambiguous paste" 2>&1)
[[ $(cnt 'agent prompt') == 2 ]] && pass "ambiguous paste: each brief sent once" || flunk "ambiguous paste: brief resent"
rm -f "$STATE/ambiguous"
reset; touch "$STATE/quick-done"
out=$("$CREW" team pair T7 "fast completion" 2>&1)
[[ $(cnt 'agent prompt') == 2 && "$out" != *"did not start working"* ]] && pass "quick completion: accepted once" || flunk "quick completion: retried or warned"
rm -f "$STATE/quick-done"

# 23. SessionStart restores exports in a fresh Claude shell environment.
reset
out=$("$CREW" team pair T7 "resume env" 2>&1)
hook_cmd=$(jq -r '.hooks.SessionStart[0].hooks[0].command // empty' "$STATE/settings.json")
ENVFILE="$TMP/resumed.env"; : >"$ENVFILE"
if [[ -n "$hook_cmd" ]]; then
  env -u CREW_SLUG -u CREW_REPO -u CREW_AGENT -u CREW_TASK -u CREW_MANAGER -u CREW_WS CLAUDE_ENV_FILE="$ENVFILE" bash -c "$hook_cmd"
fi
restored=$(bash -c 'source "$1"; printf "%s|%s|%s|%s|%s|%s" "$CREW_SLUG" "$CREW_REPO" "$CREW_AGENT" "$CREW_TASK" "$CREW_MANAGER" "$CREW_WS"' _ "$ENVFILE")
[[ "$restored" == "$S|$REPO|$S-t7-navigator|T7|$S-manager|w1" ]] && pass "resume: crew exports restored" || flunk "resume: exports missing ($restored)"

# 24. UI domain attaches to existing jobs and reaches both generated briefs.
reset
rc=0; out=$("$CREW" team pair T7 --persona driver=ui-expert --persona navigator=ui-expert "Clean up the settings UI" 2>&1) || rc=$?
(( rc == 0 )) && pass "ui domain: pair launches" || flunk "ui domain: rc=$rc ($out)"
for ui_job in driver navigator; do
  ui_brief=$(brief_of "$S-t7-$ui_job")
  in_out "ui domain: $ui_job receives persona" "Persona (ui-expert):" "$ui_brief"
  in_out "ui domain: $ui_job loads core skills" "/impeccable /react-component-engineering /react-production-engineering /react-quality-engineering" "$ui_brief"
  in_out "ui domain: $ui_job has browser tool" "chrome-devtools-axi" "$ui_brief"
done
reset
rc=0; out=$(BRANCH_EXISTS=1 "$CREW" team review T7 --persona code-reviewer=ui-expert "Review the settings UI" 2>&1) || rc=$?
(( rc == 0 )) && pass "ui domain: review launches" || flunk "ui domain: review rc=$rc ($out)"
in_out "ui domain: reviewer receives persona" "Persona (ui-expert):" "$(brief_of "$S-t7-code-reviewer")"

# 25. Project investigation uses an inspector in the repo, without a branch or worktree.
questions=$'Q1. Does login exist?\nQ2. How does login reach storage?'
for spec in investigator inspector@investigator; do
  reset
  rc=0; out=$(printf '%s\n' "$questions" | "$CREW" launch "$spec" - 2>&1) || rc=$?
  (( rc == 0 )) && pass "investigate $spec: launches" || flunk "investigate $spec: rc=$rc ($out)"
  if (( rc == 0 )); then
    in_out "investigate $spec: task created" "created task T7" "$out"
    in_log "investigate $spec: inspector starts" "--agent crew-inspector -n $S-t7-investigator"
    in_log "investigate $spec: repo cwd" "tab create --workspace w1 --cwd $REPO --label T7 investigate"
    [[ $(cnt 'agent start') == 1 ]] && pass "investigate $spec: one worker" || flunk "investigate $spec: extra worker"
    [[ $(cnt 'worktree add') == 0 && $(cnt 'checkout') == 0 ]] && pass "investigate $spec: no worktree or checkout" || flunk "investigate $spec: git mutation"
    investigation_brief=$(brief_of "$S-t7-investigator")
    in_out "investigate $spec: persona loaded" "Persona (investigator):" "$investigation_brief"
    in_out "investigate $spec: batch preserved" "$questions" "$investigation_brief"
    panes_ok "investigate $spec: pane environment"
  fi
done
reset
rc=0; out=$("$CREW" team investigate T7 --persona investigator=nestjs-expert "$questions" 2>&1) || rc=$?
(( rc == 0 )) && pass "investigate team: launches" || flunk "investigate team: rc=$rc ($out)"
if (( rc == 0 )); then
  investigation_brief=$(brief_of "$S-t7-investigator")
  in_out "investigate domain: NestJS loaded" "Persona (nestjs-expert):" "$investigation_brief"
  in_log "investigate domain: inspector retained" "--agent crew-inspector -n $S-t7-investigator"
  [[ $(cnt 'agent start') == 1 && $(cnt 'worktree add') == 0 ]] && pass "investigate team: one worker, no worktree" || flunk "investigate team: extra worker or worktree"
fi
reject "investigate: wrong rank refused before mutations" "is a inspector job" "check login" launch member@investigator -

# 26. Planning launches one documentation worker and declares a separate approval gate.
plan_request=$'Plan a safe restart fix.\nExplain failure before implementation.'
for spec in planner member@planner; do
  reset
  rc=0; out=$(printf '%s\n' "$plan_request" | "$CREW" launch "$spec" - 2>&1) || rc=$?
  (( rc == 0 )) && pass "plan $spec: launches" || flunk "plan $spec: rc=$rc ($out)"
  if (( rc == 0 )); then
    in_log "plan $spec: planning branch" "worktree add -b crew/T7-plan"
    in_log "plan $spec: member rank" "--agent crew-member -n $S-t7-planner"
    [[ $(cnt 'agent start') == 1 && $(cnt 'pane split') == 0 ]] && pass "plan $spec: one worker" || flunk "plan $spec: extra worker"
    plan_brief=$(brief_of "$S-t7-planner")
    in_out "plan $spec: original request" "$plan_request" "$plan_brief"
    in_out "plan $spec: documentation scope" "Planning artifacts only" "$plan_brief"
    in_out "plan $spec: contract pointer" "docs/planning/visual-plan-contract.md" "$plan_brief"
    in_out "plan $spec: reports version" "plan ready:" "$plan_brief"
    in_out "plan $spec: visual tooling" "lavish-axi" "$plan_brief"
    panes_ok "plan $spec: environment"
  fi
done
reset
rc=0; out=$("$CREW" team plan T7 "$plan_request" 2>&1) || rc=$?
(( rc == 0 )) && pass "plan team: existing task" || flunk "plan team: rc=$rc ($out)"
[[ $(cnt 'tsk add') == 0 ]] && pass "plan team: no duplicate task" || flunk "plan team: duplicate task"
reject "plan: wrong rank refused" "is a member job" "write plan" launch inspector@planner -
lead_rules=$(cat "$(dirname "$CREW")/../ranks/crew-lead.md")
manager_rules=$(cat "$(dirname "$CREW")/../ranks/crew-manager.md")
in_out "planning rules: Lead dispatch" "Run T<n> (plan)" "$lead_rules"
in_out "planning rules: approval evidence" "[plan approved]" "$lead_rules"
in_out "planning rules: revisions reopen" "reopen the same planning task" "$lead_rules"
in_out "planning rules: testing is not approval" "testing or simulation" "$lead_rules"
in_out "planning rules: standalone review" "standalone planner stays at review" "$manager_rules"
in_out "planning rules: draft completion" 'done "plan ready:' "$manager_rules"
in_out "planning rules: no implicit implementation" "Draft completion never authorizes implementation" "$manager_rules"
in_out "planning rules: handoff limitation" "known restart handoff-file race" "$lead_rules"
planner_rules=$(cat "$(dirname "$CREW")/../personas/planner.md")
in_out "planning source: checks live repo" 'git -C "$CREW_REPO" status --short' "$planner_rules"
in_out "planning source: blocks stale draft" "source drift" "$planner_rules"
in_out "planning source: checks before dispatch" "source drift" "$lead_rules"

echo
if (( fails == 0 )); then echo "ALL PASS"; else echo "$fails FAILED"; exit 1; fi
