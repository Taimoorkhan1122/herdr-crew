#!/usr/bin/env bash
source "$(cd "$(dirname "$0")/.." && pwd)/test/fixtures/launcher-setup.sh"
set +e
fail=0
check() { if "$@"; then echo "PASS: $label"; else echo "FAIL: $label"; fail=$((fail+1)); fi; }
reset_case() {
  HOME="$TMP/case-$1"; STATE="$TMP/state-$1"; LOG="$TMP/log-$1"; export HOME STATE LOG
  mkdir -p "$HOME" "$STATE"; : >"$LOG"; touch "$STATE/auto-ready"
  export CREW_REPO="$REPO" CREW_SLUG="case-$1" CREW_WS=w1
  unset HERDR_WORKSPACE_ID HC_TERMINAL_ID
}
reset_case finishedlead
"$CREW" launch lead first >/dev/null 2>&1; first_rc=$?
lead_meta="$HOME/.herdr/crew/$CREW_SLUG/$CREW_SLUG-lead.meta"
old_lead=$(sed -n 's/^terminal=//p' "$lead_meta")
"$FAKE/hc" kill "$old_lead" >/dev/null
: >"$LOG"
out=$("$CREW" launch lead second 2>&1); rc=$?
new_lead=$(sed -n 's/^terminal=//p' "$lead_meta")
label='finished lead relaunches in a new tab without saying to old lead'; check bash -c '[[ $1 == 0 && $2 == 0 && -n "$3" && "$3" != "$4" ]] && jq -se --arg old "$4" '\''([.[] | select(.[0:3] == ["herdr-app","do","tab.new"])] | length) == 1 and ([.[] | select(.[0:3] == ["hc","send",$old])] | length) == 0'\'' "$5" >/dev/null' _ "$first_rc" "$rc" "$new_lead" "$old_lead" "$LOG"
reset_case leadspace
"$CREW" launch lead first >/dev/null 2>&1; rc=$?
space=$(jq -r .id "$STATE/space")
label='first lead gets real space in initial argv without bootstrap terminal'; check bash -c '[[ $1 == 0 ]] && jq -e --arg space "$2" '\''.argv | index("CREW_WS=" + $space) != null'\'' "$3/term.t1" >/dev/null && jq -se '\''([.[] | select(.[0:3] == ["herdr-app","do","space.new"] and (index("--tab") == null) and (index("--argv") == null))] | length) == 1 and ([.[] | select(.[0:3] == ["herdr-app","do","tab.new"])] | length) == 1'\'' "$4" >/dev/null && [[ $(find "$3" -name "term.*" -type f | wc -l | tr -d " ") == 3 ]]' _ "$rc" "$space" "$STATE" "$LOG"
reset_case teamspace
"$CREW" team investigate T7 first >/dev/null 2>&1; rc=$?
space=$(jq -r .id "$STATE/space")
label='first team member gets real space in initial argv without bootstrap terminal'; check bash -c '[[ $1 == 0 ]] && jq -e --arg space "$2" '\''.argv | index("CREW_WS=" + $space) != null'\'' "$3/term.t1" >/dev/null && jq -se '\''([.[] | select(.[0:3] == ["herdr-app","do","space.new"] and (index("--tab") == null) and (index("--argv") == null))] | length) == 1 and ([.[] | select(.[0:3] == ["herdr-app","do","tab.new"])] | length) == 1'\'' "$4" >/dev/null && [[ $(find "$3" -name "term.*" -type f | wc -l | tr -d " ") == 1 ]]' _ "$rc" "$space" "$STATE" "$LOG"
reset_case coexist
export BRANCH_EXISTS=1
"$CREW" team pair T7 first >/dev/null 2>&1; pair_rc=$?
driver_meta="$HOME/.herdr/crew/$CREW_SLUG/$CREW_SLUG-t7-driver.meta"
navigator_meta="$HOME/.herdr/crew/$CREW_SLUG/$CREW_SLUG-t7-navigator.meta"
cp "$driver_meta" "$TMP/pair-driver.meta"; cp "$navigator_meta" "$TMP/pair-navigator.meta"
: >"$LOG"
out=$("$CREW" team review T7 review 2>&1); review_rc=$?
review_meta="$HOME/.herdr/crew/$CREW_SLUG/$CREW_SLUG-t7-code-reviewer.meta"
label='live pair and review coexist with only reviewer created'; check bash -c '[[ $1 == 0 && $2 == 0 && -s "$3" ]] && cmp -s "$4" "$5" && cmp -s "$6" "$7" && sed -n '\''/^\["herdr-app"/p'\'' "$8" | jq -se '\''([.[] | select(.[0:3] == ["herdr-app","do","tab.new"])] | length) == 1 and ([.[] | select(.[0:3] == ["herdr-app","do","pane.split"])] | length) == 0'\'' >/dev/null' _ "$pair_rc" "$review_rc" "$review_meta" "$driver_meta" "$TMP/pair-driver.meta" "$navigator_meta" "$TMP/pair-navigator.meta" "$LOG"
: >"$LOG"
out=$("$CREW" team pair T7 again 2>&1); rc=$?
label='repeated pair refuses and preserves both bindings'; check bash -c '[[ $1 != 0 && "$2" == *"already running"* ]] && cmp -s "$3" "$4" && cmp -s "$5" "$6" && ! rg -q "(tab.new|space.new|pane.split|worktree add)" "$7"' _ "$rc" "$out" "$driver_meta" "$TMP/pair-driver.meta" "$navigator_meta" "$TMP/pair-navigator.meta" "$LOG"
unset BRANCH_EXISTS
reset_case duplicate
"$CREW" team investigate T7 first >/dev/null 2>&1
meta="$HOME/.herdr/crew/$CREW_SLUG/$CREW_SLUG-t7-investigator.meta"
cp "$meta" "$TMP/original.meta"; : >"$LOG"
out=$("$CREW" team investigate T7 again 2>&1); rc=$?
label='duplicate launch refuses and preserves live binding'; check bash -c '[[ $1 != 0 && "$2" == *"already running"* ]] && cmp -s "$3" "$4" && ! rg -q "(tab.new|space.new|pane.split|worktree add)" "$5"' _ "$rc" "$out" "$meta" "$TMP/original.meta" "$LOG"
reset_case rejection
"$CREW" team investigate T7 first >/dev/null 2>&1
meta="$HOME/.herdr/crew/$CREW_SLUG/$CREW_SLUG-t7-investigator.meta"
cp "$meta" "$TMP/original.meta"; cp "${meta%.meta}.cmd" "$TMP/original.cmd"
cp "${meta%.meta}.brief" "$TMP/original.brief"; cp "${meta%.meta}.definition" "$TMP/original.definition"
jq '.state="finished"' "$STATE/term.t1" >"$STATE/new"; mv "$STATE/new" "$STATE/term.t1"
printf '9\n' >"$STATE/send-exit-on-create"
"$CREW" team investigate T7 rejected >/dev/null 2>&1; rc=$?
label='rejected first brief preserves old state'; check bash -c '[[ $1 != 0 ]] && cmp -s "$2" "$3" && cmp -s "$4" "$5" && cmp -s "$6" "$7" && cmp -s "$8" "$9"' _ "$rc" "$meta" "$TMP/original.meta" "${meta%.meta}.cmd" "$TMP/original.cmd" "${meta%.meta}.brief" "$TMP/original.brief" "${meta%.meta}.definition" "$TMP/original.definition"
reset_case dry
"$CREW" team investigate T7 first >/dev/null 2>&1
meta="$HOME/.herdr/crew/$CREW_SLUG/$CREW_SLUG-t7-investigator.meta"; cp "$STATE/term.t1" "$TMP/original.term"; : >"$LOG"
out=$("$CREW" --dry-run restart "$CREW_SLUG-t7-investigator" 2>&1); rc=$?
label='dry restart prints plan without hc or terminal changes'; check bash -c '[[ $1 == 0 && "$2" == *"+ hc send t1 /exit"* ]] && ! rg -q '\''"hc"'\'' "$3" && cmp -s "$4" "$5"' _ "$rc" "$out" "$LOG" "$STATE/term.t1" "$TMP/original.term"
reset_case blocked
"$CREW" team investigate T7 first >/dev/null 2>&1
jq '.swallow=true' "$STATE/term.t1" >"$STATE/new"; mv "$STATE/new" "$STATE/term.t1"
printf '%s\n' idle idle blocked blocked blocked blocked blocked blocked blocked blocked blocked >"$STATE/get-seq.t1"; : >"$LOG"
out=$("$CREW" say "$CREW_SLUG-t7-investigator" hello 2>&1)
label='blocked after send warns and never presses enter'; check bash -c '[[ "$1" == *"needs a person"* ]] && ! rg -q '\''"keys"'\'' "$2"' _ "$out" "$LOG"
reset_case bootstrap
unset CREW_WS
"$CREW" team investigate T7 first >/dev/null 2>&1
space=$(jq -r .id "$STATE/space"); expected_tab=$(jq -r '.spaces[0].tabs[0].id' "$STATE/ls.json"); : >"$LOG"
out=$(HC_TERMINAL_ID=t1 "$CREW" close T7 investigate 2>&1); rc=$?
label='close resolves caller terminal space'; check bash -c '[[ $1 == 0 ]] && jq -se '\''any(.[]; .[0:3] == ["herdr-app","do","tab.close"])'\'' "$2" >/dev/null' _ "$rc" "$LOG"
reset_case board
"$CREW" launch lead board >/dev/null 2>&1
space=$(jq -r .id "$STATE/space")
label='board receives resolved crew environment'; check jq -se --arg space "$space" 'any(.[]; .[0:3] == ["herdr-app","do","pane.split"] and (.[-1] | fromjson | . as $a | .[0] == "env" and index("CREW_WS=" + $space) != null and index("tsk") != null and (all(["CREW_SLUG=", "CREW_TASK=", "CREW_AGENT=", "CREW_MANAGER=", "CREW_REPO=", "CREW_CTX_LIMIT="][]; . as $prefix | any($a[]; startswith($prefix))))))' "$LOG"
printf '%s failure(s)\n' "$fail"
(( fail == 0 ))
