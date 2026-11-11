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
source "$(cd "$(dirname "$0")/.." && pwd)/test/fixtures/fake-runtime.sh"
install_fake_runtime "$TEMP_ROOT/fake" "$TEMP_ROOT/state"
# Command Code stand-in: --version and --list-models only, never a session.
install_fake_cmd "$TEMP_ROOT/fake" "$TEMP_ROOT/state"
for tool in hc herdr-app tsk claude; do
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

# Command Code configuration: the model list is the fake `cmd --list-models` table, and the
# binary is metadata-only. A real cmd may exist on PATH, so the fake directory comes first.
: >"$STATE/cmd.log"
run driver command-code --model deepseek/deepseek-v4.1-flash --effort high
expect 'configure accepts command-code and saves agent, model and effort' '[[ $rc == 0 ]] && jq -e '\''.roles.driver == {agent:"command-code",model:"deepseek/deepseek-v4.1-flash",effort:"high"}'\'' .herdr-crew.json >/dev/null'
run --show
cc_row=$(printf '%s\n' "$out" | awk -F '\t' '$1 == "driver" {print $2, $3, $4}')
expect 'show reports the command-code row' '[[ $rc == 0 && "$cc_row" == "command-code deepseek/deepseek-v4.1-flash high" ]]'
expect 'the Command Code model list is cached for offline validation' '[[ -f "$HOME/.herdr/crew/command-code-models" ]] && grep -qxF deepseek/deepseek-v4.1-flash "$HOME/.herdr/crew/command-code-models" && grep -qxF claude-sonnet-5-5 "$HOME/.herdr/crew/command-code-models" && ! grep -qxF Recommended "$HOME/.herdr/crew/command-code-models"'
expect 'configure read the model list and never started a Command Code session' '[[ -s "$STATE/cmd.log" ]] && ! grep -q unsupported "$STATE/cmd.log"'
cp .herdr-crew.json "$TEMP_ROOT/before-cc"
run driver command-code --model not/a-listed-model
expect 'Command Code rejects a model that is not in --list-models' '[[ $rc != 0 && "$out" == *"list-models"* ]] && cmp -s .herdr-crew.json "$TEMP_ROOT/before-cc"'
run driver command-code --model 'space model'
expect 'Command Code rejects a model containing a space' '[[ $rc != 0 ]] && cmp -s .herdr-crew.json "$TEMP_ROOT/before-cc"'
run driver command-code --model 'bad#model'
expect 'Command Code rejects a model containing #' '[[ $rc != 0 ]] && cmp -s .herdr-crew.json "$TEMP_ROOT/before-cc"'
run driver command-code --effort high
expect 'Command Code effort without a model is rejected' '[[ $rc != 0 && "$out" == *"explicit --model"* ]] && cmp -s .herdr-crew.json "$TEMP_ROOT/before-cc"'
run driver commandcode --model deepseek/deepseek-v4.1-flash
expect 'the runtime alias commandcode is rejected as an agent' '[[ $rc != 0 && "$out" == *"invalid agent configuration"* ]] && cmp -s .herdr-crew.json "$TEMP_ROOT/before-cc"'
run driver command_code
expect 'the runtime alias command_code is rejected as an agent' '[[ $rc != 0 && "$out" == *"invalid agent configuration"* ]] && cmp -s .herdr-crew.json "$TEMP_ROOT/before-cc"'
run driver bogus
expect 'an unknown agent is still rejected next to command-code' '[[ $rc != 0 ]] && cmp -s .herdr-crew.json "$TEMP_ROOT/before-cc"'
# Wizard: role, the exact token, a search term, a choice number, an effort, then stop.
run --interactive <<'INPUT'
driver
command-code
sonnet
1
low
n
INPUT
expect 'wizard configures command-code from the catalog by search and number' '[[ $rc == 0 ]] && jq -e '\''.roles.driver == {agent:"command-code",model:"claude-sonnet-5-5",effort:"low"}'\'' .herdr-crew.json >/dev/null'
cp .herdr-crew.json "$TEMP_ROOT/before-cc-wizard"
run --interactive <<'INPUT'
driver
command-code
INPUT
expect 'wizard EOF cancels without a Command Code write' '[[ $rc != 0 && "$out" == *"cancelled"* ]] && cmp -s .herdr-crew.json "$TEMP_ROOT/before-cc-wizard"'

