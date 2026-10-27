#!/usr/bin/env bash
# Project configuration regressions: real Git, disposable HOME, no live agents.
set -euo pipefail
CREW="$(cd "$(dirname "$0")/.." && pwd)/bin/crew"
TEMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TEMP_ROOT"' EXIT
mkdir -p "$TEMP_ROOT/home" "$TEMP_ROOT/project with spaces" "$TEMP_ROOT/other" "$TEMP_ROOT/fake"
export HOME="$TEMP_ROOT/home"
unset CREW_REPO CREW_SLUG CREW_AGENT CREW_TASK CREW_MANAGER CREW_DRY_RUN CREW_WS
PROJECT="$TEMP_ROOT/project with spaces"
git -C "$PROJECT" init -q
git -C "$PROJECT" -c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty -qm initial
git -C "$TEMP_ROOT/other" init -q
# Runtime calls are forbidden during configure, even if these binaries are installed.
export LOG="$TEMP_ROOT/runtime.log"
for tool in herdr tsk claude; do
  cat >"$TEMP_ROOT/fake/$tool" <<'SH'
#!/usr/bin/env bash
echo "$*" >>"$LOG"
exit 99
SH
  chmod +x "$TEMP_ROOT/fake/$tool"
done
export CATALOG_FILE="$TEMP_ROOT/catalog.json"
cat >"$CATALOG_FILE" <<'JSON'
{"location":{},"data":[
  {"providerID":"opencode","id":"deepseek-v4.1-flash-free","enabled":true,"variants":[{"id":"low"},{"id":"high"},{"id":"max"}]},
  {"providerID":"local","id":"plain","enabled":true,"variants":[]},
  {"providerID":"provider","id":"model","enabled":true,"variants":[{"id":"high"}]},
  {"providerID":"local","id":"disabled","enabled":false,"variants":[]}
]}
JSON
cat >"$TEMP_ROOT/fake/opencode" <<'SH'
#!/usr/bin/env bash
if [[ "$*" == 'api --standalone model.list' ]]; then
  [[ -z "${CREW_TEST_CATALOG_ERROR:-}" ]] || exit 1
  cat "$CATALOG_FILE"
else exit 99; fi
SH
chmod +x "$TEMP_ROOT/fake/opencode"
export PATH="$TEMP_ROOT/fake:$PATH"
cd "$PROJECT"
fails=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; fails=$((fails+1)); }
run() { rc=0; out=$("$CREW" configure "$@" 2>&1) || rc=$?; }
expect() { if eval "$2"; then pass "$1"; else fail "$1 (rc=$rc, output: $out)"; fi; }
run --show
expect 'defaults resolve without runtime calls or a config write' '[[ $rc == 0 && "$out" == *lead* && "$out" == *claude* && ! -e .herdr-crew.json && ! -e "$LOG" ]]'
run driver claude --model 'custom model; $(touch NEVER)' --effort high
expect 'configure saves literal model data and only the selected role' '[[ $rc == 0 && -f .herdr-crew.json && ! -e NEVER ]] && jq -e '\''.version == 1 and (.roles|keys) == ["driver"] and .roles.driver.model == "custom model; $(touch NEVER)"'\'' .herdr-crew.json >/dev/null'
[[ -f .herdr-crew.json ]] || { echo "Configuration write is missing; stopping dependent checks"; exit 1; }
cp .herdr-crew.json "$TEMP_ROOT/before"
run lead claude --model opus
expect 'configuring another role preserves prior assignments' '[[ $rc == 0 ]] && jq -e '\''.roles.driver.model != null and .roles.lead.model == "opus"'\'' .herdr-crew.json >/dev/null'
run --show
expect 'show includes resolved job assignments and config location' '[[ $rc == 0 && "$out" == *driver* && "$out" == *"custom model"* && "$out" == *".herdr-crew.json"* ]]'
if [[ -f .herdr-crew.json ]]; then cp .herdr-crew.json "$TEMP_ROOT/before"; fi
for args in 'driver unknown' 'bogus claude' 'driver claude --oops' 'driver claude --effort bogus' 'driver opencode --effort max' 'driver opencode --model provider/model#high'; do
  read -r -a words <<<"$args"
  run "${words[@]}"
  expect "reject invalid input: $args" '[[ $rc != 0 ]] && cmp -s .herdr-crew.json "$TEMP_ROOT/before"'
