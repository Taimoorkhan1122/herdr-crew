#!/usr/bin/env bash
# Hermetic test for bin/crew. Fake herdr, tsk and git go first on PATH: they log argv to $LOG and print canned JSON.
# The real launcher code runs (jq parsing included). No live Herdr, agents or tasks.
set -euo pipefail

CREW="$(cd "$(dirname "$0")/.." && pwd)/bin/crew"
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
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
      if [[ "${!j}" == --agents ]]; then j=$((j+1)); printf '%s' "${!j}" >"$STATE/$3.agents.json"; fi
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
    if [[ "$4" == /exit ]]; then touch "$STATE/shell"; [[ ! -f "$STATE/gone" ]]; else [[ -f "$STATE/$3" ]] || echo idle >"$STATE/$3"; fi ;;
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
          if [[ -f "$STATE/tsk-empty" ]]; then echo '[]'
          else
            st=ready
            if [[ -f "$STATE/tsk-seq" ]]; then st=$(head -1 "$STATE/tsk-seq"); tail -n +2 "$STATE/tsk-seq" >"$STATE/tsk-seq.n"; mv -f "$STATE/tsk-seq.n" "$STATE/tsk-seq"; fi
            echo "$st" >"$STATE/tsk-last"
            if [[ "$st" == done ]]; then echo '[{"number":8,"status":"ready","title":"other","notes":""}]'
            else echo "[{\"number\":7,\"status\":\"$st\",\"title\":\"fix the login bug\",\"notes\":\"\"},{\"number\":8,\"status\":\"ready\",\"title\":\"other\",\"notes\":\"\"}]"; fi
          fi
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
printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE/claude"
chmod +x "$FAKE"/*
export PATH="$FAKE:$PATH" HOME="$TMP/home" HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 CREW_WS=w1
unset CREW_SLUG CREW_REPO CREW_AGENT CREW_TASK CREW_MANAGER CREW_DRY_RUN BRANCH_EXISTS
source "$ROOT/test/fixtures/fake-runtime.sh"
install_fake_runtime "$FAKE" "$STATE"
touch "$STATE/auto-ready"

fails=0
pass() { echo "PASS: $1"; }
flunk() { echo "FAIL: $1"; fails=$((fails+1)); }
reset() { : >"$LOG"; }
cnt() { grep -c -- "$1" "$LOG" || true; }
in_log() { if grep -qF -- "$2" "$LOG"; then pass "$1"; else flunk "$1 (missing: $2)"; fi; }
in_out() { if grep -qF -- "$2" <<<"$3"; then pass "$1"; else flunk "$1 (missing: $2)"; fi; }
json_log() { sed -n '/^\["herdr-app"/p' "$LOG" | jq -s "$@"; }
hc_log() { sed -n '/^\["hc"/p' "$LOG" | jq -s "$@"; }
app_argv_text() { json_log -r '[.[] | select(.[0] == "herdr-app" and .[1] == "do" and (index("--argv") != null)) | . as $call | ($call | index("--argv")) as $i | ($call[$i + 1] | fromjson | join(" "))] | join("\n")'; }
app_settings() { json_log -r '[.[] | select(.[0] == "herdr-app" and .[1] == "do" and (index("--argv") != null)) | . as $call | ($call | index("--argv")) as $i | ($call[$i + 1] | fromjson) as $argv | ($argv | index("--settings")) as $s | select($s != null) | $argv[$s + 1]][-1] // empty'; }
app_agents_json() { json_log -r '[.[] | select(.[0] == "herdr-app" and .[1] == "do" and (index("--argv") != null)) | . as $call | ($call | index("--argv")) as $i | ($call[$i + 1] | fromjson) as $argv | ($argv | index("--agents")) as $a | select($a != null) | $argv[$a + 1]][0] // empty'; }
app_agent_count() { json_log '[.[] | select(.[0] == "herdr-app" and .[1] == "do" and (index("--argv") != null)) | . as $call | ($call | index("--argv")) as $i | ($call[$i + 1] | fromjson) as $argv | select(any($argv[]; startswith("CREW_AGENT=")))] | length'; }
# panes_ok LABEL: each app-created agent terminal receives the complete crew environment.
panes_ok() {
  if json_log -e '
    [.[] | select(.[0] == "herdr-app" and .[1] == "do" and
      (.[2] == "space.new" or .[2] == "tab.new" or .[2] == "pane.split"))]
    | all(.[]; . as $call | ($call | index("--argv")) as $i |
      ($call[$i + 1] | fromjson) as $argv |
      if $argv == ["tsk"] then true else
        all(["CREW_SLUG=", "CREW_TASK=", "CREW_AGENT=", "CREW_WS="][];
          . as $prefix | any($argv[]; startswith($prefix)))
      end)
  ' >/dev/null; then pass "$1"; else flunk "$1 (incomplete app argv)"; fi
}
# reject LABEL WANT STDIN ARGS...: must fail with WANT and must not reach herdr, tsk or git worktree
reject() {
  local label=$1 want=$2 input=$3 out rc=0 before; shift 3
  before=$(wc -l <"$LOG")
  out=$(printf '%s\n' "$input" | "$CREW" "$@" 2>&1) || rc=$?
  if (( rc != 0 )) && grep -qF -- "$want" <<<"$out" && [[ $(wc -l <"$LOG") == "$before" ]]; then pass "$label"; else flunk "$label (rc=$rc, out: $out)"; fi
}

# 1. lead tab: app space with lead root, manager and board split off it, no worktree
reset
out=$(echo "add hello.txt" | "$CREW" launch lead - 2>&1)
in_out "lead: ready" "ready: $S-lead" "$out"
json_log -e '([.[] | select(.[0:3] == ["herdr-app","do","space.new"]) ] | length) == 1 and ([.[] | select(.[0:3] == ["herdr-app","do","pane.split"]) ] | length) == 2' >/dev/null \
  && pass "lead: one app space and two pane splits" || flunk "lead: app topology is incomplete"
json_log -e 'all(.[] | select(.[0] == "herdr-app"); (index("--env") == null))' >/dev/null \
  && pass "lead: app argv uses env prefix, not --env" || flunk "lead: app log contains --env"
json_log -e 'any(.[]; .[0:3] == ["herdr-app","do","pane.split"] and .[4] == "down" and .[-1] == "[\"tsk\"]")' >/dev/null \
  && pass "lead: board is tsk in the down split" || flunk "lead: board argv or direction is wrong"
space_id=$(jq -r '.id // empty' "$STATE/space" 2>/dev/null || true)
json_log --arg space "$space_id" -e 'all([.[] | select(.[0] == "herdr-app" and .[1] == "do" and (.[2] == "pane.split"))][]; . as $call | ($call | index("--argv")) as $i | ($call[$i + 1] | fromjson) as $argv | if $argv == ["tsk"] then true else any($argv[]; . == ("CREW_WS=" + $space)) end)' >/dev/null \
  && pass "lead: later app argv uses its space ID in CREW_WS" || flunk "lead: later app CREW_WS does not match space"
for field in "space=$space_id" "tab=tb1" "terminal=t1" "label=crew $S"; do
  grep -qF "$field" "$HOME/.herdr/crew/$S/$S-lead.meta" && pass "lead: meta saves $field" || flunk "lead: meta missing $field"
done
[[ $(cnt 'worktree add') == 0 ]] && pass "lead: no worktree" || flunk "lead: unexpected worktree"
panes_ok "lead: every pane carries its agent env and CREW_WS"

# 2. team pair on a job persona: task, own branch worktree, driver (member) + navigator (inspector)
reset
space_id=$(jq -r '.id' "$STATE/space")
out=$(echo "fix the login bug" | env CREW_WS="$space_id" "$CREW" launch driver - 2>&1)
in_out "pair: task created" "created task T7" "$out"
in_log "pair: tsk add with --title/--notes/-p repo" "tsk add --title=fix the login bug --notes=fix the login bug -p $REPO --json"
in_log "pair: new branch in its worktree" "worktree add -b crew/T7-pair $HOME/.herdr/worktrees/$S/T7-pair HEAD"
json_log --arg folder "$HOME/.herdr/worktrees/$S/T7-pair" -e 'any(.[]; .[0:3] == ["herdr-app","do","tab.new"] and (index("--folder") as $i | .[$i+1] == $folder))' >/dev/null \
  && pass "pair: tab in the worktree" || flunk "pair: tab not created in its worktree"
in_out "pair: driver is member rank" "--agent crew-member -n $S-t7-driver" "$(app_argv_text)"
in_out "pair: navigator is inspector rank" "--agent crew-inspector -n $S-t7-navigator" "$(app_argv_text)"
in_out "pair: default domain persona" "Persona (pragmatic-senior)" "$(cat "$HOME/.herdr/crew/$S/$S-t7-driver.brief")"
in_out "pair: job skills loaded" "Load these skills now: /tdd /verification-before-completion" "$(cat "$HOME/.herdr/crew/$S/$S-t7-driver.brief")"
for field in space tab terminal label; do
  if grep -q "^$field=." "$HOME/.herdr/crew/$S/$S-t7-driver.meta"; then pass "pair: meta saves $field"; else flunk "pair: meta missing $field"; fi
done
for agent in "$S-t7-driver" "$S-t7-navigator"; do
  for field in space tab terminal label; do
    grep -q "^$field=." "$HOME/.herdr/crew/$S/$agent.meta" && pass "pair: $agent meta saves $field" || flunk "pair: $agent meta missing $field"
  done
done
json_log --arg space "$space_id" -e 'all([.[] | select(.[0] == "herdr-app" and .[1] == "do" and (index("--argv") != null))][]; . as $call | ($call | index("--argv")) as $i | ($call[$i+1] | fromjson) as $argv | if any($argv[]; . == "tsk") then true else any($argv[]; . == ("CREW_WS=" + $space)) end)' >/dev/null \
  && pass "pair: agent argv uses live CREW_WS space ID" || flunk "pair: agent argv has wrong CREW_WS"
panes_ok "pair: every pane carries its agent env and CREW_WS"

# 3. review checks out the pair branch; test branches from it (or from HEAD when no pair branch)
reset
out=$(BRANCH_EXISTS=1 "$CREW" team review T7 "check it" 2>&1)
in_log "review: detached checkout of crew/T7-pair" "worktree add --detach $HOME/.herdr/worktrees/$S/T7-review crew/T7-pair"
in_out "review: reviewer starts as inspector" "--agent crew-inspector -n $S-t7-code-reviewer" "$(app_argv_text)"
panes_ok "review: every pane carries its agent env and CREW_WS"
reset
out=$(BRANCH_EXISTS=1 "$CREW" team test T7 "write tests" 2>&1)
in_log "test: new branch from crew/T7-pair" "worktree add -b crew/T7-test $HOME/.herdr/worktrees/$S/T7-test crew/T7-pair"
in_out "test: tester is member rank" "--agent crew-member -n $S-t7-tester" "$(app_argv_text)"
reset
out=$("$CREW" team test T8 "write tests" 2>&1)
in_log "test: falls back to HEAD without a pair branch" "worktree add -b crew/T8-test $HOME/.herdr/worktrees/$S/T8-test HEAD"
reject "review: refuses without the pair branch" "no branch crew/T8-pair" "" team review T8 "check it"

# 4. text starting with a dash
reset
out=$(echo "-fix parser" | "$CREW" launch driver - 2>&1)
in_log "dash text: = form keeps the title" "tsk add --title=-fix parser --notes=-fix parser -p $REPO --json"

# 5. say sends once when idle; waits once then queues when still working or blocked.
say_term=$(sed -n 's/^terminal=//p' "$HOME/.herdr/crew/$S/$S-t7-driver.meta")
set_say_status() { jq --arg status "$2" '.status = $status | .sendExit = 0' "$STATE/term.$1" >"$STATE/term.$1.tmp" && mv "$STATE/term.$1.tmp" "$STATE/term.$1"; }
reset; set_say_status "$say_term" idle
out=$(CREW_AGENT=$S-t7-navigator "$CREW" say "$S-t7-driver" "hello there" 2>&1)
hc_log -e --arg terminal "$say_term" --arg message "[from $S-t7-navigator] hello there" '[.[] | select(. == ["hc","send",$terminal,$message])] | length == 1' >/dev/null \
  && pass "say idle: sends exactly once through saved terminal" || flunk "say idle: message send count or address is wrong"
in_out "say idle: reports delivery" "sent to $S-t7-driver" "$out"
reset; set_say_status "$say_term" working
rc=0; out=$(CREW_AGENT=$S-t7-navigator "$CREW" say "$S-t7-driver" "hold on" 2>&1) || rc=$?
(( rc == 0 )) && in_out "say working: exits successfully after wait" "queued on T7" "$out" || flunk "say working: command failed"
hc_log -e --arg terminal "$say_term" '[.[] | select(. == ["hc","wait",$terminal,"--timeout","20"])] | length == 1' >/dev/null \
  && pass "say working: waits once before queue" || flunk "say working: did not wait exactly once"
in_log "say working: queues one task step" "tsk steps T7 add [msg from $S-t7-navigator to $S-t7-driver] hold on"
[[ $(cnt '"send"') == 0 ]] && pass "say working: no hc send after wait timeout" || flunk "say working: sent to busy agent"
reset; set_say_status "$say_term" blocked
out=$(CREW_AGENT=$S-t7-navigator "$CREW" say "$S-t7-driver" "permission needed" 2>&1)
in_out "say blocked: queues task step" "queued on T7" "$out"
[[ $(cnt '"send"') == 0 ]] && pass "say blocked: never calls hc send" || flunk "say blocked: attempted send"
[[ $(grep -cF 'tsk steps T7 add [msg from' "$LOG") == 1 ]] && pass "say blocked: queues once" || flunk "say blocked: queued more than once"
lead_term=$(sed -n 's/^terminal=//p' "$HOME/.herdr/crew/$S/$S-lead.meta")
reset; set_say_status "$lead_term" working
out=$(CREW_AGENT=$S-t7-navigator "$CREW" say "$S-lead" "no task message" 2>&1)
in_out "say no-task: warns message not delivered" "message NOT delivered" "$out"
[[ $(cnt '"send"') == 0 && $(cnt 'tsk steps') == 0 ]] && pass "say no-task: sends and queues nothing" || flunk "say no-task: unexpected delivery or queue"

# 6. mark uses the real CREW_AGENT
reset
CREW_AGENT=$S-t7-driver "$CREW" mark T7 review "tests pass" >/dev/null
in_log "mark: status change" "tsk status T7 review"
in_log "mark: note as a step" "tsk steps T7 add tests pass"
mark_tab=$(sed -n 's/^tab=//p' "$HOME/.herdr/crew/$S/$S-t7-driver.meta")
json_log -e --arg tab "$mark_tab" --arg name "T7 pair · $S-t7-driver: tests pass" 'any(.[]; . == ["herdr-app","do","tab.rename","--id",$tab,"--name",$name])' >/dev/null \
  && pass "mark: renames tab and keeps T7 pair prefix" || flunk "mark: wrong tab rename or label prefix"

# 7. status: task rows stay first; agent statuses map saved terminals from one hc ls.
set_say_status "$lead_term" done
manager_term=$(sed -n 's/^terminal=//p' "$HOME/.herdr/crew/$S/$S-manager.meta")
set_say_status "$manager_term" idle
set_say_status "$say_term" working
reset; printf '%s\n' review >"$STATE/tsk-seq"
out=$("$CREW" status 2>&1)
in_out "status: task row remains" "T7"$'\t'"review"$'\t'"fix the login bug" "$out"
in_out "status: lead state from saved terminal" "$S-lead"$'\t'"done" "$out"
in_out "status: manager state from saved terminal" "$S-manager"$'\t'"idle" "$out"
in_out "status: driver state from saved terminal" "$S-t7-driver"$'\t'"working" "$out"
hc_log -e '[.[] | select(. == ["hc","ls","--json"])] | length == 1' >/dev/null \
  && pass "status: reads one hc ls snapshot" || flunk "status: did not use exactly one hc ls"
[[ $(cnt 'agent get') == 0 ]] && pass "status: no legacy agent status probes" || flunk "status: used legacy agent status"

# 7a. read and wait resolve names through saved metadata and pass options through.
printf 'recent screen output\n' >"$STATE/screen.$say_term"
reset; rc=0; out=$("$CREW" read "$S-t7-driver" --lines 12 2>&1) || rc=$?
(( rc == 0 )) || flunk "read: rc=$rc ($out)"
in_out "read: prints terminal output" "recent screen output" "$out"
hc_log -e --arg terminal "$say_term" '[.[] | select(. == ["hc","read",$terminal,"--lines","12"])] | length == 1' >/dev/null \
  && pass "read: passes lines option to hc" || flunk "read: hc arguments are wrong"
reset; rc=0; out=$("$CREW" wait "$S-t7-driver" --timeout 4 2>&1) || rc=$?
(( rc == 0 )) || flunk "wait: rc=$rc ($out)"
hc_log -e --arg terminal "$say_term" '[.[] | select(. == ["hc","wait",$terminal,"--timeout","4"])] | length == 1' >/dev/null \
  && pass "wait: passes timeout option to hc" || flunk "wait: hc arguments are wrong"
for command in read wait; do
  rc=0; out=$("$CREW" "$command" missing-agent 2>&1) || rc=$?
  (( rc != 0 )) && in_out "$command: missing saved state fails clearly" "start it with herdr-crew first" "$out" || flunk "$command: missing state rc=$rc"
done

# 7b. watch emits one terminal transition and one gone event from two snapshots.
manager_term=$(sed -n 's/^terminal=//p' "$HOME/.herdr/crew/$S/$S-manager.meta")
set_say_status "$lead_term" working; set_say_status "$manager_term" working
cp "$STATE/term.$manager_term" "$TMP/manager.term.saved"
printf '%s\tblocked\n%s\tgone\n' "$lead_term" "$manager_term" >"$STATE/watch-mutations"
touch "$STATE/tsk-empty"
reset; out=$(CREW_WATCH_ONCE=1 CREW_WATCH_SECS=0 "$CREW" watch 2>&1)
rm -f "$STATE/tsk-empty"
cp "$TMP/manager.term.saved" "$STATE/term.$manager_term"
in_out "watch: reports blocked transition" "$S-lead blocked" "$out"
in_out "watch: reports removed terminal once" "$S-manager gone" "$out"
[[ $(printf '%s\n' "$out" | grep -c .) == 2 ]] && pass "watch: one transition and one gone line" || flunk "watch: unexpected event lines ($out)"
[[ $(hc_log -e '[.[] | select(.[0:2] == ["hc","ls"])] | length') == 2 ]] && pass "watch: one hc ls snapshot per poll" || flunk "watch: wrong hc ls call count"

# 8. lead re-run: delivers through hc and does not claim success before send.
reset; set_say_status "$lead_term" idle
out=$(echo "more work" | "$CREW" launch lead - 2>&1)
hc_log -e --arg terminal "$lead_term" --arg message "[from user] more work" '[.[] | select(. == ["hc","send",$terminal,$message])] | length == 1' >/dev/null \
  && pass "lead re-run: sends through hc exactly once" || flunk "lead re-run: message was not delivered through hc"
in_out "lead re-run: confirms delivery only after send" "sent to $S-lead" "$out"
[[ $(cnt 'space.new') == 0 && $(cnt 'tab.new') == 0 ]] && pass "lead re-run: no app tab created" || flunk "lead re-run: created an app tab"
reset; jq '.status = "idle" | .sendExit = 9' "$STATE/term.$lead_term" >"$STATE/term.$lead_term.tmp" && mv "$STATE/term.$lead_term.tmp" "$STATE/term.$lead_term"
out=$(echo "blocked rerun" | "$CREW" launch lead - 2>&1)
in_out "lead re-run blocked: reports person needed" "needs a person" "$out"
[[ "$out" != *"sent to $S-lead"* && "$out" != *"sent instructions to it"* ]] && pass "lead re-run blocked: no false success" || flunk "lead re-run blocked: reported false success"
[[ $(cnt '"send"') == 1 ]] && pass "lead re-run blocked: does not bypass exit 9" || flunk "lead re-run blocked: unexpected send count"

# 9. Trust handling moves to the hc readiness task.
reset; touch "$TMP/trust"
out=$(echo "fix trust" | "$CREW" launch driver - 2>&1)
[[ $(cnt 'agent start') == 0 ]] && pass "trust: no legacy agent start call" || flunk "trust: used legacy agent start"
rm -f "$TMP/trust"

# 10. outside legacy Herdr: reuse the named app space
reset
out=$(echo "reuse" | env -u HERDR_ENV "$CREW" launch driver - 2>&1)
space_id=$(jq -r '.id' "$STATE/space")
json_log --arg space "$space_id" -e 'any(.[]; .[0:3] == ["herdr-app","do","tab.new"] and (index("--space") as $i | .[$i+1] == $space))' >/dev/null \
  && pass "outside app: reuses the named crew space" || flunk "outside app: did not reuse the crew space"
[[ $(cnt 'space.new') == 0 ]] && pass "outside app: no second space" || flunk "outside app: created another space"

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
brief_of() { cat "$HOME/.herdr/crew/$S/$1.brief" 2>/dev/null || true; }
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

# 15. terminal labels recover the app space when CREW_WS is absent
reset
space_id=$(jq -r '.id' "$STATE/space")
terminal_id=""
for term_file in "$STATE"/term.*; do
  if jq -e --arg space "$space_id" '.labels["herdr.space"] == $space' "$term_file" >/dev/null 2>&1; then terminal_id=${term_file##*/term.}; fi