# Runtime adapter tests: capture each argument exactly, not shell-flattened text.
rm .herdr-crew.json
printf '%s\n' '{"version":1,"roles":{}}' >.herdr-crew.json
install_fake_runtime "$TEMP_ROOT/fake" "$TEMP_ROOT/state"
touch "$STATE/auto-ready"
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
policy_from_command() {
  /bin/bash -c 'eval "set -- $1"; while (( $# )); do case "$1" in OPENCODE_CONFIG_CONTENT=*) printf "%s\n" "${1#OPENCODE_CONFIG_CONTENT=}"; exit 0 ;; --agents) shift; printf "%s\n" "$1"; exit 0 ;; esac; shift; done; exit 1' _ "$1"
}

run driver opencode --model provider/model --effort high
: >"$LOG"
launch team pair T7 'mixed team'
app_argvs() { jq -sr '[.[] | select(.[0:2] == ["herdr-app","do"] and (index("--argv") != null)) | . as $call | ($call | index("--argv")) as $i | $call[$i+1] | fromjson] ' "$LOG"; }
argvs=$(app_argvs)
expect 'mixed team launches configured driver with standalone OpenCode' '[[ $rc == 0 ]] && jq -e '\''any(.[]; index("opencode") != null and index("--standalone") != null)'\'' <<<"$argvs" >/dev/null'
expect 'unconfigured navigator keeps Claude native rank settings' 'jq -e '\''any(.[]; index("crew-inspector") != null and index("--settings") != null)'\'' <<<"$argvs" >/dev/null'
policy=$(jq -r '[.[][] | select(startswith("OPENCODE_CONFIG_CONTENT=")) | sub("^OPENCODE_CONFIG_CONTENT=";"") | fromjson][0] // {}' <<<"$argvs")
expect 'OpenCode receives provider model and member native edit permission' 'jq -e '\''.model == "provider/model" and .agents.crew.model == "provider/model#high" and (.agents.crew.permissions|length > 0) and any(.agents.crew.permissions[]?; .action == "edit" and .effect == "allow")'\'' <<<"$policy" >/dev/null'
original_policy=$policy
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
expect 'OpenCode brief includes native role guidance without claiming a context hook' '[[ $(cat "$HOME/.herdr/crew/config-fixture/config-fixture-t7-driver.brief") == *"OpenCode runtime"* && $(cat "$HOME/.herdr/crew/config-fixture/config-fixture-t7-driver.brief") != *"A hook warns you"* ]]'
driver_term=$(sed -n 's/^terminal=//p' "$HOME/.herdr/crew/config-fixture/config-fixture-t7-driver.meta")
expect 'OpenCode guidance is actually sent to driver' 'jq -se --arg term "$driver_term" '\''any(.[]; .[0:3] == ["hc","send",$term] and (.[3] | contains("OpenCode runtime")))'\'' "$LOG" >/dev/null'
run driver claude --model changed
: >"$LOG"
restart_term=$(sed -n 's/^terminal=//p' "$HOME/.herdr/crew/config-fixture/config-fixture-t7-driver.meta")
saved_cmd=$(cat "$HOME/.herdr/crew/config-fixture/config-fixture-t7-driver.cmd")
printf 'working\nnull\nworking\nworking\nworking\n' >"$STATE/get-seq.$restart_term"
launch restart config-fixture-t7-driver
expect 'restart pins original provider and model across config edits' '[[ $rc == 0 ]] && jq -se --arg term "$restart_term" --arg command "$saved_cmd" '\''any(.[]; . == ["hc","send",$term,$command])'\'' "$LOG" >/dev/null'
expect 'restart restores original provider model and effort variant' '[[ "$saved_cmd" == *provider/model* && "$saved_cmd" == *high* ]]'
restart_command=$(jq -sr --arg term "$restart_term" '[.[] | select(.[0:3] == ["hc","send",$term] and .[3] != "/exit") | .[3]][0]' "$LOG")
restart_policy=$(policy_from_command "$restart_command")
expect 'restart sends exact original effective policy' 'jq -ne --argjson a "$original_policy" --argjson b "$restart_policy" '\''$a == $b and $b.model == "provider/model" and $b.agents.crew.model == "provider/model#high"'\'' >/dev/null'
run inspector opencode --model provider/reviewer
: >"$LOG"
launch team investigate T8 'read only'
argvs=$(app_argvs)
policy=$(jq -r '[.[][] | select(startswith("OPENCODE_CONFIG_CONTENT=")) | sub("^OPENCODE_CONFIG_CONTENT=";"") | fromjson][0] // {}' <<<"$argvs")
expect 'read-only OpenCode policy denies unknown tools and allows rank commands' '[[ $rc == 0 ]] && jq -e '\''.agents.crew.permissions[0] == {action:"*",resource:"*",effect:"deny"} and any(.agents.crew.permissions[]; .action == "shell" and .resource == "tsk list *" and .effect == "allow") and (any(.agents.crew.permissions[]; .action == "edit" and .effect == "allow")|not) and (any(.agents.crew.permissions[]; .action == "subagent" and .effect == "allow")|not)'\'' <<<"$policy" >/dev/null'
: >"$LOG"
launch team lead T11 'rank-only team'
if [[ $rc == 0 ]] && jq -se 'any(.[]; .[0:3] == ["herdr-app","do","tab.new"] and (.[-1] | contains("config-fixture-t11-lead")))' "$LOG" >/dev/null; then
  pass 'rank-only team slots preflight without inventing job personas'