done
run --interactive </dev/null
expect 'wizard EOF does not change the config' '[[ $rc != 0 ]] && cmp -s .herdr-crew.json "$TEMP_ROOT/before"'
run < /dev/null
expect 'noninteractive bare configure never waits for input' '[[ $rc != 0 && "$out" == *"--show"* ]]'
# No model is guessed for another agent, and job-specific settings win.
run member opencode
run --show
expect 'agent changes clear inherited Claude model and effort' '[[ $rc == 0 && $'\''\n'\''"$out"$'\''\n'\'' == *$'\''\nmember\topencode\tdefault\tdefault\n'\''* ]]'
git -C "$PROJECT" worktree add -qb worker "$TEMP_ROOT/worker"
cd "$TEMP_ROOT/worker"
run navigator claude --model alternate
expect 'linked worktree writes the primary project config' '[[ $rc == 0 && ! -e .herdr-crew.json ]] && jq -e '\''.roles.navigator.model == "alternate"'\'' "$PROJECT/.herdr-crew.json" >/dev/null'
cd "$TEMP_ROOT/other"
run --show
expect 'other projects retain their own defaults' '[[ $rc == 0 && "$out" != *alternate* && "$out" != *"custom model"* && ! -e .herdr-crew.json ]]'
cd "$PROJECT"
cp .herdr-crew.json "$TEMP_ROOT/valid"
for bad in '{broken' '{"version":2,"roles":{}}' '{"version":1,"roles":{"driver":{"agent":"claude","extra":true}}}' '{"version":1,"roles":{"driver":{"agent":"claude","model":42}}}' '{"version":1,"roles":{"unknown":{"agent":"claude"}}}' '{"version":1,"roles":{"driver":{"agent":"claude","model":"bad\nmodel"}}}'; do
  printf '%s\n' "$bad" >.herdr-crew.json
  run --show
  expect 'invalid stored configuration fails with its path' '[[ $rc != 0 && "$out" == *".herdr-crew.json"* ]]'
done
cp "$TEMP_ROOT/valid" .herdr-crew.json
mv .herdr-crew.json "$TEMP_ROOT/target"
ln -s "$TEMP_ROOT/target" .herdr-crew.json
run driver claude --model nope
expect 'symlink config destination is refused without changing target' '[[ $rc != 0 && -L .herdr-crew.json ]] && cmp -s "$TEMP_ROOT/target" "$TEMP_ROOT/valid"'
[[ ! -e "$LOG" ]] && pass 'configuration never invokes Herdr or tsk' || fail 'configuration called runtime tools'
rm .herdr-crew.json
cp "$TEMP_ROOT/valid" .herdr-crew.json
# A JSON stream must be refused before a configure write, not only during show.
printf '%s\n' '{"version":2,"roles":{}}' '{"version":1,"roles":{}}' >.herdr-crew.json
cp .herdr-crew.json "$TEMP_ROOT/stream-before"
run driver claude --model must-not-save
expect 'multiple JSON documents are rejected without rewriting the file' '[[ $rc != 0 ]] && cmp -s .herdr-crew.json "$TEMP_ROOT/stream-before"'
cp "$TEMP_ROOT/valid" .herdr-crew.json
# A separate Git metadata directory is not the project checkout.
git init -q --separate-git-dir "$TEMP_ROOT/admin" "$TEMP_ROOT/separate"
git -C "$TEMP_ROOT/separate" -c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty -qm initial
cd "$TEMP_ROOT/separate"
run navigator claude --model separate-model
expect 'separate Git metadata keeps config inside its project' '[[ $rc == 0 && -f .herdr-crew.json && ! -e "$TEMP_ROOT/.herdr-crew.json" ]]'
git worktree add -qb separate-worker "$TEMP_ROOT/separate-worker"
cd "$TEMP_ROOT/separate-worker"
run planner claude --model must-not-write
expect 'unlocatable primary checkout fails instead of writing Git metadata' '[[ $rc != 0 && "$out" == *"CREW_REPO"* && ! -e .herdr-crew.json && ! -e "$TEMP_ROOT/admin/.herdr-crew.json" ]]'
CREW_REPO="$TEMP_ROOT/separate" run planner claude --model separate-planner
if [[ $rc == 0 && ! -e .herdr-crew.json ]] && jq -e '.roles.planner.model == "separate-planner" and .roles.navigator.model == "separate-model"' "$TEMP_ROOT/separate/.herdr-crew.json" >/dev/null; then
  pass 'explicit primary project pointer shares separated-metadata config'
