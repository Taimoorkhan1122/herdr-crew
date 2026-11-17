#!/usr/bin/env bash
# Doctor command: hermetic checks on the launcher seam. Fake integrations only;
# no live Herdr, agents or tasks. Assert user-visible outcomes: reported checks,
# their status and fix text, the verdict, the exit code.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fixtures/launcher-setup.sh"

pass() { printf 'PASS: %s\n' "$1"; }
flunk() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
in_out() { [[ "$3" == *"$2"* ]] || flunk "$1: output missing '$2': $3"; }

# The fixture HOME starts without persona skills: satisfy the installer's
# discovery with stub skill directories, plugin records and AXI tools on PATH,
# so the doctor's ready path has every requirement present.
mkdir -p "$HOME/.claude/plugins"
printf '%s\n' '{"plugins":{"caveman@caveman":{},"ponytail@ponytail":{}}}' >"$HOME/.claude/plugins/installed_plugins.json"
for _ in 1 2 3; do
  out=$("$ROOT/bin/install-skills" --check 2>&1) && break
  while IFS= read -r n; do
    [[ -n "$n" ]] || continue
    if [[ "$n" == *:* ]]; then continue; fi
    mkdir -p "$HOME/.claude/skills/$n"; : >"$HOME/.claude/skills/$n/SKILL.md"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE/$n"; chmod +x "$FAKE/$n"
  done < <(printf '%s\n' "$out" | awk '/MISSING|BLOCKED/{print $1}')
done
"$ROOT/bin/install-skills" --check >/dev/null 2>&1 || flunk "fixture: installer --check still fails"
ln -s "$ROOT/bin/crew" "$FAKE/herdr-crew"

# 1. Ready path: every required tool present on the fixture PATH; verdict last; exit 0.
out=$("$CREW" doctor) || flunk "ready: doctor exited non-zero"
in_out "ready: git ok" "git: ok" "$out"
in_out "ready: jq ok" "jq: ok" "$out"
in_out "ready: tsk ok" "tsk: ok" "$out"
in_out "ready: hc ok" "hc: ok" "$out"
in_out "ready: herdr-app ok" "herdr-app: ok" "$out"
in_out "ready: app window ok" "app window: ok" "$out"
in_out "ready: required skills ok" "required skills: ok" "$out"
[[ "$out" == *'doctor: ready to launch a crew.' ]] || flunk "ready: verdict missing: $out"
[[ "$out" == *'doctor: ready'* || "$out" != *missing* ]] || flunk "ready: unexpected missing line: $out"
pass "ready: verdict and exit"

# 2. Read-only proof: the doctor made no fake runtime, app, tsk or git mutating call.
[[ ! -s "$LOG" ]] || flunk "read-only: fake call log not empty: $(cat "$LOG")"
pass "read-only: no recorded calls"

# 3. --dry-run prints the same output, because the doctor makes no mutating call.
out2=$("$CREW" --dry-run doctor) || flunk "dry-run: exited non-zero"
[[ "$out" == "$out2" ]] || flunk "dry-run: output differs"
pass "dry-run: identical output"

# 4. Missing tools: symlink-farm PATH that really lacks jq, tsk, hc, herdr-app.
# Every gap is reported in one run, each with the launcher's fix text, exit 1.
FARM="$TMP/doctor-farm"; mkdir -p "$FARM"
( IFS=:; for d in $PATH; do for f in "$d"/*; do b=${f##*/}; case "$b" in jq|tsk|hc|herdr-app) ;; *) ln -s "$f" "$FARM/$b" 2>/dev/null || true ;; esac; done; done )
rc=0; out=$(env PATH="$FARM" "$CREW" doctor 2>&1) || rc=$?
[[ "$rc" == 1 ]] || flunk "missing: rc=$rc"
in_out "missing: jq reported" "jq: missing (install: brew install jq)" "$out"
in_out "missing: tsk reported" "tsk: missing (install: brew install smarzban/tap/tsk)" "$out"
in_out "missing: hc reported" "hc: missing (install herdr-core: https://herdr.dev/download)" "$out"
in_out "missing: herdr-app reported" "herdr-app: missing (install the Herdr desktop app: https://herdr.dev/download)" "$out"
in_out "missing: git still ok" "git: ok" "$out"
in_out "missing: verdict" "doctor: not ready (4 missing)" "$out"
pass "missing: all gaps in one pass"

# 5. --json parses and agrees with the human verdict and exit code, ready and missing.
j=$("$CREW" doctor --json) || flunk "json ready: exited non-zero"
jq -e '.verdict == "ready" and .missing == 0 and (.checks | length == 17) and .not_checked == "credentials and model access" and all(.checks[]; (.name|type)=="string" and (.status|type)=="string")' <<<"$j" >/dev/null || flunk "json ready: wrong document: $j"
rc=0; j=$(env PATH="$FARM" "$CREW" doctor --json) || rc=$?
[[ "$rc" == 1 ]] || flunk "json missing: rc=$rc"
jq -e '.verdict == "not ready" and .missing == 4 and ([.checks[] | select(.status == "missing") | .name] == ["jq","tsk","hc","herdr-app"]) and ([.checks[] | select(.status == "missing") | .fix] | all(. != ""))' <<<"$j" >/dev/null || flunk "json missing: wrong document: $j"
pass "json: parses and agrees"

