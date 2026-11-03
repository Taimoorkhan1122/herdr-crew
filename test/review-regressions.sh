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