else fail "explicit primary pointer (rc=$rc, output: $out)"; fi
git -C "$TEMP_ROOT/separate" config core.worktree "$TEMP_ROOT/separate"
run tester claude --model separate-tester
if [[ $rc == 0 && ! -e .herdr-crew.json ]] && jq -e '.roles.tester.model == "separate-tester"' "$TEMP_ROOT/separate/.herdr-crew.json" >/dev/null; then
  pass 'configured core.worktree resolves the real primary checkout'
else fail "core.worktree resolution (rc=$rc, output: $out)"; fi
cd "$PROJECT"

# Interactive setup saves once; a later EOF cancels the entire edit.
run --interactive <<'INPUT'
planner
claude
wizard-model
high
n
INPUT
expect 'wizard saves an explicitly entered role, model and Claude effort' '[[ $rc == 0 ]] && jq -e '\''.roles.planner.model == "wizard-model" and .roles.planner.effort == "high"'\'' .herdr-crew.json >/dev/null'
cp .herdr-crew.json "$TEMP_ROOT/before-wizard"
run --interactive <<'INPUT'
lead
claude
never-saved
high
y
INPUT
expect 'wizard cancels all pending edits on a later EOF' '[[ $rc != 0 ]] && cmp -s .herdr-crew.json "$TEMP_ROOT/before-wizard"'
run member opencode --model opencode/deepseek-v4.1-flash-free --effort high
expect 'OpenCode saves a supported model-specific effort' '[[ $rc == 0 ]] && jq -e '\''.roles.member.effort == "high"'\'' .herdr-crew.json >/dev/null'
cp .herdr-crew.json "$TEMP_ROOT/before-variant"
run member opencode --model opencode/deepseek-v4.1-flash-free --effort medium
expect 'unsupported model effort reports supported choices without saving' '[[ $rc != 0 && "$out" == *"low"* && "$out" == *"high"* && "$out" == *"max"* ]] && cmp -s .herdr-crew.json "$TEMP_ROOT/before-variant"'
run member opencode --effort high
expect 'OpenCode effort requires an explicit model' '[[ $rc != 0 && "$out" == *"model"* ]] && cmp -s .herdr-crew.json "$TEMP_ROOT/before-variant"'
run --interactive <<'INPUT'
lead
claude
opus
high
y
member
opencode
deepseek
1
2
n
INPUT
expect 'wizard searches models and offers selected model efforts after a Claude role' '[[ $rc == 0 ]] && jq -e '\''.roles.lead.effort == "high" and .roles.member == {agent:"opencode",model:"opencode/deepseek-v4.1-flash-free",effort:"high"}'\'' .herdr-crew.json >/dev/null'
run --interactive <<'INPUT'
member
opencode
local/plain
n
INPUT
expect 'wizard skips effort selection for a model without variants' '[[ $rc == 0 ]] && jq -e '\''.roles.member == {agent:"opencode",model:"local/plain",effort:"inherit"}'\'' .herdr-crew.json >/dev/null'
cp .herdr-crew.json "$TEMP_ROOT/before-variant"
CREW_TEST_CATALOG_ERROR=1 run --interactive <<'INPUT'
member
opencode
INPUT
expect 'catalog failure cancels setup without changing saved assignments' '[[ $rc != 0 && "$out" == *"catalog"* ]] && cmp -s .herdr-crew.json "$TEMP_ROOT/before-variant"'
run --interactive <<'INPUT'
member
opencode
local/disabled
INPUT
expect 'wizard refuses disabled catalog models and cancels on EOF' '[[ $rc != 0 ]] && cmp -s .herdr-crew.json "$TEMP_ROOT/before-variant"'