# 6. Help, usage and completion know the doctor.
h=$("$CREW" help doctor) || flunk "help doctor: exited non-zero"
in_out "help doctor: usage" "USAGE" "$h"
in_out "help doctor: json option" "--json" "$h"
h=$("$CREW" doctor --help) || flunk "doctor --help: exited non-zero"
in_out "doctor --help: usage" "USAGE" "$h"
"$CREW" completion bash | grep -q 'doctor' || flunk "completion bash: no doctor"
"$CREW" completion zsh | grep -q 'doctor' || flunk "completion zsh: no doctor"
pass "help and completion"

# 7. Invalid arguments fail through the launcher's error path, naming the valid options.
rc=0; out=$("$CREW" doctor extra 2>&1) || rc=$?
[[ "$rc" == 1 && "$out" == *'usage: herdr-crew doctor [--json]'* ]] || flunk "invalid args: rc=$rc out=$out"
rc=0; out=$("$CREW" doctor --bogus 2>&1) || rc=$?
[[ "$rc" == 1 && "$out" == *'usage: herdr-crew doctor [--json]'* ]] || flunk "invalid option: rc=$rc out=$out"
pass "invalid arguments"

# 8. Runtime checks: the four ranks are validated with the defaults; a claude-only
# project configuration reports no OpenCode or Command Code.
out=$("$CREW" doctor) || flunk "runtimes: doctor exited non-zero"
in_out "runtimes: lead validated" "runtime lead: ok" "$out"
in_out "runtimes: manager validated" "runtime manager: ok" "$out"
in_out "runtimes: member validated" "runtime member: ok" "$out"
in_out "runtimes: inspector validated" "runtime inspector: ok" "$out"
printf '%s\n' '{"version":1,"roles":{"driver":{"agent":"claude"}}}' >"$REPO/.herdr-crew.json"
out=$("$CREW" doctor) || flunk "claude-only config: doctor exited non-zero"
in_out "claude-only: driver validated" "runtime driver: ok" "$out"
[[ "$out" != *OpenCode* && "$out" != *'Command Code'* ]] || flunk "claude-only: mentions unassigned runtimes: $out"
rm -f "$REPO/.herdr-crew.json"
pass "runtimes: ranks and claude-only configuration"

# 9. OpenCode assigned with a version-1 binary: the same failure text a team launch produces.
printf '%s\n' '{"version":1,"roles":{"driver":{"agent":"opencode","model":"test/model","effort":"high"}}}' >"$REPO/.herdr-crew.json"
printf '%s\n' '#!/usr/bin/env bash
case "${1:-}" in
  --version) printf "1.2.3\\n" ;;
  *) exit 99 ;;
esac' >"$FAKE/opencode"; chmod +x "$FAKE/opencode"
rc=0; out=$("$CREW" doctor 2>&1) || rc=$?
[[ "$rc" == 1 ]] || flunk "opencode v1: rc=$rc"
in_out "opencode v1: launch error text" "OpenCode 2 is required for native crew permissions (found: 1.2.3)" "$out"
in_out "opencode v1: verdict" "doctor: not ready" "$out"
rm -f "$REPO/.herdr-crew.json" "$FAKE/opencode"
pass "opencode v1: same error text as launch"

# 10. Command Code assigned below its minimum version: the same failure text a team launch produces.
printf '%s\n' '{"version":1,"roles":{"driver":{"agent":"command-code","model":"deepseek/deepseek-v4.1-flash","effort":"high"}}}' >"$REPO/.herdr-crew.json"
CREW_FAKE_CMD_VERSION=1.80.0 install_fake_cmd "$FAKE" "$STATE"
rc=0; out=$("$CREW" doctor 2>&1) || rc=$?
[[ "$rc" == 1 ]] || flunk "old cmd: rc=$rc"
in_out "old cmd: launch error text" "Command Code 1.88.5 or newer is required (found: 1.80.0)" "$out"
CREW_FAKE_CMD_VERSION=1.88.5 install_fake_cmd "$FAKE" "$STATE"
out=$("$CREW" doctor) || flunk "new cmd: doctor exited non-zero"
in_out "new cmd: driver validated" "runtime driver: ok" "$out"
rm -f "$REPO/.herdr-crew.json"
pass "command code version gate"