done
out=$(env -u CREW_WS HC_TERMINAL_ID="$terminal_id" "$CREW" team pair T7 "do it" 2>&1)
json_log --arg space "$space_id" -e 'any(.[]; .[0:3] == ["herdr-app","do","tab.new"] and (index("--space") as $i | .[$i+1] == $space))' >/dev/null \
  && pass "team fallback: app tab uses terminal label space" || flunk "team fallback: wrong app space"
grep -qF "[\"hc\",\"get\",\"$terminal_id\",\"--json\"]" "$LOG" \
  && pass "team fallback: checks HC_TERMINAL_ID label" || flunk "team fallback: did not inspect terminal label"
panes_ok "team fallback: every pane carries the resolved CREW_WS"

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
in_out "prompt: manager runs the review team" "herdr-crew team review T<n>" "$(cat "$(dirname "$CREW")/../agents/crew-manager/AGENTS.md")"
in_out "prompt: manager marks done after approval" "mark T<n> done" "$(cat "$(dirname "$CREW")/../agents/crew-manager/AGENTS.md")"
in_out "prompt: manager monitors through crew wait" 'herdr-crew wait <agent> --timeout 60' "$(cat "$(dirname "$CREW")/../agents/crew-manager/AGENTS.md")"
in_out "prompt: manager reads screen through crew read" 'herdr-crew read <agent> --lines 80' "$(cat "$(dirname "$CREW")/../agents/crew-manager/AGENTS.md")"
manager_agent=$(cat "$(dirname "$CREW")/../agents/crew-manager/agent.json")
jq -e '(.tools | index("Bash(herdr-crew read *)") != null) and (.tools | index("Bash(herdr-crew wait *)") != null) and ([.tools[] | select(startswith("Bash(herdr agent "))] | length == 0)' <<<"$manager_agent" >/dev/null \
  && pass "manager grants: use crew read/wait, no legacy agent commands" || flunk "manager grants: missing or stale tool grants"
