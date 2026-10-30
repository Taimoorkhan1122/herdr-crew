#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOOK="$ROOT/hooks/context-limit.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" CREW_SLUG=test CREW_AGENT=worker
mkdir -p "$HOME" "$TMP/transcripts with spaces"
TRANSCRIPT="$TMP/transcripts with spaces/context.jsonl"
printf '%s\n' '{"type":"assistant","message":{"usage":{"input_tokens":10000,"cache_read_input_tokens":120000,"cache_creation_input_tokens":10000}}}' '{"type":"assistant","isSidechain":true,"message":{"usage":{"input_tokens":999}}}' > "$TRANSCRIPT"
failures=0
check() { if "$@"; then printf 'ok: %s\n' "$description"; else printf 'FAIL: %s\n' "$description" >&2; failures=$((failures + 1)); fi; }
invoke() { jq -nc --arg tr "$1" --arg sid "$2" '{transcript_path:$tr,session_id:$sid,hook_event_name:"PostToolUse"}' | /bin/bash "$HOOK"; }

out=$(invoke "$TRANSCRIPT" default); rc=$?
description='warns at default threshold with main-thread usage'; check bash -c '[[ $1 == *"Context is 140000 tokens"* && $1 == *"135000"* && $2 == 0 ]]' _ "$out" "$rc"
out=$(invoke "$TRANSCRIPT" default); rc=$?
description='warns only once per session'; check bash -c '[[ -z $1 && $2 == 0 ]]' _ "$out" "$rc"
out=$(CREW_CTX_LIMIT=150000 invoke "$TRANSCRIPT" higher); rc=$?
description='custom threshold keeps smaller usage silent'; check bash -c '[[ -z $1 && $2 == 0 ]]' _ "$out" "$rc"
out=$(CREW_CTX_LIMIT=120000 invoke "$TRANSCRIPT" lower); rc=$?
description='custom threshold is reflected in warning'; check bash -c '[[ $1 == *"120000"* && $2 == 0 ]]' _ "$out" "$rc"
out=$(invoke "$TMP/missing" missing); rc=$?
description='missing usage remains silent and successful'; check bash -c '[[ -z $1 && $2 == 0 ]]' _ "$out" "$rc"
out=$(printf 'not json' | /bin/bash "$HOOK"); rc=$?
description='malformed input stays successful and silent'; check bash -c '[[ -z $1 && $2 == 0 ]]' _ "$out" "$rc"
out=$(printf 'not json' | /bin/bash "$ROOT/bin/ctx-guard"); rc=$?
description='legacy ctx-guard delegates and stays successful'; check bash -c '[[ -z $1 && $2 == 0 ]]' _ "$out" "$rc"
out=$(invoke "$TRANSCRIPT" '../../escape'); rc=$?
description='unsafe session IDs stay silent and do not escape state directory'; check bash -c '[[ -z $1 && $2 == 0 && ! -e $3 ]]' _ "$out" "$rc" "$HOME/.herdr/escape"
for i in 1 2 3 4 5 6 7 8; do invoke "$TRANSCRIPT" concurrent > "$TMP/out-$i" & done
wait
count=$(cat "$TMP"/out-* | jq -s 'length' 2>/dev/null || printf 'invalid')
description='concurrent events emit exactly one warning'; check test "$count" = 1
if (( failures )); then printf '%s failures\n' "$failures" >&2; exit 1; fi
printf 'All context hook checks passed\n'