run member opencode --model opencode/deepseek-v4.1-flash-free --effort high
run driver opencode --model local/plain
run --show
driver_row=$(printf '%s\n' "$out" | awk -F '\t' '$1 == "driver" {print $3, $4}')
expect 'changing OpenCode model clears variants inherited from another model' '[[ $rc == 0 && "$driver_row" == "local/plain default" ]]'

# Runtime adapter tests: capture each argument exactly, not shell-flattened text.
rm .herdr-crew.json
printf '%s\n' '{"version":1,"roles":{}}' >.herdr-crew.json
cat >"$TEMP_ROOT/fake/herdr" <<'SH'
#!/usr/bin/env bash
jq -nc --args '$ARGS.positional' -- "$@" >>"$LOG"
case "$1 $2" in
  'tab create'|'pane split')
    pane=p1; [[ "$1" != pane ]] || pane=p2
    jq -nc --args '$ARGS.positional' -- "$@" >"$PANE_ENV_DIR/$pane"
    ;;
  'agent start')
    pane=p1
    for ((i=1; i <= $#; i++)); do
      if [[ "${!i}" == --pane ]]; then i=$((i+1)); pane=${!i}; pane=${pane##*:}; break; fi
    done
    if [[ -f "$PANE_ENV_DIR/$pane" ]]; then
      policy=$(jq -c '[.[]|select(startswith("OPENCODE_CONFIG_CONTENT="))|sub("^OPENCODE_CONFIG_CONTENT=";"")|fromjson][0] // {}' "$PANE_ENV_DIR/$pane")
      jq -nc --arg name "$3" --argjson policy "$policy" '["effective-policy",$name,$policy]' >>"$LOG"
    fi ;;
esac
case "$1 $2" in
  'agent get') exit 1 ;;
  'tab create') echo '{"result":{"root_pane":{"pane_id":"w1:p1"}}}' ;;
  'pane split') echo '{"result":{"pane":{"pane_id":"w1:p2"}}}' ;;
  'pane process-info') echo '{"result":{"process_info":{"foreground_process_group_id":1,"shell_pid":1}}}' ;;
  *) exit 0 ;;
esac
SH
cat >"$TEMP_ROOT/fake/tsk" <<'SH'
#!/usr/bin/env bash
jq -nc --args '$ARGS.positional' -- "tsk" "$@" >>"$LOG"
echo '[{"number":7,"notes":"adapter regression"}]'
SH
for tool in claude opencode; do
  cat >"$TEMP_ROOT/fake/$tool" <<'SH'
#!/usr/bin/env bash
case "$1" in
  api) [[ "$*" == "api --standalone model.list" ]] || exit 99; cat "$CATALOG_FILE" ;;
  --version) echo 2.1.2 ;;
  --help) echo --standalone ;;
  *) exit 99 ;;
esac
SH
  chmod +x "$TEMP_ROOT/fake/$tool"