in_out "prompt: reviewer approves with approve" '"approve"' "$(cat "$(dirname "$CREW")/../agents/code-reviewer/AGENTS.md")"
in_out "prompt: navigator verdict uses nav fix:" "nav fix:" "$(cat "$(dirname "$CREW")/../agents/navigator/AGENTS.md")"

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

# App-created agents retain their saved context hooks and native arguments.
reset
out=$(echo "budget check" | "$CREW" launch driver - 2>&1)
in_out "budget: app argv passes --settings" "--settings" "$(app_argv_text)"
in_out "budget: settings register a saved context hook" ".context-limit." "$(app_argv_text)"
[[ -f "$HOME/.herdr/crew/$S/$S-t7-driver.meta" ]] && pass "budget: meta file saved" || flunk "budget: no meta file"
[[ -f "$HOME/.herdr/crew/$S/$S-t7-driver.brief" ]] && pass "budget: brief file saved" || flunk "budget: no brief file"
in_out "budget: brief names the context budget" "Context budget" "$(cat "$HOME/.herdr/crew/$S/$S-t7-driver.brief")"

# handoff: stdin becomes the file, the task gets a step, and the manager is told
reset; set_say_status "$manager_term" idle
out=$(echo "Goal: fix login. Done: test written." | CREW_AGENT=$S-t7-driver CREW_TASK=T7 "$CREW" handoff "half done" 2>&1)
[[ -f "$HOME/.herdr/crew/$S/handoff-$S-t7-driver.md" ]] && pass "handoff: writes the handoff file" || flunk "handoff: no file"
in_log "handoff: step on the task" "tsk steps T7 add [handoff] $S-t7-driver: half done"
manager_term=$(sed -n 's/^terminal=//p' "$HOME/.herdr/crew/$S/$S-manager.meta")
hc_log -e --arg terminal "$manager_term" --arg message "[from $S-t7-driver] $S-t7-driver hit the context limit. Handoff: $HOME/.herdr/crew/$S/handoff-$S-t7-driver.md. Restart it: herdr-crew restart $S-t7-driver" 'any(.[]; . == ["hc","send",$terminal,$message])' >/dev/null \
  && pass "handoff: sends manager notification through hc" || flunk "handoff: manager was not notified"
