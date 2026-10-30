#!/bin/bash
# Project-agent launch regressions. All integrations are fake and Git is disposable.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
CREW="$ROOT/bin/crew"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/crew-launch.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home" "$TMP/project with spaces/.herdr-crew" "$TMP/fake" "$TMP/panes"
export HOME="$TMP/home" LOG="$TMP/calls.jsonl" PANE_ENV_DIR="$TMP/panes"
export CREW_REPO="$TMP/project with spaces" CREW_SLUG=fixture HERDR_ENV=1 CREW_WS=w1
unset CREW_DRY_RUN CREW_AGENT CREW_TASK CREW_MANAGER
: > "$LOG"
git -C "$CREW_REPO" init -q || exit 1
git -C "$CREW_REPO" -c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty -qm initial || exit 1
cp -R "$ROOT/agents" "$CREW_REPO/.herdr-crew/agents" || exit 1
cp -R "$ROOT/personas" "$CREW_REPO/.herdr-crew/personas" || exit 1
cp -R "$ROOT/teams" "$CREW_REPO/.herdr-crew/teams" || exit 1
cp -R "$ROOT/hooks" "$CREW_REPO/.herdr-crew/hooks" || exit 1
mkdir "$CREW_REPO/.herdr-crew/agents/payments-reviewer"
printf '%s\n' 'CUSTOM PAYMENT REVIEW ORIGINAL' > "$CREW_REPO/.herdr-crew/agents/payments-reviewer/AGENTS.md"
printf '%s\n' '{"name":"payments-reviewer","description":"Review payments","profile":"inspector"}' > "$CREW_REPO/.herdr-crew/agents/payments-reviewer/agent.json"
printf '%s\n' 'members=inspector@payments-reviewer' 'worktree=none' > "$CREW_REPO/.herdr-crew/teams/payments.conf"
printf '%s\n' '{"version":1,"roles":{}}' > "$CREW_REPO/.herdr-crew/config.json"
cat > "$TMP/fake/herdr" <<'SH'
#!/bin/bash
jq -nc --args '$ARGS.positional' -- "$@" >> "$LOG"
case "$1 $2" in
  'tab create') jq -nc --args '$ARGS.positional' -- "$@" > "$PANE_ENV_DIR/p1"; echo '{"result":{"root_pane":{"pane_id":"w1:p1"}}}' ;;
  'pane split') jq -nc --args '$ARGS.positional' -- "$@" > "$PANE_ENV_DIR/p2"; echo '{"result":{"pane":{"pane_id":"w1:p2"}}}' ;;
  'agent get') exit 1 ;;
  'pane process-info') echo '{"result":{"process_info":{"foreground_process_group_id":1,"shell_pid":1}}}' ;;
  'agent start')
    if [[ -f "$PANE_ENV_DIR/p1" ]]; then
      policy=$(jq -c '[.[] | select(startswith("OPENCODE_CONFIG_CONTENT=")) | sub("^OPENCODE_CONFIG_CONTENT=";"") | fromjson][0] // {}' "$PANE_ENV_DIR/p1")
      jq -nc --argjson policy "$policy" '["effective-policy",$policy]' >> "$LOG"
    fi ;;
  *) exit 0 ;;