# 11. Missing claude runtime: the same error text a team launch produces.
FARM2="$TMP/doctor-farm2"; mkdir -p "$FARM2"
( IFS=:; for d in $PATH; do for f in "$d"/*; do b=${f##*/}; case "$b" in claude) ;; *) ln -s "$f" "$FARM2/$b" 2>/dev/null || true ;; esac; done; done )
rc=0; out=$(env PATH="$FARM2" "$CREW" doctor 2>&1) || rc=$?
[[ "$rc" == 1 ]] || flunk "no claude: rc=$rc"
in_out "no claude: launch error text" "claude not found on PATH; install it or run herdr-crew configure" "$out"
pass "missing claude runtime"

# 12. Invalid assignment in the configuration: the same error a team launch would report.
printf '%s\n' '{"version":1,"roles":{"lead":{"agent":"vim"}}}' >"$REPO/.herdr-crew.json"
rc=0; out=$("$CREW" doctor 2>&1) || rc=$?
[[ "$rc" == 1 ]] || flunk "invalid config: rc=$rc"
in_out "invalid config: validation error" "invalid agent configuration in" "$out"
rm -f "$REPO/.herdr-crew.json"
pass "invalid configuration reported"

# 13. Runtime checks made no mutating call either.
[[ ! -s "$LOG" ]] || flunk "read-only: fake call log grew: $(cat "$LOG")"
pass "read-only: still no recorded calls"

# 14. App window unreachable: herdr-app present but status fails.
touch "$STATE/no-window"
rc=0; out=$("$CREW" doctor 2>&1) || rc=$?
[[ "$rc" == 1 ]] || flunk "no window: rc=$rc"
in_out "no window: reported with launcher fix text" "app window: missing (open a Herdr app window and try again)" "$out"
rm -f "$STATE/no-window"
out=$("$CREW" doctor) || flunk "window back: doctor exited non-zero"
in_out "window back: ok again" "app window: ok" "$out"
pass "app window reachability"

# 15. herdr-app absent: the binary is reported missing and reachability is not double-reported.
rc=0; out=$(env PATH="$FARM" "$CREW" doctor 2>&1) || rc=$?
[[ "$rc" == 1 ]] || flunk "app absent: rc=$rc"
in_out "app absent: binary missing" "herdr-app: missing" "$out"
[[ "$out" != *'app window'* ]] || flunk "app absent: double report: $out"
pass "herdr-app absent skips reachability"

# 16. A missing required skill is reported through the installer's discovery, then ok again.
rm -rf "$HOME/.claude/skills/ponytail"
rc=0; out=$("$CREW" doctor 2>&1) || rc=$?
[[ "$rc" == 1 ]] || flunk "skill missing: rc=$rc"
in_out "skill missing: reported" "required skills: missing (missing: ponytail; run bin/install-skills in the herdr-crew checkout to install)" "$out"
in_out "skill missing: fix" "run bin/install-skills in the herdr-crew checkout to install" "$out"
mkdir -p "$HOME/.claude/skills/ponytail"; : >"$HOME/.claude/skills/ponytail/SKILL.md"
out=$("$CREW" doctor) || flunk "skill back: doctor exited non-zero"
in_out "skill back: ok" "required skills: ok" "$out"
pass "required skills via installer discovery"

# 17. Installation integrity, baseline state and the not-checked line.
rc=0; out=$("$CREW" doctor 2>&1) || rc=$?
[[ "$rc" == 0 ]] || flunk "integrity: rc=$rc"
in_out "integrity: launcher on PATH" "launcher: ok" "$out"
in_out "integrity: not-checked line" "credentials and model access: not checked" "$out"
in_out "integrity: baseline uninitialized is a warning" "project baseline: not initialized. the first launch initializes it" "$out"
mkdir -p "$HOME/.claude/skills/herdr-crew"; : >"$HOME/.claude/skills/herdr-crew/marker"
rc=0; out=$("$CREW" doctor 2>&1) || rc=$?
[[ "$rc" == 0 ]] || flunk "divergent install: rc=$rc"
REAL_HOME=$(cd "$HOME" && pwd -P)
in_out "divergent install: warning names the copy" "warning: skill installation (claude): resolves to $REAL_HOME/.claude/skills/herdr-crew, the launcher uses $ROOT" "$out"
rm -rf "$HOME/.claude/skills/herdr-crew"
ln -s "$ROOT" "$HOME/.claude/skills/herdr-crew"
out=$("$CREW" doctor) || flunk "linked install: doctor exited non-zero"
in_out "linked install: ok" "skill installation (claude): ok" "$out"
rm -f "$HOME/.claude/skills/herdr-crew"
"$CREW" init >/dev/null 2>&1 || flunk "baseline init: project init failed"
out=$("$CREW" doctor) || flunk "baseline init: doctor exited non-zero"
in_out "baseline init: ok" "project baseline: ok" "$out"
rm -rf "$REPO/.herdr-crew"
j=$("$CREW" doctor --json) || flunk "json not-checked: exited non-zero"
jq -e '.not_checked == "credentials and model access"' <<<"$j" >/dev/null || flunk "json not-checked: missing field"
pass "installation integrity, baseline and not-checked"

printf 'ALL PASS\n'