reject "handoff: refuses with no body and no file" "no handoff at" "" handoff "x"

# restart: /exit, wait for the shell, start again with a readable handoff path
reset
out=$("$CREW" restart "$S-t7-driver" 2>&1)
in_log "restart: /exit the agent" "agent prompt $S-t7-driver /exit"
in_log "restart: starts the agent again" "agent start $S-t7-driver --pane"
in_out "restart: saved brief resumes from the handoff" "Resume from your handoff: $HOME/.herdr/crew/$S/handoff-$S-t7-driver.md" "$(cat "$HOME/.herdr/crew/$S/$S-t7-driver.brief")"
[[ -f "$HOME/.herdr/crew/$S/handoff-$S-t7-driver.md" ]] && pass "restart: handoff remains readable" || flunk "restart: handoff missing"

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
in_out "prompt: lead has the Monitor tool" "Monitor" "$(cat "$(dirname "$CREW")/../agents/crew-lead/AGENTS.md")"
in_out "prompt: lead monitors with herdr-crew watch" "herdr-crew watch" "$(cat "$(dirname "$CREW")/../agents/crew-lead/AGENTS.md")"
in_out "prompt: manager restarts a worker on handoff" "herdr-crew restart <agent>" "$(cat "$(dirname "$CREW")/../agents/crew-manager/AGENTS.md")"