esac
SH
cat > "$TMP/fake/tsk" <<'SH'
#!/bin/bash
jq -nc --args '$ARGS.positional' -- tsk "$@" >> "$LOG"
echo '[{"number":7,"notes":"inspect payments"}]'
SH
cat > "$TMP/fake/claude" <<'SH'
#!/bin/bash
[[ "${1:-}" != --version ]] || echo '2.1.312 (Claude Code)'
exit 0
SH
cat > "$TMP/fake/opencode" <<'SH'
#!/bin/bash
[[ "${1:-}" != --version ]] || echo 'opencode v2.1.2'
exit 0
SH
chmod +x "$TMP/fake/"*
export PATH="$TMP/fake:$PATH"
cd "$CREW_REPO" || exit 1
fails=0
check() { if "$@"; then printf 'PASS: %s\n' "$label"; else printf 'FAIL: %s (rc=%s; %s)\n' "$label" "$rc" "$out"; fails=$((fails+1)); fi; }
run() { : > "$LOG"; rc=0; out=$("$CREW" "$@" 2>&1) || rc=$?; }
claude_policy() {
  [[ "$rc" == 0 ]] || return 1
  jq -s -e '[.[] | select(.[0:2] == ["agent","start"]) | . as $call | ($call|index("--agents")) as $i | select($i != null) | $call[$i+1] | fromjson | to_entries[] | .value | select((.prompt | contains("CUSTOM PAYMENT REVIEW ORIGINAL")) and (.tools | index("Write") | not) and (.disallowedTools | index("Write")))] | length > 0' "$LOG" >/dev/null
}
label='Claude project inspector uses selected guidance and native read-only policy'
run team payments T7 'inspect payments'
check claude_policy
printf '%s\n' 'CUSTOM PAYMENT REVIEW CHANGED' > "$CREW_REPO/.herdr-crew/agents/payments-reviewer/AGENTS.md"
label='Claude restart keeps original inspector definition'
run restart fixture-t7-payments-reviewer
check claude_policy
cp "$HOME/.herdr/crew/fixture/fixture-t7-payments-reviewer.definition" "$TMP/saved-definition" 2>/dev/null || :
rm -f "$HOME/.herdr/crew/fixture/fixture-t7-payments-reviewer.definition"
label='restart refuses missing snapshot before stopping the agent'
run restart fixture-t7-payments-reviewer
check bash -c '[[ "$1" != 0 ]] && ! jq -se '\''any(.[]; .[0:2] == ["agent","prompt"] and .[3] == "/exit")'\'' "$2" >/dev/null' _ "$rc" "$LOG"
printf '%s\n' 'not-json' > "$HOME/.herdr/crew/fixture/fixture-t7-payments-reviewer.definition"
label='restart refuses malformed snapshot before stopping the agent'
run restart fixture-t7-payments-reviewer
check bash -c '[[ "$1" != 0 ]] && ! jq -se '\''any(.[]; .[0:2] == ["agent","prompt"] and .[3] == "/exit")'\'' "$2" >/dev/null' _ "$rc" "$LOG"
[[ ! -f "$TMP/saved-definition" ]] || cp "$TMP/saved-definition" "$HOME/.herdr/crew/fixture/fixture-t7-payments-reviewer.definition"
printf '%s\n' 'CUSTOM PAYMENT REVIEW ORIGINAL' > "$CREW_REPO/.herdr-crew/agents/payments-reviewer/AGENTS.md"
# Invalid later slot must fail before task, workspace, pane or Git worktree mutation.
printf '%s\n' 'members=member@driver inspector@missing-reviewer' 'worktree=new' > "$CREW_REPO/.herdr-crew/teams/bad.conf"
label='invalid later slot fails before resources'
run team bad T8 'must refuse'
check bash -c '[[ "$1" != 0 && "$4" == *"missing-reviewer"* ]] && ! jq -se '\''any(.[]; (.[0] == "tsk") or (.[0:2] == ["tab","create"]) or (.[0:2] == ["pane","split"]) or (.[0:2] == ["agent","start"]))'\'' "$2" >/dev/null && [[ ! -e "$3/.herdr/worktrees/fixture/T8-bad" ]]' _ "$rc" "$LOG" "$HOME" "$out"
printf '%s\n' 'members=inspector@payments-reviewer' 'worktree=none' > "$CREW_REPO/.herdr-crew/outside.conf"
label='team traversal is rejected before resources'
run team ../outside T8 'must refuse'
check bash -c '[[ "$1" != 0 ]] && ! jq -se '\''any(.[]; (.[0] == "tsk") or (.[0:2] == ["tab","create"]) or (.[0:2] == ["agent","start"]))'\'' "$2" >/dev/null' _ "$rc" "$LOG"
# Configuring OpenCode is fixture data, not a provider request.
printf '%s\n' '{"version":1,"roles":{"payments-reviewer":{"agent":"opencode","model":"provider/reviewer"}}}' > "$CREW_REPO/.herdr-crew/config.json"
label='OpenCode project inspector has selected guidance and native deny policy'
run team payments T9 'inspect payments'
check bash -c '[[ "$1" == 0 ]] && jq -se '\''[.[][] | select(type == "string" and startswith("OPENCODE_CONFIG_CONTENT=")) | sub("^OPENCODE_CONFIG_CONTENT=";"") | fromjson | .agents.crew | select((.system | contains("CUSTOM PAYMENT REVIEW ORIGINAL")) and .permissions[0] == {action:"*",resource:"*",effect:"deny"} and (any(.permissions[]; .action == "edit" and .effect == "allow")|not) and (any(.permissions[]; .action == "subagent" and .effect == "allow")|not))] | length > 0'\'' "$2" >/dev/null' _ "$rc" "$LOG"
jq -cs '[.[]|select(.[0] == "effective-policy")|.[1]][0] // {}' "$LOG" > "$TMP/original-policy"
# Restart must use the saved definition and native policy, not edited files.
printf '%s\n' 'CUSTOM PAYMENT REVIEW CHANGED' > "$CREW_REPO/.herdr-crew/agents/payments-reviewer/AGENTS.md"
label='restart retains original inspector guidance and native policy after project edit'
run restart fixture-t9-payments-reviewer
check bash -c '[[ "$1" == 0 ]] && jq -se --slurpfile original "$3" '\''any(.[]; .[0] == "effective-policy" and .[1] == $original[0] and (.[1].agents.crew.system | contains("CUSTOM PAYMENT REVIEW ORIGINAL")))'\'' "$2" >/dev/null && ! jq -se '\''any(.[]; .[0:2] == ["agent","prompt"] and any(.[]; type == "string" and contains("CUSTOM PAYMENT REVIEW CHANGED")))'\'' "$2" >/dev/null' _ "$rc" "$LOG" "$TMP/original-policy"
label='fresh launch uses changed project inspector guidance'
run team payments T10 'inspect payments again'
check bash -c '[[ "$1" == 0 ]] && jq -se '\''any(.[]; .[0] == "effective-policy" and (.[1].agents.crew.system | contains("CUSTOM PAYMENT REVIEW CHANGED")))'\'' "$2" >/dev/null' _ "$rc" "$LOG"
(( fails == 0 )) || { printf '%s checks failed\n' "$fails"; exit 1; }
printf 'ALL PASS\n'
