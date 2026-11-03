#!/usr/bin/env bash
# Reuse the launcher suite's disposable repository and fake integrations.
source "$(cd "$(dirname "$0")/.." && pwd)/test/fixtures/launcher-setup.sh"
HOME="$TMP/home with spaces"
mkdir -p "$HOME"
export HOME
fail=0
check() { if "$@"; then printf 'PASS: %s\n' "$label"; else printf 'FAIL: %s\n' "$label"; fail=$((fail+1)); fi; }
/bin/bash "$CREW" init --json >"$TMP/init.out" 2>"$TMP/init.err" || { cat "$TMP/init.err" >&2; exit 1; }
export CREW_CTX_LIMIT=120000
cat >"$FAKE/opencode" <<'SH'
#!/usr/bin/env bash
[[ "$1" == --version ]] && { echo 2.1.2; exit 0; }
exit 0
SH
chmod +x "$FAKE/opencode"
jq '.roles.driver={agent:"opencode"}' "$REPO/.herdr-crew/config.json" >"$TMP/config.json"
mv "$TMP/config.json" "$REPO/.herdr-crew/config.json"
if ! printf 'test context\n' | /bin/bash "$CREW" launch driver - >"$TMP/launch.out" 2>"$TMP/launch.err"; then cat "$TMP/launch.err" >&2; exit 1; fi
label='launch propagates configured context threshold'; check rg -q 'CREW_CTX_LIMIT=120000' "$LOG"
name="$S-t7-driver"
crew_root=$(cd "$(dirname "$CREW")/.." && pwd)
hook_name="$S-t7-navigator"
meta="$HOME/.herdr/crew/$S/$hook_name.meta"
driver_meta="$HOME/.herdr/crew/$S/$name.meta"
saved_hook=$(sed -n 's/^context_hook=//p' "$meta")
saved_completion=$(sed -n 's/^completion_hook=//p' "$meta")
context_command=$(printf '%q' "$saved_hook")
settings=$(sed -n '/^\["herdr-app"/p' "$LOG" | jq -sr '[.[] | select(.[1:3] == ["do","pane.split"]) | .[-1] | fromjson | . as $a | ($a | index("--settings")) as $i | select($i != null) | $a[$i+1] | fromjson][0]')
label='session registers snapshotted project hook'; check jq -e --arg command "$context_command" '.hooks.PostToolUse[0].hooks[0].command == $command' <<<"$settings"
label='launch snapshots context hook bytes'; check cmp -s "$REPO/.herdr-crew/hooks/context-limit.sh" "$saved_hook"
label='launch snapshots completion hook bytes'; check cmp -s "$REPO/.herdr-crew/hooks/task-complete.sh" "$saved_completion"
label='OpenCode stores only an explicit completion snapshot'; check bash -c '[[ -z $(sed -n "s/^context_hook=//p" "$1") && -f $(sed -n "s/^completion_hook=//p" "$1") ]]' _ "$driver_meta"
printf '\n# changed after launch\n' >> "$REPO/.herdr-crew/hooks/context-limit.sh"
printf '\n# changed after launch\n' >> "$REPO/.herdr-crew/hooks/task-complete.sh"
label='active session hook stays pinned after project edit'; check bash -c '[[ -f "$1" ]] && ! rg -q "changed after launch" "$1"' _ "$saved_hook"
label='active session completion hook stays pinned'; check bash -c '[[ -f "$1" ]] && ! rg -q "changed after launch" "$1"' _ "$saved_completion"
restart_term=$(sed -n 's/^terminal=//p' "$meta")
printf 'working\nnull\nworking\nworking\nworking\n' >"$STATE/get-seq.$restart_term"
/bin/bash "$CREW" restart "$hook_name" >"$TMP/restart.out" 2>"$TMP/restart.err" || { cat "$TMP/restart.err" >&2; exit 1; }
label='restart keeps the same context hook snapshot'; check bash -c '[[ $(sed -n "s/^context_hook=//p" "$1") == "$2" ]]' _ "$meta" "$saved_hook"
label='restart keeps the same completion hook snapshot'; check bash -c '[[ $(sed -n "s/^completion_hook=//p" "$1") == "$2" ]]' _ "$meta" "$saved_completion"
export CREW_SLUG="$S" CREW_AGENT="$name" CREW_TASK=T7 CREW_MANAGER="$S-manager" CREW_REPO="$REPO"
manager_term=t1
printf 'terminal=%s\n' "$manager_term" >"$HOME/.herdr/crew/$S/$S-manager.meta"
jq '.status = "idle"' "$STATE/term.$manager_term" >"$STATE/manager.tmp"; mv "$STATE/manager.tmp" "$STATE/term.$manager_term"
: > "$LOG"
/bin/bash "$CREW" mark T7 review 'checked evidence' >"$TMP/mark.out" 2>"$TMP/mark.err" || true
label='mark saves validated result'; check jq -e --arg name "$name" '.agent == $name and .task == "T7" and .status == "review" and .note == "checked evidence"' "$HOME/.herdr/crew/$S/$name.result.json"
label='review result notifies coordinator'; check rg -q "checked evidence" "$STATE/sent.$manager_term"
/bin/bash "$CREW" mark T7 review 'checked evidence' >"$TMP/mark2.out" 2>"$TMP/mark2.err" || true
label='repeated result notifies once'; check bash -c '[[ $(rg -c "checked evidence" "$1") == 1 ]]' _ "$STATE/sent.$manager_term"
label='review notification does not mark task done'; check bash -c '! rg -q "tsk status T7 done" "$1"' _ "$LOG"
mv "$STATE/term.$manager_term" "$STATE/manager.saved"
no_receiver_rc=0
"$crew_root/bin/crew-say" "$S-manager" 'no receiver' >"$TMP/no-receiver.out" 2>"$TMP/no-receiver.err" || no_receiver_rc=$?
label='undelivered say is reported as failure'; check bash -c '[[ $1 != 0 ]] && rg -q "NOT delivered" "$2"' _ "$no_receiver_rc" "$TMP/no-receiver.err"
mv "$STATE/manager.saved" "$STATE/term.$manager_term"
jq '.status = "blocked"' "$STATE/term.$manager_term" >"$STATE/manager.tmp"; mv "$STATE/manager.tmp" "$STATE/term.$manager_term"
touch "$STATE/fail-notify"
/bin/bash "$CREW" mark T7 blocked 'waiting for evidence' >"$TMP/mark-failed.out" 2>"$TMP/mark-failed.err" || true
label='failed delivery is reported'; check rg -q 'completion notification failed' "$TMP/mark-failed.err"
label='failed delivery retains validated result'; check jq -e --arg name "$name" '.agent == $name and .task == "T7" and .status == "blocked" and .note == "waiting for evidence"' "$HOME/.herdr/crew/$S/$name.result.json"
rm "$STATE/fail-notify"
jq ' .status = "idle" ' "$STATE/term.$manager_term" >"$STATE/manager.tmp"; mv "$STATE/manager.tmp" "$STATE/term.$manager_term"
/bin/bash "$CREW" mark T7 blocked 'waiting for evidence' >"$TMP/mark-retry.out" 2>"$TMP/mark-retry.err" || true
label='blocked result retries notification'; check bash -c '[[ $(rg -c "waiting for evidence" "$1") == 1 ]]' _ "$STATE/sent.$manager_term"
label='blocked result does not mark task done'; check bash -c '! rg -q "tsk status T7 done" "$1"' _ "$LOG"
printf '%s failure(s)\n' "$fail"
(( fail == 0 ))