# 19. Restart survives an agent that already exited.
reset; touch "$STATE/gone"
rc=0; out=$("$CREW" restart "$S-t7-driver" 2>&1) || rc=$?
(( rc == 0 )) && pass "restart gone: succeeds" || flunk "restart gone: rc=$rc"
in_log "restart gone: reaches start" "agent start $S-t7-driver"
rm -f "$STATE/gone" "$STATE/shell"

# 20. App terminals have no legacy name registry to clear.
! grep -qF 'clear_stale_name' "$ROOT/bin/crew" && pass "app terminals: no name registry cleanup" || flunk "app terminals: legacy name cleanup remains"

# 21. Existing branches are attached; retained worktrees are reused.
reset
out=$(BRANCH_EXISTS=1 "$CREW" team pair T7 "reuse branch" 2>&1)
in_log "pair branch: attached without -b" "worktree add $HOME/.herdr/worktrees/$S/T7-pair crew/T7-pair"
mkdir -p "$HOME/.herdr/worktrees/$S/T7-pair"
reset
out=$(BRANCH_EXISTS=1 "$CREW" team pair T7 "reuse worktree" 2>&1)
[[ $(cnt 'worktree add') == 0 ]] && pass "pair worktree: retained" || flunk "pair worktree: added again"
rmdir "$HOME/.herdr/worktrees/$S/T7-pair"

# 22. Visible pasted input gets one Enter; each first app brief uses hc send.
reset; echo idle >"$STATE/$S-t7-navigator"; rm -f "$STATE/entered"
paste_term=$(sed -n 's/^terminal=//p' "$HOME/.herdr/crew/$S/$S-t7-navigator.meta")
jq '.status = "idle" | .swallow = true' "$STATE/term.$paste_term" >"$STATE/term.$paste_term.tmp"
mv "$STATE/term.$paste_term.tmp" "$STATE/term.$paste_term"
out=$("$CREW" say "$S-t7-navigator" "paste me" 2>&1)
hc_log -e --arg term "$paste_term" 'any(.[]; . == ["hc","keys",$term,"enter"])' >/dev/null \
  && pass "paste: extra Enter after visible text" || flunk "paste: missing Enter retry"
hc_log -e --arg term "$paste_term" '[.[] | select(.[0:3] == ["hc","send",$term])] | length == 1' >/dev/null \
  && pass "paste: submitted once" || flunk "paste: duplicate prompt"
reset; touch "$STATE/ambiguous" "$STATE/quick-done"
out=$("$CREW" team pair T7 "brief awaits readiness" 2>&1)
[[ $(hc_log '[.[] | select(.[0:2] == ["hc","send"])] | length') == 2 ]] && pass "first app briefs use hc send" || flunk "first app briefs did not use hc send"
rm -f "$STATE/ambiguous" "$STATE/quick-done"

# 23. SessionStart restores exports in a fresh Claude shell environment.
reset
out=$("$CREW" team pair T7 "resume env" 2>&1)
app_settings >"$STATE/settings.json"
hook_cmd=$(jq -r '.hooks.SessionStart[0].hooks[0].command // empty' "$STATE/settings.json")
ENVFILE="$TMP/resumed.env"; : >"$ENVFILE"
if [[ -n "$hook_cmd" ]]; then
  env -u CREW_SLUG -u CREW_REPO -u CREW_AGENT -u CREW_TASK -u CREW_MANAGER -u CREW_WS CLAUDE_ENV_FILE="$ENVFILE" bash -c "$hook_cmd"
fi
restored=$(bash -c 'source "$1"; printf "%s|%s|%s|%s|%s|%s" "$CREW_SLUG" "$CREW_REPO" "$CREW_AGENT" "$CREW_TASK" "$CREW_MANAGER" "$CREW_WS"' _ "$ENVFILE")
space_id=$(jq -r '.id' "$STATE/space")
[[ "$restored" == "$S|$REPO|$S-t7-navigator|T7|$S-manager|$space_id" ]] && pass "resume: crew exports restored" || flunk "resume: exports missing ($restored)"

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
    in_out "investigate $spec: inspector starts" "--agent crew-inspector -n $S-t7-investigator" "$(app_argv_text)"
    json_log --arg folder "$REPO" -e 'any(.[]; .[0:3] == ["herdr-app","do","tab.new"] and (index("--folder") as $i | .[$i+1] == $folder))' >/dev/null \
      && pass "investigate $spec: repo cwd" || flunk "investigate $spec: wrong app folder"
    [[ $(app_agent_count) == 1 ]] && pass "investigate $spec: one worker" || flunk "investigate $spec: extra worker"
    [[ $(cnt 'worktree add') == 0 && $(cnt 'checkout') == 0 ]] && pass "investigate $spec: no worktree or checkout" || flunk "investigate $spec: git mutation"
    investigation_brief=$(brief_of "$S-t7-investigator")
    jq -e '.["crew-inspector"].prompt | contains("Investigation job.")' <<<"$(app_agents_json)" >/dev/null && pass "investigate $spec: persona loaded" || flunk "investigate $spec: persona missing"
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
  in_out "investigate domain: inspector retained" "--agent crew-inspector -n $S-t7-investigator" "$(app_argv_text)"
  [[ $(app_agent_count) == 1 && $(cnt 'worktree add') == 0 ]] && pass "investigate team: one worker, no worktree" || flunk "investigate team: extra worker or worktree"
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
    in_out "plan $spec: member rank" "--agent crew-member -n $S-t7-planner" "$(app_argv_text)"
    [[ $(app_agent_count) == 1 && $(cnt 'pane.split') == 0 ]] && pass "plan $spec: one worker" || flunk "plan $spec: extra worker"
    plan_brief=$(brief_of "$S-t7-planner")
    in_out "plan $spec: original request" "$plan_request" "$plan_brief"
    plan_guidance=$(jq -r '.["crew-member"].prompt' <<<"$(app_agents_json)")
    in_out "plan $spec: documentation scope" "Planning artifacts only" "$plan_guidance"
    in_out "plan $spec: contract pointer" "docs/planning/visual-plan-contract.md" "$plan_guidance"
    in_out "plan $spec: reports version" "plan ready:" "$plan_guidance"
    in_out "plan $spec: visual tooling" "lavish-axi" "$plan_brief"
    panes_ok "plan $spec: environment"
  fi
