#!/bin/bash
# Project agent definitions are data, never shell code.

definitions_load() {
  local root="$1" path id profile meta
  DEFINITION_ROOT=
  [[ -d "$root/agents" && ! -L "$root/agents" ]] || { printf 'invalid agents directory: %s\n' "$root" >&2; return 1; }
  for path in "$root"/agents/*; do
    [[ -e "$path" || -L "$path" ]] || continue
    id=${path##*/}
    [[ "$id" =~ ^[a-z][a-z0-9-]*$ && -d "$path" && ! -L "$path" && -f "$path/AGENTS.md" && ! -L "$path/AGENTS.md" && -f "$path/agent.json" && ! -L "$path/agent.json" ]] || { printf 'invalid agent definition: %s\n' "$id" >&2; return 1; }
    meta="$path/agent.json"
    if ! jq -e -s --arg id "$id" '
      length == 1 and (.[0] | type == "object" and
        .name == $id and (.description | type == "string" and length > 0) and
        (.profile | . == "lead" or . == "manager" or . == "member" or . == "inspector") and
        (if (["crew-lead","crew-manager","crew-member","crew-inspector"] | index($id)) then
          $id == ("crew-" + .profile) and
          (keys - ["name","description","profile","tools","disallowedTools","permissionMode","model","effort","kind","skills","axi"] | length == 0)
        else
          (keys - ["name","description","profile","skills","axi","effort"] | length == 0)
        end) and
        (. as $o | all(["tools","disallowedTools","skills","axi"][]; . as $k | ($o | has($k) | not) or ($o[$k] | type == "array" and all(.[]; type == "string")))) and
        (. as $o | all(["permissionMode","model","effort","kind"][]; . as $k | ($o | has($k) | not) or ($o[$k] | type == "string"))))
    ' "$meta" >/dev/null 2>&1; then
      printf 'invalid agent metadata: %s\n' "$id" >&2; return 1
    fi
  done
  for profile in lead manager member inspector; do
    [[ -f "$root/agents/crew-$profile/agent.json" ]] || { printf 'missing profile: %s\n' "$profile" >&2; return 1; }
  done
  DEFINITION_ROOT="$root"
}

agent_definition() {
  local id="$1" root="${DEFINITION_ROOT:-}" profile
  [[ -n "$root" && "$id" =~ ^[a-z][a-z0-9-]*$ ]] || return 1
  case "$id" in lead|manager|member|inspector) id="crew-$id" ;; esac
  # Revalidate on use so edits after discovery cannot introduce policy fields.
  definitions_load "$root" || return 1
  [[ -f "$root/agents/$id/agent.json" && ! -L "$root/agents/$id/agent.json" ]] || return 1
  profile=$(jq -r '.profile' "$root/agents/$id/agent.json") || return 1
  jq -n --slurpfile policy "$root/agents/crew-$profile/agent.json" --slurpfile job "$root/agents/$id/agent.json" \
    --rawfile profileInstructions "$root/agents/crew-$profile/AGENTS.md" --rawfile instructions "$root/agents/$id/AGENTS.md" \
    --arg id "$id" '($policy[0] + $job[0]) + {id:$id,profileInstructions:$profileInstructions,instructions:$instructions}'
}