else fail "rank-only team slots preflight (rc=$rc, output: $out)"; fi
cat >"$TEMP_ROOT/fake/opencode" <<'SH'
#!/usr/bin/env bash
echo 1.9.0
SH
: >"$LOG"
launch team pair T9 'must not start'
expect 'unsupported OpenCode version fails before any team mutation' '[[ $rc != 0 && "$out" == *"OpenCode 2"* ]] && ! jq -se '\''any(.[]; .[0:3] == ["herdr-app","do","tab.new"] or .[0:3] == ["herdr-app","do","space.new"])'\'' "$LOG" >/dev/null && [[ ! -e "$HOME/.herdr/worktrees/config-fixture/T9-pair" ]]'
# A missing runtime in a later team slot must not leave a driver or worktree behind.
mkdir -p "$TEMP_ROOT/no-agent"
for tool in hc herdr-app tsk claude; do ln -s "$TEMP_ROOT/fake/$tool" "$TEMP_ROOT/no-agent/$tool"; done
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
rc=0
out=$("$CREW" configure --show 2>&1) || rc=$?
expect 'OpenCode effort with explicit model validates' '[[ $rc == 0 ]]'
rm .herdr-crew.json

# Command Code launches: version gate, missing binary, built argv, native mod, permission
# modes and the pinned restart. argv_program/argv_value read the app --argv JSON exactly.
argv_program() { jq -r '[.[] | select(test("^[A-Za-z_][A-Za-z0-9_]*=") | not)][1] // ""' <<<"$1"; }
argv_value() { jq -r --arg flag "$2" '. as $a | ($a | index($flag)) as $i | if $i == null then "" else $a[$i + 1] end' <<<"$1"; }
# command_flag_value COMMAND FLAG: the value that follows FLAG in a saved command line.
command_flag_value() {
  /bin/bash -c 'flag=$2; eval "set -- $1"; while (( $# )); do if [[ "$1" == "$flag" ]]; then shift; printf "%s\n" "$1"; exit 0; fi; shift; done; exit 1' _ "$1" "$2"
}
cc_argv_of() { jq -c --arg agent "CREW_AGENT=$1" '[.[] | select(any(.[]; . == $agent))][0] // []' <<<"$2"; }

# The launch section initializes the project baseline, so the live config moves to
# .herdr-crew/config.json. Start Command Code coverage from an empty assignment set.
mkdir -p .herdr-crew
printf '%s\n' '{"version":1,"roles":{}}' >.herdr-crew/config.json