done
export HERDR_ENV=1 CREW_WS=w1 CREW_SLUG=config-fixture CREW_REPO="$PROJECT"
export PANE_ENV_DIR="$TEMP_ROOT/panes"
mkdir -p "$PANE_ENV_DIR"
launch() { rc=0; out=$("$CREW" "$@" 2>&1) || rc=$?; }
run driver opencode --model provider/model --effort high
: >"$LOG"
launch team pair T7 'mixed team'
expect 'mixed team launches configured driver with standalone OpenCode' '[[ $rc == 0 ]] && jq -se '\''any(.[]; .[0:3] == ["agent","start","config-fixture-t7-driver"] and (index("opencode") != null) and (index("--standalone") != null))'\'' "$LOG" >/dev/null'
expect 'unconfigured navigator keeps Claude native rank settings' 'jq -se '\''any(.[]; .[0:3] == ["agent","start","config-fixture-t7-navigator"] and (index("crew-inspector") != null) and (index("--settings") != null))'\'' "$LOG" >/dev/null'
policy=$(jq -rs '[.[][] | select(type == "string") | select(startswith("OPENCODE_CONFIG_CONTENT=")) | sub("^OPENCODE_CONFIG_CONTENT=";"") | fromjson][0] // {}' "$LOG")
expect 'OpenCode receives provider model and member native edit permission' 'jq -e '\''.model == "provider/model" and .agents.crew.model == "provider/model#high" and (.agents.crew.permissions|length > 0) and any(.agents.crew.permissions[]?; .action == "edit" and .effect == "allow")'\'' <<<"$policy" >/dev/null'
# Model the documented whole-value wildcards, trailing " *" bare-command match,
# and last-match precedence: https://opencode.ai/v2/docs/permissions/#matching
shell_effect() {
  local command=$1 action resource effect result=ask
  while IFS=$'\t' read -r action resource effect; do
    [[ $action == shell || $action == '*' ]] || continue
    if [[ $command == $resource || ( $resource == *' *' && $command == ${resource% \*} ) ]]; then result=$effect; fi
  done < <(jq -r '.agents.crew.permissions[] | [.action,.resource,.effect] | @tsv' <<<"$policy")
  printf '%s\n' "$result"
}
for command in 'git push' 'git push origin branch' 'git merge' 'git merge branch' \
  'git -C repo push' 'git -C repo push origin branch' 'git -C repo merge' 'git -C repo merge branch' \
  'git -C "project with spaces" push origin branch' 'git -C "project with spaces" merge'; do
  expect "member policy denies: $command" '[[ $(shell_effect "$command") == deny ]]'
done
for command in 'git status' 'git diff --stat' 'git -C repo status' 'git -C repo diff' 'git add file' 'git commit -m change' 'printf hello'; do
  expect "member policy allows: $command" '[[ $(shell_effect "$command") == allow ]]'