done
reset
rc=0; out=$("$CREW" team plan T7 "$plan_request" 2>&1) || rc=$?
(( rc == 0 )) && pass "plan team: existing task" || flunk "plan team: rc=$rc ($out)"
[[ $(cnt 'tsk add') == 0 ]] && pass "plan team: no duplicate task" || flunk "plan team: duplicate task"
reject "plan: wrong rank refused" "is a member job" "write plan" launch inspector@planner -
lead_rules=$(cat "$(dirname "$CREW")/../agents/crew-lead/AGENTS.md")
manager_rules=$(cat "$(dirname "$CREW")/../agents/crew-manager/AGENTS.md")
in_out "planning rules: Lead dispatch" "Run T<n> (plan)" "$lead_rules"
in_out "planning rules: approval evidence" "[plan approved]" "$lead_rules"
in_out "planning rules: revisions reopen" "reopen the same planning task" "$lead_rules"
in_out "planning rules: testing is not approval" "testing or simulation" "$lead_rules"
in_out "planning rules: standalone review" "standalone planner stays at review" "$manager_rules"
in_out "planning rules: draft completion" 'done "plan ready:' "$manager_rules"
in_out "planning rules: no implicit implementation" "Draft completion never authorizes implementation" "$manager_rules"
in_out "planning rules: handoff limitation" "known restart handoff-file race" "$lead_rules"
planner_rules=$(cat "$(dirname "$CREW")/../agents/planner/AGENTS.md")
in_out "planning source: checks live repo" 'git -C "$CREW_REPO" status --short' "$planner_rules"
in_out "planning source: blocks stale draft" "source drift" "$planner_rules"
in_out "planning source: checks before dispatch" "source drift" "$lead_rules"

# 27. Command-line UX: help, version, global options, readable status, completions
reset
rc=0; out=$("$CREW" --help 2>&1) || rc=$?
(( rc == 0 )) && pass "help: --help exits 0" || flunk "help: --help rc=$rc"
for want in USAGE COMMANDS "GLOBAL OPTIONS" EXAMPLES configure restart completion; do
  in_out "help: lists $want" "$want" "$out"
done
in_out "help: documents the global dry-run flag" "--dry-run" "$out"
rc=0; out=$("$CREW" help 2>&1) || rc=$?
(( rc == 0 )) && in_out "help: the help subcommand prints the same help" "GLOBAL OPTIONS" "$out" || flunk "help: help subcommand rc=$rc"
for c in configure launch team say read wait mark status close watch handoff restart completion; do
  rc=0; out=$("$CREW" help "$c" 2>&1) || rc=$?
  (( rc == 0 )) && in_out "help: help $c" "USAGE" "$out" || flunk "help: help $c rc=$rc"
  rc=0; out=$("$CREW" "$c" --help 2>&1) || rc=$?
  (( rc == 0 )) && in_out "help: $c --help" "USAGE" "$out" || flunk "help: $c --help rc=$rc"
done
rc=0; out=$("$CREW" --version 2>&1) || rc=$?
(( rc == 0 )) && [[ -n "$out" ]] && pass "version: --version exits 0 ($out)" || flunk "version: --version rc=$rc"
rc=0; out=$("$CREW" -V 2>&1) || rc=$?
(( rc == 0 )) && pass "version: -V exits 0" || flunk "version: -V rc=$rc"
# help and version must work on a machine with no tsk, herdr or jq at all.
# A stub on PATH proves nothing, because `command -v` still succeeds and the
# dependency check passes. This farm really lacks the three runtimes.
NORUN="$TMP/norun"; mkdir -p "$NORUN"
( IFS=:; for d in $PATH; do for f in "$d"/*; do b=${f##*/}; case "$b" in jq|tsk|herdr) ;; *) ln -s "$f" "$NORUN/$b" 2>/dev/null || true ;; esac; done; done )
norun_ok=0
# Bash may retain earlier command paths even when PATH is temporarily changed.
hash -r
for probe in jq tsk herdr; do PATH="$NORUN" command -v "$probe" >/dev/null || norun_ok=$((norun_ok + 1)); done
(( norun_ok == 3 )) && pass "no-runtime farm: jq, tsk and herdr are absent" || flunk "no-runtime farm: a runtime is still present"
for probe in "--help" "help" "help team" "launch --help" "configure --help"; do
  rc=0; out=$(env PATH="$NORUN" "$CREW" $probe 2>&1) || rc=$?
  (( rc == 0 )) && in_out "no-runtime: [$probe] prints help" "USAGE" "$out" || flunk "no-runtime: [$probe] rc=$rc, $out"
done
rc=0; out=$(env PATH="$NORUN" "$CREW" --version 2>&1) || rc=$?
(( rc == 0 )) && [[ -n "$out" ]] && pass "no-runtime: --version works ($out)" || flunk "no-runtime: --version rc=$rc, $out"
for shell in bash zsh; do
  rc=0; out=$(env PATH="$NORUN" "$CREW" completion "$shell" 2>&1) || rc=$?
  (( rc == 0 )) && in_out "no-runtime: completion $shell prints the script" "herdr-crew" "$out" || flunk "no-runtime: completion $shell rc=$rc, $out"
done
# a command that is not pure text still reports the missing runtime
rc=0; out=$(env PATH="$NORUN" "$CREW" status 2>&1) || rc=$?
(( rc != 0 )) && in_out "no-runtime: status still reports the missing jq" "jq not found" "$out" || flunk "no-runtime: status rc=$rc, $out"
reset
rc=0; out=$("$CREW" nope 2>&1) || rc=$?
(( rc != 0 )) && in_out "unknown command: names it" "unknown command 'nope'" "$out" || flunk "unknown command: rc=$rc"
in_out "unknown command: prints the help" "USAGE" "$out"
rc=0; out=$("$CREW" 2>&1) || rc=$?
(( rc == 1 )) && in_out "no command: prints the help and fails" "USAGE" "$out" || flunk "no command: rc=$rc"
rc=0; out=$("$CREW" help nope 2>&1) || rc=$?
(( rc != 0 )) && in_out "help: unknown command named" "unknown command 'nope'" "$out" || flunk "help: unknown command rc=$rc"

# status: task rows and agent states, no raw JSON dump; --json keeps the machine form
reset; printf '%s\n' review >"$STATE/tsk-seq"; echo working >"$STATE/$S-t7-driver"
out=$("$CREW" status 2>&1)
[[ "$out" != *'"number"'* ]] && pass "status: no raw JSON dump" || flunk "status: still dumps JSON"
in_out "status: task row" "T7"$'\t'"review"$'\t'"fix the login bug" "$out"
in_out "status: driver name and state" "$S-t7-driver"$'\t'"working" "$out"
out=$("$CREW" status --json 2>&1)
in_out "status --json: raw task JSON" '"number":7' "$out"

# the global --dry-run flag matches CREW_DRY_RUN=1
reset
out=$(echo "dry run flag" | "$CREW" --dry-run launch driver - 2>&1)
in_out "dry-run flag: prints the tsk call" "+ tsk add --title=dry run flag" "$out"
in_out "dry-run flag: reports the task" "created task T1" "$out"
in_out "dry-run flag: prints app tab creation" "+ herdr-app do tab.new" "$out"
[[ $(cnt 'agent start') == 0 ]] && pass "dry-run flag: starts no agent" || flunk "dry-run flag: started an agent"