# The version gate runs in preflight, before a task, tab or worktree exists.
printf '1.80.0\n' >"$STATE/cmd-version"
run member command-code --model claude-sonnet-5-5
: >"$LOG"
launch team pair T20 'old command code'
expect 'Command Code older than 1.88.5 fails before task, tab or worktree creation' '[[ $rc != 0 && "$out" == *"1.88.5"* ]] && ! jq -se '\''any(.[]; .[0:3] == ["herdr-app","do","tab.new"] or .[0:3] == ["herdr-app","do","space.new"])'\'' "$LOG" >/dev/null && ! jq -se '\''any(.[]; .[0] == "tsk")'\'' "$LOG" >/dev/null && [[ ! -e "$HOME/.herdr/worktrees/config-fixture/T20-pair" ]]'
printf '1.88.5\n' >"$STATE/cmd-version"

# A PATH with the other runtimes but no cmd, command-code or commandcode.
mkdir -p "$TEMP_ROOT/no-command-code"
for tool in hc herdr-app tsk claude opencode; do ln -sf "$TEMP_ROOT/fake/$tool" "$TEMP_ROOT/no-command-code/$tool"; done
ln -sf "$(command -v jq)" "$TEMP_ROOT/no-command-code/jq"
: >"$LOG"
rc=0
out=$(PATH="$TEMP_ROOT/no-command-code:/usr/bin:/bin" "$CREW" team pair T21 'missing command code binary' 2>&1) || rc=$?
expect 'a PATH without cmd fails with a message naming command-code' '[[ $rc != 0 && "$out" == *"command-code not found"* && ! -s "$LOG" && ! -e "$HOME/.herdr/worktrees/config-fixture/T21-pair" ]]'

# Member and inspector configured as Command Code: one tab, plan for the inspector.
run driver command-code --model deepseek/deepseek-v4.1-flash --effort high
run inspector command-code --model claude-sonnet-5-5
: >"$LOG"
launch team pair T22 'command code pair'
argvs=$(app_argvs)
cc_driver_argv=$(cc_argv_of config-fixture-t22-driver "$argvs")
cc_nav_argv=$(cc_argv_of config-fixture-t22-navigator "$argvs")
cc_driver_program=$(argv_program "$cc_driver_argv")
cc_driver_mode=$(argv_value "$cc_driver_argv" --permission-mode)
cc_nav_mode=$(argv_value "$cc_nav_argv" --permission-mode)
cc_driver_mod=$(argv_value "$cc_driver_argv" --mod)
cc_nav_mod=$(argv_value "$cc_nav_argv" --mod)
expect 'Command Code member program is cmd by basename, not an absolute path' '[[ $rc == 0 && "$cc_driver_program" == cmd ]]'
expect 'Command Code member argv carries -n NAME, the crew flags, --mod, --model and --effort' 'jq -e '\''(. as $a | ($a | index("-n")) as $n | $a[$n + 1] == "config-fixture-t22-driver") and index("-t") != null and index("--skip-onboarding") != null and index("--no-auto-update") != null and index("--mod") != null and index("--model") != null and index("--effort") != null'\'' <<<"$cc_driver_argv" >/dev/null'
expect 'Command Code member argv carries the configured model and effort' 'jq -e '\''(. as $a | ($a | index("--model")) as $m | ($a | index("--effort")) as $e | $a[$m + 1] == "deepseek/deepseek-v4.1-flash" and $a[$e + 1] == "high")'\'' <<<"$cc_driver_argv" >/dev/null'
expect 'Command Code argv has no --agent, --agents, --settings or --standalone' 'jq -e '\''index("--agent") == null and index("--agents") == null and index("--settings") == null and index("--standalone") == null'\'' <<<"$cc_driver_argv" >/dev/null'
expect 'Command Code argv names neither claude nor opencode' 'jq -e '\''any(.[]; . == "claude" or . == "opencode") | not'\'' <<<"$cc_driver_argv" >/dev/null && jq -e '\''any(.[]; . == "claude" or . == "opencode") | not'\'' <<<"$cc_nav_argv" >/dev/null'
expect 'Command Code member runs in yolo, the inspector in plan' '[[ "$cc_driver_mode" == yolo && "$cc_nav_mode" == plan ]]'
expect 'the member --mod path is the generated mod and it exists' '[[ -n "$cc_driver_mod" && "$cc_driver_mod" == "$HOME/.herdr/crew/config-fixture/config-fixture-t22-driver.mod.ts" && -f "$cc_driver_mod" ]]'
expect 'the inspector --mod path is its own generated mod' '[[ -n "$cc_nav_mod" && "$cc_nav_mod" == "$HOME/.herdr/crew/config-fixture/config-fixture-t22-navigator.mod.ts" && -f "$cc_nav_mod" ]]'