done
expect 'OpenCode brief includes native role guidance without claiming a context hook' 'jq -se '\''any(.[]; .[0:3] == ["agent","prompt","config-fixture-t7-driver"] and (.[3]|contains("OpenCode runtime")) and (.[3]|contains("A hook warns you")|not))'\'' "$LOG" >/dev/null'
run driver claude --model changed
: >"$LOG"
launch restart config-fixture-t7-driver
expect 'restart pins original provider and model across config edits' '[[ $rc == 0 ]] && jq -se '\''any(.[]; .[0:3] == ["agent","start","config-fixture-t7-driver"] and (index("opencode") != null))'\'' "$LOG" >/dev/null'
policy=$(jq -cs '[.[]|select(.[0] == "effective-policy" and .[1] == "config-fixture-t7-driver")|.[2]][0] // {}' "$LOG")
expect 'restart restores original provider model and effort variant' 'jq -e '\''.model == "provider/model" and .agents.crew.model == "provider/model#high"'\'' <<<"$policy" >/dev/null'
run inspector opencode --model provider/reviewer
: >"$LOG"
launch team investigate T8 'read only'
policy=$(jq -rs '[.[][] | select(type == "string") | select(startswith("OPENCODE_CONFIG_CONTENT=")) | sub("^OPENCODE_CONFIG_CONTENT=";"") | fromjson][0] // {}' "$LOG")
expect 'read-only OpenCode policy denies unknown tools and allows rank commands' '[[ $rc == 0 ]] && jq -e '\''.agents.crew.permissions[0] == {action:"*",resource:"*",effect:"deny"} and any(.agents.crew.permissions[]; .action == "shell" and .resource == "tsk list *" and .effect == "allow") and (any(.agents.crew.permissions[]; .action == "edit" and .effect == "allow")|not) and (any(.agents.crew.permissions[]; .action == "subagent" and .effect == "allow")|not)'\'' <<<"$policy" >/dev/null'
: >"$LOG"
launch team lead T11 'rank-only team'
if [[ $rc == 0 ]] && jq -se 'any(.[]; .[0:3] == ["agent","start","config-fixture-t11-lead"])' "$LOG" >/dev/null; then
  pass 'rank-only team slots preflight without inventing job personas'
else fail "rank-only team slots preflight (rc=$rc, output: $out)"; fi
cat >"$TEMP_ROOT/fake/opencode" <<'SH'
#!/usr/bin/env bash
echo 1.9.0
SH
: >"$LOG"
launch team pair T9 'must not start'
expect 'unsupported OpenCode version fails before any team mutation' '[[ $rc != 0 && "$out" == *"OpenCode 2"* ]] && ! jq -se '\''any(.[]; .[0:2] == ["tab","create"] or .[0:2] == ["agent","start"])'\'' "$LOG" >/dev/null && [[ ! -e "$HOME/.herdr/worktrees/config-fixture/T9-pair" ]]'
# A missing runtime in a later team slot must not leave a driver or worktree behind.
mkdir -p "$TEMP_ROOT/no-agent"
for tool in herdr tsk claude; do ln -s "$TEMP_ROOT/fake/$tool" "$TEMP_ROOT/no-agent/$tool"; done
ln -s "$(command -v jq)" "$TEMP_ROOT/no-agent/jq"
: >"$LOG"
rc=0
out=$(PATH="$TEMP_ROOT/no-agent:/usr/bin:/bin:/usr/sbin:/sbin" "$CREW" team pair T10 'missing reviewer runtime' 2>&1) || rc=$?
expect 'missing later-slot runtime fails before resource creation' '[[ $rc != 0 && "$out" == *"opencode not found"* && ! -s "$LOG" && ! -e "$HOME/.herdr/worktrees/config-fixture/T10-pair" ]]'
printf '%s\n' '{"version":1,"roles":{"driver":{"agent":"bogus"}}}' >.herdr-crew.json
: >"$LOG"
launch launch driver 'reject bad config'
expect 'bad project config is rejected before tsk task creation' '[[ $rc != 0 && "$out" == *".herdr-crew.json"* && ! -s "$LOG" ]]'
printf '%s\n' '{"version":1,"roles":{"member":{"agent":"opencode","effort":"high"}}}' >.herdr-crew.json
: >"$LOG"
out=$("$CREW" configure --show 2>&1) || rc=$?
expect 'OpenCode effort without model is rejected without rewriting config' '[[ $rc != 0 && "$out" == *".herdr-crew.json"* ]]'
printf '%s\n' '{"version":1,"roles":{"member":{"agent":"opencode","model":"opencode/deepseek-v4.1-flash-free","effort":"high"}}}' >.herdr-crew.json
: >"$LOG"
out=$("$CREW" configure --show 2>&1) || rc=$?
expect 'OpenCode effort with explicit model validates' '[[ $rc == 0 ]]'
rm .herdr-crew.json
(( fails == 0 )) || { echo "$fails checks failed"; exit 1; }
echo 'ALL PASS'