# app topology dry-run prints planned argv and never writes agent metadata
mkdir -p "$TMP/dry-home" "$TMP/dry-state"
reset
out=$(echo "dry topology" | env HOME="$TMP/dry-home" STATE="$TMP/dry-state" LOG="$TMP/dry-log" CREW_SLUG=dry-run CREW_WS=w1 CREW_DRY_RUN=1 "$CREW" launch lead - 2>&1)
in_out "dry-run app: plans space creation" "+ herdr-app do space.new" "$out"
in_out "dry-run app: plans the manager split" "herdr-app do pane.split --direction right" "$out"
in_out "dry-run app: plans the tsk split" "herdr-app do pane.split --direction down" "$out"
in_out "dry-run app: argv carries crew environment" 'CREW_WS=sp-dry' "$out"
[[ ! -e "$TMP/dry-home/.herdr/crew/dry-run/dry-run-lead.meta" ]] && pass "dry-run app: writes no agent meta" || flunk "dry-run app: wrote agent meta"

# completions
rc=0; out=$("$CREW" completion bash 2>&1) || rc=$?
(( rc == 0 )) && in_out "completion: bash names the commands" "herdr-crew" "$out" || flunk "completion: bash rc=$rc"
in_out "completion: bash includes read and wait" "say read wait mark" "$out"
rc=0; out=$("$CREW" completion zsh 2>&1) || rc=$?
(( rc == 0 )) && in_out "completion: zsh uses compdef" "#compdef" "$out" || flunk "completion: zsh rc=$rc"
in_out "completion: zsh includes read and wait" "say read wait mark" "$out"
rc=0; out=$("$CREW" completion fish 2>&1) || rc=$?
(( rc != 0 )) && pass "completion: unknown shell refused" || flunk "completion: accepted fish"
rc=0; out=$("$CREW" completion 2>&1) || rc=$?
(( rc != 0 )) && in_out "completion: missing shell refused" "completion <bash|zsh>" "$out" || flunk "completion: missing shell rc=$rc"