# Native-deny regression: the generated mod text wires the hooks and carries the member
# block reason. The suite does not execute the mod; a live headless run is recorded in STATE.
cc_driver_reasons=$(sed -n 's/^ *return "\(Crew policy:.*\)";$/\1/p' "$cc_driver_mod" 2>/dev/null || true)
expect 'the member mod wires beforeToolCall and onPermissionRequest' 'grep -qF beforeToolCall "$cc_driver_mod" && grep -qF onPermissionRequest "$cc_driver_mod"'
expect 'the mod reads the native toolName field and the input command' 'grep -qF toolName "$cc_driver_mod" && grep -qF "value.command" "$cc_driver_mod"'
expect 'the member mod names git, push, merge and gh pr merge' 'grep -qF git "$cc_driver_mod" && grep -qF push "$cc_driver_mod" && grep -qF merge "$cc_driver_mod" && grep -qF "gh pr merge" "$cc_driver_mod"'
expect 'the member mod states the git push, git merge and gh pr merge block reason' '[[ "$cc_driver_reasons" == *"a member never runs git push, git merge or gh pr merge"* ]]'
expect 'the member mod removes the subagent tools at session start' 'grep -qF onSessionStart "$cc_driver_mod" && grep -qF agent_output "$cc_driver_mod"'
expect 'the member mod injects the rank/job instructions and runtime guidance' 'grep -qF "Implementation job. Work only in your working dir" "$cc_driver_mod" && grep -qF "Command Code runtime" "$cc_driver_mod"'
expect 'the inspector mod states the no-write block reason' '[[ $(sed -n '\''s/^ *return "\(Crew policy:.*\)";$/\1/p'\'' "$cc_nav_mod") == *"never edits files"* ]]'

# Execute the generated mod: static greps cannot show that global git options are consumed
# or that the subagent filter reads the active tool list. Node is optional.
if command -v node >/dev/null 2>&1; then
  cp "$cc_driver_mod" "$TEMP_ROOT/cc-mod.mjs"
  rc=0
  out=$(node --input-type=module - "$TEMP_ROOT/cc-mod.mjs" <<'JS' 2>&1
import { pathToFileURL } from "node:url";

const mod = await import(pathToFileURL(process.argv[2]).href);
const notices = [];
const active = [];
let hooks = {};
const cmd = {
  hooks(h) { hooks = h; return { dispose() {} }; },
  getContextUsage() { return { tokens: null }; },
  getActiveTools() { return ["read_file", "shell_command", "agent", "agent_output"]; },
  setActiveTools(names) { active.length = 0; active.push(...names); },
  ui: { notify(message, level) { notices.push({ message, level }); } },
};
await mod.default(cmd);
const blocked = (command) =>
  !!(hooks.beforeToolCall({ toolName: "shell_command", input: { command } }, {}) || {}).block;
const cases = [
  ["git --no-pager push origin main", true],
  ["git -P merge topic", true],
  ["git --bare push", true],
  ["git --git-dir=.git push", true],
  ["git --work-tree=.. merge topic", true],
  ["git -C repo push", true],
  ["git -c core.pager=cat push", true],
  ["git -Crepo push", true],
  ["gh pr merge 12", true],
  ["git status", false],
  ["git -C repo status", false],
  ["git log --grep push", false],
  ["git commit -m merge", false],
  ["echo push", false],
];
let fails = 0;
for (const [command, want] of cases) {
  if (blocked(command) !== want) {
    fails += 1;
    console.log("FAIL matcher: " + command);
  }
}
hooks.onSessionStart({ source: "startup" });
if (active.join(",") !== "read_file,shell_command") {
  fails += 1;
  console.log("FAIL onSessionStart keep list: " + active.join(","));
}

let reported = false;
let hooks2 = {};
const cmd2 = {
  hooks(h) { hooks2 = h; return { dispose() {} }; },
  getActiveTools() { return []; },
  ui: { notify() { reported = true; } },
};
await mod.default(cmd2);
hooks2.onSessionStart({ source: "startup" });
if (!reported) {
  fails += 1;
  console.log("FAIL onSessionStart did not report an unreadable tool list");
}
process.exit(fails ? 1 : 0);
JS
  ) || rc=$?
  expect 'the generated member mod consumes global git options and filters tools via getActiveTools' '[[ $rc == 0 ]]'
