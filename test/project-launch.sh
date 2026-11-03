#!/bin/bash
# Project-agent launch regressions. All integrations are fake and Git is disposable.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
CREW="$ROOT/bin/crew"
source "$ROOT/test/fixtures/fake-runtime.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/crew-launch.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home" "$TMP/project with spaces/.herdr-crew" "$TMP/fake" "$TMP/panes" "$TMP/state"
export HOME="$TMP/home" LOG="$TMP/calls.jsonl" PANE_ENV_DIR="$TMP/panes" STATE="$TMP/state"
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
install_fake_runtime "$TMP/fake" "$STATE"
touch "$STATE/auto-ready"
export PATH="$TMP/fake:$PATH"
cd "$CREW_REPO" || exit 1
fails=0
check() { if "$@"; then printf 'PASS: %s\n' "$label"; else printf 'FAIL: %s (rc=%s; %s)\n' "$label" "$rc" "$out"; fails=$((fails+1)); fi; }
run() { : > "$LOG"; rc=0; out=$("$CREW" "$@" 2>&1) || rc=$?; }
app_log() { sed -n '/^\["herdr-app"/p' "$LOG" | jq -s "$@"; }
policy_from_command() {
  /bin/bash -c 'eval "set -- $1"; while (( $# )); do case "$1" in OPENCODE_CONFIG_CONTENT=*) printf "%s\n" "${1#OPENCODE_CONFIG_CONTENT=}"; exit 0 ;; --agents) shift; printf "%s\n" "$1"; exit 0 ;; esac; shift; done; exit 1' _ "$1"
}
registered_and_sent() {
  local name=$1 meta="$HOME/.herdr/crew/fixture/$1.meta" terminal
  [[ -s "$meta" && -s "$HOME/.herdr/crew/fixture/$name.brief" && -s "$HOME/.herdr/crew/fixture/$name.definition" ]] || return 1
  terminal=$(sed -n 's/^terminal=//p' "$meta")
  [[ -n "$terminal" ]] && jq -se --arg terminal "$terminal" 'any(.[]; .[0:3] == ["hc","send",$terminal])' "$LOG" >/dev/null
}
claude_policy() {
  [[ "$rc" == 0 ]] || return 1
  app_log -e '[.[] | select(.[0] == "herdr-app" and .[1] == "do" and (.[2] == "space.new" or .[2] == "tab.new" or .[2] == "pane.split")) | . as $call | ($call|index("--argv")) as $i | ($call[$i+1]|fromjson) as $argv | ($argv|index("--agents")) as $a | select($a != null) | $argv[$a+1] | fromjson | to_entries[] | .value | select((.prompt | contains("CUSTOM PAYMENT REVIEW ORIGINAL")) and (.tools | index("Write") | not) and (.disallowedTools | index("Write")))] | length > 0' >/dev/null
}
label='Claude project inspector uses selected guidance and native read-only policy'
run team payments T7 'inspect payments'
check claude_policy
label='agent registration saves snapshots and sends its first brief'
check registered_and_sent fixture-t7-payments-reviewer
original_claude_policy=$(app_log -r '[.[] | select(.[0:2] == ["herdr-app","do"] and (index("--argv") != null)) | .[-1] | fromjson | . as $a | ($a | index("--agents")) as $i | select($i != null) | $a[$i+1] | fromjson][0]')
printf '%s\n' 'CUSTOM PAYMENT REVIEW CHANGED' > "$CREW_REPO/.herdr-crew/agents/payments-reviewer/AGENTS.md"
label='Claude restart keeps original inspector definition'
restart_term=$(sed -n 's/^terminal=//p' "$HOME/.herdr/crew/fixture/fixture-t7-payments-reviewer.meta")
printf 'working\nnull\nworking\nworking\nworking\n' >"$STATE/get-seq.$restart_term"
run restart fixture-t7-payments-reviewer
check bash -c '[[ "$1" == 0 ]] && rg -q "CUSTOM PAYMENT REVIEW ORIGINAL" "$2" && ! rg -q "CUSTOM PAYMENT REVIEW CHANGED" "$2"' _ "$rc" "$HOME/.herdr/crew/fixture/fixture-t7-payments-reviewer.definition"
restart_command=$(jq -sr --arg term "$restart_term" '[.[] | select(.[0:3] == ["hc","send",$term] and .[3] != "/exit") | .[3]][0]' "$LOG")
restart_policy=$(policy_from_command "$restart_command")
label='Claude restart sends original native policy'; check jq -ne --argjson a "$original_claude_policy" --argjson b "$restart_policy" '$a == $b'
cp "$HOME/.herdr/crew/fixture/fixture-t7-payments-reviewer.definition" "$TMP/saved-definition" 2>/dev/null || :
rm -f "$HOME/.herdr/crew/fixture/fixture-t7-payments-reviewer.definition"
label='restart refuses missing snapshot before stopping the agent'
run restart fixture-t7-payments-reviewer
check bash -c '[[ "$1" != 0 ]] && ! jq -se '\''any(.[]; .[0:2] == ["hc","send"] and .[3] == "/exit")'\'' "$2" >/dev/null' _ "$rc" "$LOG"
printf '%s\n' 'not-json' > "$HOME/.herdr/crew/fixture/fixture-t7-payments-reviewer.definition"
label='restart refuses malformed snapshot before stopping the agent'
run restart fixture-t7-payments-reviewer
check bash -c '[[ "$1" != 0 ]] && ! jq -se '\''any(.[]; .[0:2] == ["hc","send"] and .[3] == "/exit")'\'' "$2" >/dev/null' _ "$rc" "$LOG"
[[ ! -f "$TMP/saved-definition" ]] || cp "$TMP/saved-definition" "$HOME/.herdr/crew/fixture/fixture-t7-payments-reviewer.definition"
printf '%s\n' 'CUSTOM PAYMENT REVIEW ORIGINAL' > "$CREW_REPO/.herdr-crew/agents/payments-reviewer/AGENTS.md"
# Invalid later slot must fail before task, workspace, pane or Git worktree mutation.
printf '%s\n' 'members=member@driver inspector@missing-reviewer' 'worktree=new' > "$CREW_REPO/.herdr-crew/teams/bad.conf"
label='invalid later slot fails before resources'
run team bad T8 'must refuse'
check bash -c '[[ "$1" != 0 && "$4" == *"missing-reviewer"* ]] && ! jq -se '\''any(.[]; (.[0] == "tsk") or (.[0:2] == ["tab","create"]) or (.[0:2] == ["pane","split"]) or (.[0:2] == ["agent","start"]))'\'' "$2" >/dev/null && ! grep -qF '\''["herdr-app","do"'\'' "$2" && [[ ! -e "$3/.herdr/worktrees/fixture/T8-bad" ]]' _ "$rc" "$LOG" "$HOME" "$out"
printf '%s\n' 'members=inspector@payments-reviewer' 'worktree=none' > "$CREW_REPO/.herdr-crew/outside.conf"
label='team traversal is rejected before resources'
run team ../outside T8 'must refuse'
check bash -c '[[ "$1" != 0 ]] && ! jq -se '\''any(.[]; (.[0] == "tsk") or (.[0:2] == ["tab","create"]) or (.[0:2] == ["agent","start"]))'\'' "$2" >/dev/null && ! grep -qF '\''["herdr-app","do"'\'' "$2"' _ "$rc" "$LOG"
# Configuring OpenCode is fixture data, not a provider request.
printf '%s\n' '{"version":1,"roles":{"payments-reviewer":{"agent":"opencode","model":"provider/reviewer"}}}' > "$CREW_REPO/.herdr-crew/config.json"
label='OpenCode project inspector has selected guidance and native deny policy'
run team payments T9 'inspect payments'
app_log > "$TMP/app-log.json"
check bash -c '[[ "$1" == 0 ]] && jq -e '\''[.[] | select(.[0] == "herdr-app" and .[1] == "do" and (.[2] == "space.new" or .[2] == "tab.new" or .[2] == "pane.split")) | . as $call | ($call|index("--argv")) as $i | ($call[$i+1]|fromjson)[] | select(startswith("OPENCODE_CONFIG_CONTENT=")) | sub("^OPENCODE_CONFIG_CONTENT=";"") | fromjson | .agents.crew | select((.system | contains("CUSTOM PAYMENT REVIEW ORIGINAL")) and .permissions[0] == {action:"*",resource:"*",effect:"deny"} and (any(.permissions[]; .action == "edit" and .effect == "allow")|not) and (any(.permissions[]; .action == "subagent" and .effect == "allow")|not))] | length > 0'\'' "$2" >/dev/null' _ "$rc" "$TMP/app-log.json"
original_opencode_policy=$(jq -r '[.[] | select(.[0:2] == ["herdr-app","do"] and (index("--argv") != null)) | .[-1] | fromjson | .[] | select(startswith("OPENCODE_CONFIG_CONTENT=")) | sub("^OPENCODE_CONFIG_CONTENT=";"") | fromjson][0]' "$TMP/app-log.json")
# Restart must use the saved definition and native policy, not edited files.
printf '%s\n' 'CUSTOM PAYMENT REVIEW CHANGED' > "$CREW_REPO/.herdr-crew/agents/payments-reviewer/AGENTS.md"
label='restart retains original inspector guidance and native policy after project edit'
restart_term=$(sed -n 's/^terminal=//p' "$HOME/.herdr/crew/fixture/fixture-t9-payments-reviewer.meta")
printf 'working\nnull\nworking\nworking\nworking\n' >"$STATE/get-seq.$restart_term"
run restart fixture-t9-payments-reviewer
check bash -c '[[ "$1" == 0 ]] && grep -q "CUSTOM PAYMENT REVIEW ORIGINAL" "$HOME/.herdr/crew/fixture/fixture-t9-payments-reviewer.definition" && ! grep -q "CUSTOM PAYMENT REVIEW CHANGED" "$2"' _ "$rc" "$LOG"
restart_command=$(jq -sr --arg term "$restart_term" '[.[] | select(.[0:3] == ["hc","send",$term] and .[3] != "/exit") | .[3]][0]' "$LOG")
restart_policy=$(policy_from_command "$restart_command")
label='OpenCode restart sends original native policy'; check jq -ne --argjson a "$original_opencode_policy" --argjson b "$restart_policy" '$a == $b'
label='fresh launch uses changed project inspector guidance'
run team payments T10 'inspect payments again'
app_log > "$TMP/fresh-app-log.json"
check bash -c '[[ "$1" == 0 ]] && jq -e '\''[.[] | select(.[0] == "herdr-app" and .[1] == "do" and (.[2] == "space.new" or .[2] == "tab.new" or .[2] == "pane.split")) | . as $call | ($call|index("--argv")) as $i | ($call[$i+1]|fromjson)[] | select(startswith("OPENCODE_CONFIG_CONTENT=")) | sub("^OPENCODE_CONFIG_CONTENT=";"") | fromjson | .agents.crew.system | select(contains("CUSTOM PAYMENT REVIEW CHANGED"))] | length > 0'\'' "$2" >/dev/null' _ "$rc" "$TMP/fresh-app-log.json"
(( fails == 0 )) || { printf '%s checks failed\n' "$fails"; exit 1; }
printf 'ALL PASS\n'