# 28. Core/app fake runtime contract. Keep these binaries outside PATH; call them directly.
  RFAKE="$TMP/runtime-fake"; RSTATE="$TMP/runtime-state"
  mkdir -p "$RFAKE" "$RSTATE"
  reset
  install_fake_runtime "$RFAKE" "$RSTATE"
  argv='["env","CREW_AGENT=lead","claude"]'
  out=$("$RFAKE/herdr-app" do space.new --name crew-fixture --folder "$TMP" --tab lead --argv "$argv")
  in_out "runtime fake: space.new returns IDs" '"space":"sp1"' "$out"
  in_out "runtime fake: space.new returns tab and terminal IDs" '"tab":"tb1"' "$out"
  in_out "runtime fake: space.new returns terminal ID" '"terminal":"t1"' "$out"
  space=$(jq -r '.space' <<<"$out"); root_tab=$(jq -r '.tab' <<<"$out"); root_term=$(jq -r '.terminal' <<<"$out")
  out=$("$RFAKE/herdr-app" do tab.new --space "$space" --name worker --folder "$TMP" --argv "$argv")
  in_out "runtime fake: tab.new returns IDs without pane" '"tab":"tb2"' "$out"
  worker_tab=$(jq -r '.tab' <<<"$out")
  root_pane=$("$RFAKE/herdr-app" ls | jq -r --arg tab "$root_tab" '.spaces[0].tabs[] | select(.id == $tab) | .terminals[0].pane')
  jq -e --arg space "$space" --arg tab "$root_tab" --arg term "$root_term" '.spaces[0].id == $space and .spaces[0].tabs[0].id == $tab and .spaces[0].tabs[0].terminals[0].terminal == $term' <<<"$("$RFAKE/herdr-app" ls)" >/dev/null \
    && pass "runtime fake: app ls lists space, tab and terminal" || flunk "runtime fake: app ls listing"
  out=$("$RFAKE/herdr-app" do pane.split --direction right --pane "$root_pane" --argv "$argv")
  in_out "runtime fake: pane.split returns IDs" '"pane":"p3"' "$out"
  split_term=$(jq -r '.terminal' <<<"$out")
  out=$("$RFAKE/hc" get "$split_term" --json)
  in_out "runtime fake: hc get returns terminal object" '"address":"t3"' "$out"
  in_out "runtime fake: hc get keeps null status" '"status":null' "$out"
  jq -e --arg term "$root_term" --argjson argv "$argv" '.address == $term and .argv == $argv and (.labels | type == "object") and has("pid")' <<<"$("$RFAKE/hc" get "$root_term" --json)" >/dev/null \
    && pass "runtime fake: hc get exposes argv, labels and pid" || flunk "runtime fake: hc get terminal fields"
  jq -e --arg term "$split_term" '.terminals | any(.address == $term and .status == null)' <<<"$("$RFAKE/hc" ls --json)" >/dev/null \
    && pass "runtime fake: hc ls lists terminal status" || flunk "runtime fake: hc ls listing"
  printf 'fixture screen\n' >"$RSTATE/screen.$split_term"
  out=$("$RFAKE/hc" read "$split_term" --lines 2)
  in_out "runtime fake: hc read returns screen text" "fixture screen" "$out"
  "$RFAKE/hc" keys "$split_term" down enter
  "$RFAKE/hc" wait "$split_term" >/dev/null
  "$RFAKE/hc" label "$split_term" crew.task=T7
  jq -e '.labels["crew.task"] == "T7"' <<<"$("$RFAKE/hc" get "$split_term" --json)" >/dev/null \
    && pass "runtime fake: keys, wait and label are controllable" || flunk "runtime fake: keys, wait or label"
  jq --argjson status '"blocked"' '.status = $status' "$RSTATE/term.$split_term" >"$RSTATE/term.$split_term.tmp"
  mv "$RSTATE/term.$split_term.tmp" "$RSTATE/term.$split_term"
  rc=0; out=$("$RFAKE/hc" send "$split_term" "blocked message" 2>&1) || rc=$?
  (( rc == 9 )) && in_out "runtime fake: blocked send exits 9" '"kind":"blocked"' "$out" || flunk "runtime fake: blocked send rc=$rc ($out)"
  rc=0; out=$("$RFAKE/hc" send missing "missing message" 2>&1) || rc=$?
  (( rc == 3 )) && pass "runtime fake: missing send exits 3" || flunk "runtime fake: missing send rc=$rc ($out)"
  "$RFAKE/hc" kill "$split_term"
  jq -e '.state == "finished"' <<<"$("$RFAKE/hc" get "$split_term" --json)" >/dev/null \
    && pass "runtime fake: kill marks terminal finished" || flunk "runtime fake: kill state"
  out=$("$RFAKE/herdr-app" do tab.rename --id "$worker_tab" --name worker-renamed)
  in_out "runtime fake: tab.rename succeeds" '"ok":true' "$out"
  jq -e --arg tab "$worker_tab" 'any(.spaces[0].tabs[]; .id == $tab and .name == "worker-renamed")' "$RSTATE/ls.json" >/dev/null \
    && pass "runtime fake: renamed tab updates listing" || flunk "runtime fake: tab rename listing"
  out=$("$RFAKE/herdr-app" do tab.close --id "$worker_tab" --confirmed true)
  in_out "runtime fake: tab.close succeeds" '"ok":true' "$out"
  jq -e --arg tab "$worker_tab" 'all(.spaces[0].tabs[]; .id != $tab)' "$RSTATE/ls.json" >/dev/null \
    && pass "runtime fake: closed tab leaves listing" || flunk "runtime fake: closed tab remains listed"
  jq -s -e --arg folder "$TMP" --arg argv "$argv" 'any(.[]; . == ["herdr-app","do","space.new","--name","crew-fixture","--folder",$folder,"--tab","lead","--argv",$argv])' "$LOG" >/dev/null \
    && pass "runtime fake: logs app argv including JSON argv" || flunk "runtime fake: app argv log missing"
  jq -s -e --arg pane "$root_pane" --arg argv "$argv" 'any(.[]; . == ["herdr-app","do","pane.split","--direction","right","--pane",$pane,"--argv",$argv])' "$LOG" >/dev/null \
    && pass "runtime fake: logs split argv exactly" || flunk "runtime fake: split argv log missing"

  # 29. New agent briefs wait for readiness, trust only the recognized dialog, and use hc send safely.
  READY_STATE="$TMP/readiness-state"; READY_HOME="$TMP/readiness-home"; READY_LOG="$TMP/readiness-log"
  ready_reset() {
    rm -rf "$READY_STATE" "$READY_HOME"
    mkdir -p "$READY_STATE" "$READY_HOME"
    : >"$READY_LOG"
    touch "$READY_STATE/auto-ready"
  }
  run_ready() {
    env HOME="$READY_HOME" STATE="$READY_STATE" LOG="$READY_LOG" CREW_REPO="$REPO" CREW_SLUG=readiness CREW_WS=w1 "$CREW" "$@"
  }
  ready_meta="$READY_HOME/.herdr/crew/readiness/readiness-t7-investigator.meta"

  ready_reset
  printf 'null\nidle\n' >"$READY_STATE/status-sequence-on-create"
  rc=0; out=$(run_ready team investigate T7 "wait for readiness" 2>&1) || rc=$?
  (( rc == 0 )) && pass "readiness: null then idle allows first brief" || flunk "readiness: null then idle rc=$rc ($out)"
  jq -s -e '([.[] | select(.[0:3] == ["hc","get","t1"])] | length) == 4 and ([.[] | select(.[0:3] == ["hc","read","t1"] and .[3:] == ["--lines","40"])] | length) == 1' "$READY_LOG" >/dev/null \
    && pass "readiness: polls null then idle and reads screen" || flunk "readiness: expected status/read sequence"
  jq -s -e '[.[] | select(.[0:2] == ["hc","send"])] | length == 1 and .[0][2] == "t1"' "$READY_LOG" >/dev/null \
    && pass "readiness: sends one first brief" || flunk "readiness: first brief send count/terminal"
  grep -q '^rank=inspector$' "$ready_meta" && grep -q '^job=investigator$' "$ready_meta" \
    && [[ -s "$READY_HOME/.herdr/crew/readiness/readiness-t7-investigator.brief" && -s "$READY_HOME/.herdr/crew/readiness/readiness-t7-investigator.definition" ]] \
    && pass "readiness: saves full agent state after readiness" || flunk "readiness: saved state missing"

  ready_reset
  printf '%s\n' 'Claude asks: trust this folder?' >"$READY_STATE/screen-on-create"
  rc=0; out=$(run_ready team investigate T7 "trust then send" 2>&1) || rc=$?
  (( rc == 0 )) && pass "trust: recognized dialog allows launch" || flunk "trust: launch rc=$rc ($out)"
  jq -s -e '([to_entries[] | select(.value == ["hc","keys","t1","down","enter"]) | .key][0]) < ([to_entries[] | select(.value[0:2] == ["hc","send"]) | .key][0])' "$READY_LOG" >/dev/null \
    && pass "trust: answers only named folder prompt before send" || flunk "trust: keys did not precede send"

  ready_reset
  printf '%s\n' blocked >"$READY_STATE/status-on-create"
  mkdir -p "$(dirname "$ready_meta")"; printf 'old meta\n' >"$ready_meta"
  rc=0; out=$(run_ready team investigate T7 "must not send" 2>&1) || rc=$?
  (( rc != 0 )) && [[ $(jq -s '[.[] | select(.[0:2] == ["hc","send"])] | length' "$READY_LOG") == 0 ]] \
    && grep -q '^old meta$' "$ready_meta" \
    && pass "readiness: blocked returns failure without send or replacing meta" || flunk "readiness: blocked rc=$rc, output=$out"

  ready_reset
  printf '9\n' >"$READY_STATE/send-exit-on-create"
  rc=0; out=$(run_ready team investigate T7 "blocked send" 2>&1) || rc=$?
  (( rc != 0 )) && in_out "send: exit 9 warns and fails launch" "needs a person" "$out" || flunk "send: exit 9 rc=$rc ($out)"
  [[ ! -e "$READY_STATE/sent.t1" ]] && pass "send: exit 9 leaves message unsent" || flunk "send: exit 9 recorded a sent message"

  ready_reset
  printf '3\n' >"$READY_STATE/send-exit-on-create"
  rc=0; out=$(run_ready team investigate T7 "gone terminal" 2>&1) || rc=$?
  (( rc != 0 )) && in_out "send: exit 3 fails launch" "terminal t1 is gone" "$out" || flunk "send: exit 3 rc=$rc ($out)"

  ready_reset
  touch "$READY_STATE/keep-turn-on-create"
  rc=0; out=$(run_ready team investigate T7 "working status is sufficient" 2>&1) || rc=$?
  if (( rc == 0 )) && [[ "$out" != *"did not start after brief submission"* ]] \
    && [[ -s "$READY_STATE/sent.t1" ]] \
    && jq -e '.status == "working" and .turn == 0' "$READY_STATE/term.t1" >/dev/null; then
    pass "send: working status succeeds without a turn change"
  else
    flunk "send: working without turn change rc=$rc ($out)"
  fi

  ready_reset
  touch "$READY_STATE/swallow-send-on-create"
  rc=0; out=$(run_ready team investigate T7 "retry Enter" 2>&1) || rc=$?
  (( rc == 0 )) && pass "paste: swallowed Enter recovers first brief" || flunk "paste: launch rc=$rc ($out)"
  jq -s -e '[.[] | select(. == ["hc","keys","t1","enter"])] | length == 1' "$READY_LOG" >/dev/null \
    && pass "paste: retries Enter once after visible first line" || flunk "paste: Enter retry missing or duplicated"

echo
if (( fails == 0 )); then echo "ALL PASS"; else echo "$fails FAILED"; exit 1; fi