else
  echo 'SKIP: node not found; the generated member mod was not executed'
fi

# Lead and manager as Command Code: the lead runs in yolo and the manager mod blocks writes.
run lead command-code --model claude-sonnet-5-5
run manager command-code --model claude-sonnet-5-5
: >"$LOG"
rc=0; out=$(printf 'command code lead\n' | "$CREW" launch lead - 2>&1) || rc=$?
argvs=$(app_argvs)
cc_lead_argv=$(cc_argv_of config-fixture-lead "$argvs")
cc_manager_argv=$(cc_argv_of config-fixture-manager "$argvs")
cc_lead_mode=$(argv_value "$cc_lead_argv" --permission-mode)
cc_manager_mod=$(argv_value "$cc_manager_argv" --mod)
cc_manager_reason=$(sed -n 's/^ *return "\(Crew policy:.*\)";$/\1/p' "$cc_manager_mod" 2>/dev/null || true)
expect 'Command Code lead runs in yolo' '[[ $rc == 0 && "$cc_lead_mode" == yolo && "$(argv_program "$cc_lead_argv")" == cmd ]]'
expect 'the manager mod states the no-write block reason' '[[ -f "$cc_manager_mod" && "$cc_manager_reason" == *"never edits files"* ]]'

# Restart reuses the saved command bytes (mod included) and the Command Code brief.
: >"$LOG"
cc_term=$(sed -n 's/^terminal=//p' "$HOME/.herdr/crew/config-fixture/config-fixture-t22-driver.meta")
cc_saved=$(cat "$HOME/.herdr/crew/config-fixture/config-fixture-t22-driver.cmd")
printf 'working\nnull\nworking\nworking\nworking\n' >"$STATE/get-seq.$cc_term"
launch restart config-fixture-t22-driver
expect 'restart types the saved Command Code command bytes including --mod' '[[ $rc == 0 ]] && jq -se --arg term "$cc_term" --arg command "$cc_saved" '\''any(.[]; . == ["hc","send",$term,$command])'\'' "$LOG" >/dev/null && [[ "$cc_saved" == *--mod* ]]'
expect 'the pinned command keeps the model and effort bytes' '[[ "$cc_saved" == *"--model deepseek/deepseek-v4.1-flash"* && "$cc_saved" == *"--effort high"* ]]'
cc_saved_mod=$(command_flag_value "$cc_saved" --mod 2>/dev/null || true)
expect 'the mod named by the saved command still exists after restart' '[[ -n "$cc_saved_mod" && -f "$cc_saved_mod" && "$cc_saved_mod" == "$cc_driver_mod" ]]'
cc_brief=$(cat "$HOME/.herdr/crew/config-fixture/config-fixture-t22-driver.brief" 2>/dev/null || true)
expect 'the Command Code brief carries its guidance and not the Claude hook sentence' '[[ "$cc_brief" == *"Command Code runtime"* && "$cc_brief" == *"per-session native mod"* && "$cc_brief" != *"A hook warns you"* ]]'
cc_restart_command=$(jq -sr --arg term "$cc_term" '[.[] | select(.[0:3] == ["hc","send",$term] and .[3] != "/exit") | .[3]][0]' "$LOG")
expect 'Command Code carries no inline policy: the mod is the policy carrier' '! policy_from_command "$cc_restart_command" >/dev/null 2>&1'
expect 'no launch started a Command Code session' '! grep -q unsupported "$STATE/cmd.log"'

(( fails == 0 )) || { echo "$fails checks failed"; exit 1; }
echo 'ALL PASS'
