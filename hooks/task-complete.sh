#!/usr/bin/env bash
# Invoke: task-complete.sh RESULT EXPECT_AGENT EXPECT_TASK COORDINATOR STATE_DIR DELIVER
# DELIVER receives coordinator and message; exit 0 means delivered or durably queued.
[[ $# == 6 ]] || exit 1
result=$1 expected_agent=$2 expected_task=$3 coordinator=$4 state=$5 deliver=$6
[[ -f "$result" && ! -L "$result" && -d "$state" && ! -L "$state" && -x "$deliver" ]] || exit 1
[[ "$expected_agent" =~ ^[a-zA-Z0-9_-]+$ && "$expected_task" =~ ^T[0-9]+$ && "$coordinator" =~ ^[a-zA-Z0-9_-]+$ ]] || exit 1
evidence=$(jq -sc --arg agent "$expected_agent" --arg task "$expected_task" '
  if length == 1 and (.[0] | type == "object") then .[0] else error("one result required") end
  | select((keys | sort) == ["agent", "note", "status", "task"])
  | select(.agent == $agent and .task == $task)
  | select(.status == "review" or .status == "blocked" or .status == "done")
  | select((.note | type) == "string" and (.note | length) > 0)
' "$result" 2>/dev/null) || exit 1
[[ -n "$evidence" ]] || exit 1
key=$(printf '%s\n%s' "$coordinator" "$evidence" | shasum -a 256 | cut -d ' ' -f 1)
[[ "$key" =~ ^[a-f0-9]{64}$ ]] || exit 1
marker="$state/completion-$key"
[[ ! -e "$marker" && ! -L "$marker" ]] || exit 0
lock="$state/completion-$key.lock"
mkdir "$lock" 2>/dev/null || exit 1
trap 'rmdir "$lock" 2>/dev/null || true' EXIT
[[ ! -e "$marker" && ! -L "$marker" ]] || exit 0
status=$(jq -r '.status' <<<"$evidence")
note=$(jq -r '.note' <<<"$evidence")
"$deliver" "$coordinator" "$expected_agent $expected_task $status: $note" || exit 1
mkdir "$marker" 2>/dev/null || exit 1
exit 0
