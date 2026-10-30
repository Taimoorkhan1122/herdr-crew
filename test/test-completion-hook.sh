#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOOK="$ROOT/hooks/task-complete.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir "$TMP/state"
export COMPLETION_LOG="$TMP/log" COMPLETION_FAIL="$TMP/fail"
cat > "$TMP/send" <<'SEND'
#!/usr/bin/env bash
[[ ! -e "$COMPLETION_FAIL" ]] || exit 1
printf '%s\t%s\n' "$1" "$2" >> "$COMPLETION_LOG"
SEND
chmod +x "$TMP/send"
failures=0
check() { if "$@"; then printf 'ok: %s\n' "$description"; else printf 'FAIL: %s\n' "$description" >&2; failures=$((failures + 1)); fi; }
result() { jq -nc --arg a "$1" --arg t "$2" --arg s "$3" --arg n "$4" '{agent:$a,task:$t,status:$s,note:$n}' > "$TMP/result.json"; }
invoke() { /bin/bash "$HOOK" "$TMP/result.json" worker T7 coordinator "$TMP/state" "$TMP/send"; }
result worker T7 review 'verified: evidence.txt'
invoke; rc=$?
description='valid review reports to coordinator'; check bash -c '[[ $1 == 0 ]] && [[ $(wc -l < "$2" | tr -d " ") == 1 ]] && rg -q "^coordinator.*worker.*T7.*review.*verified: evidence.txt" "$2"' _ "$rc" "$COMPLETION_LOG"
invoke; rc=$?
description='duplicate result does not send twice'; check bash -c '[[ $1 == 0 && $(wc -l < "$2" | tr -d " ") == 1 ]]' _ "$rc" "$COMPLETION_LOG"
result worker T7 blocked 'waiting for evidence'
touch "$COMPLETION_FAIL"
invoke; rc=$?
description='failed delivery is reported'; check test "$rc" -ne 0
rm "$COMPLETION_FAIL"
invoke; rc=$?
description='failed delivery can be retried'; check bash -c '[[ $1 == 0 && $(wc -l < "$2" | tr -d " ") == 2 ]] && rg -q "blocked.*waiting for evidence" "$2"' _ "$rc" "$COMPLETION_LOG"
result other T7 review 'wrong agent'
invoke; rc=$?
description='mismatched agent is refused'; check test "$rc" -ne 0
result worker T8 review 'wrong task'
invoke; rc=$?
description='mismatched task is refused'; check test "$rc" -ne 0
result worker T7 invalid 'bad status'
invoke; rc=$?
description='unknown status is refused'; check test "$rc" -ne 0
printf '%s\n' '{"agent":"worker"}' '{"agent":"worker"}' > "$TMP/result.json"
invoke; rc=$?
description='malformed or multiple JSON values are refused'; check test "$rc" -ne 0
description='invalid evidence sends no messages'; check bash -c '[[ $(wc -l < "$1" | tr -d " ") == 2 ]]' _ "$COMPLETION_LOG"
result worker T7 review 'parallel delivery'
for i in 1 2 3 4 5 6; do invoke > "$TMP/out-$i" 2>&1 & done
wait
description='concurrent callbacks send once'; check bash -c '[[ $(wc -l < "$1" | tr -d " ") == 3 ]]' _ "$COMPLETION_LOG"
if (( failures )); then printf '%s failures\n' "$failures" >&2; exit 1; fi
printf 'All completion hook checks passed\n'
