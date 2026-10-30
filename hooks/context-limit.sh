#!/usr/bin/env bash
# Advisory Claude hook: never block an agent if usage or state is unavailable.
input=$(cat)
field() { jq -r ".$1 // empty" <<<"$input" 2>/dev/null || true; }
tr=$(field transcript_path); sid=$(field session_id); ev=$(field hook_event_name)
limit=${CREW_CTX_LIMIT:-135000}
slug=${CREW_SLUG:-x}
[[ "$sid" =~ ^[a-zA-Z0-9_-]+$ && "$slug" =~ ^[a-zA-Z0-9_-]+$ ]] || exit 0
[[ "$ev" == PostToolUse || "$ev" == UserPromptSubmit ]] || exit 0
[[ "$limit" =~ ^[0-9]+$ && ${#limit} -le 15 ]] || exit 0
dir="$HOME/.herdr/crew/$slug"
size=0
if [[ -f "$tr" ]]; then
  size=$(tail -n 400 "$tr" | jq -r 'select(.type == "assistant" and .isSidechain != true)
    | (.message.usage // {}) | ((.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))' \
    2>/dev/null | tail -1 || true)
fi
[[ "$size" =~ ^[0-9]+$ && ${#size} -le 15 ]] || exit 0
if (( 10#$size >= 10#$limit )); then
  mkdir -p "$dir" 2>/dev/null || exit 0
  mkdir "$dir/ctx-$sid" 2>/dev/null || exit 0
  msg="Context is $size tokens, at or over the crew limit of $limit. Finish the current step only. Write your handoff with: herdr-crew handoff \"<one line status>\" <<'EOF' ... EOF (goal, done, in progress, next steps, files, task number). It is saved to $dir/handoff-${CREW_AGENT:-x}.md. Then stop and wait."
  jq -nc --arg e "$ev" --arg m "$msg" '{hookSpecificOutput: {hookEventName: $e, additionalContext: $m}}' 2>/dev/null || true
fi
exit 0
