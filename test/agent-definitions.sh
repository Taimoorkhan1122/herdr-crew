#!/bin/bash
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/crew-definitions.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
[[ -f "$ROOT/lib/agent-definitions.sh" ]] || fail 'definition registry is missing'
. "$ROOT/lib/agent-definitions.sh"
definitions_load "$ROOT" || fail 'baseline definitions load'
(cd "$ROOT" && shasum -a 256 -c test/fixtures/agent-definitions.sha256 >/dev/null) || fail 'migrated agent baseline differs from the reviewed fixture'
for id in crew-lead crew-manager crew-member crew-inspector code-reviewer driver investigator navigator planner qa-bug-reproducer qa-bug-triager tester; do
  agent_definition "$id" | jq -e --arg id "$id" '.id == $id and (.description | type == "string" and length > 0)' >/dev/null || fail "$id resolves"
done
agent_definition driver | jq -e '.profile == "member"' >/dev/null || fail 'driver profile'
agent_definition inspector | jq -e '.id == "crew-inspector"' >/dev/null || fail 'profile alias'
mkdir -p "$TMP/fixture"
cp -R "$ROOT/agents" "$TMP/fixture/agents"
mkdir "$TMP/fixture/agents/payments-reviewer"
printf '%s\n' 'Payment review guidance' > "$TMP/fixture/agents/payments-reviewer/AGENTS.md"
printf '%s\n' '{"name":"payments-reviewer","description":"Review payments","profile":"inspector"}' > "$TMP/fixture/agents/payments-reviewer/agent.json"
definitions_load "$TMP/fixture" || fail 'custom inspector load'
agent_definition payments-reviewer | jq -e '.profile == "inspector" and (.instructions | contains("Payment review")) and (.disallowedTools | index("Write")) and (.profileInstructions | contains("You inspect"))' >/dev/null || fail 'custom inspector policy and guidance'
mkdir "$TMP/fixture/agents/crew-auditor"
printf '%s\n' 'Audit guidance' > "$TMP/fixture/agents/crew-auditor/AGENTS.md"
printf '%s\n' '{"name":"crew-auditor","description":"Audit","profile":"inspector"}' > "$TMP/fixture/agents/crew-auditor/agent.json"
definitions_load "$TMP/fixture" && agent_definition crew-auditor | jq -e '.profile == "inspector"' >/dev/null || fail 'non-reserved crew name'
agent_definition ../escape >/dev/null 2>&1 && fail 'traversal accepted'
printf 'untouched\n' > "$TMP/sentinel"
cp "$TMP/fixture/agents/payments-reviewer/agent.json" "$TMP/good.json"
reject() { if definitions_load "$TMP/fixture" >/dev/null 2>&1; then fail "$1 accepted"; fi; cmp -s "$TMP/sentinel" <(printf 'untouched\n') || fail 'sentinel changed'; cp "$TMP/good.json" "$TMP/fixture/agents/payments-reviewer/agent.json"; }
printf '%s\n' '{"name":"wrong","description":"Review","profile":"inspector"}' > "$TMP/fixture/agents/payments-reviewer/agent.json"; reject 'mismatched name'
printf '%s\n' '{"name":"payments-reviewer","description":"Review","profile":"root"}' > "$TMP/fixture/agents/payments-reviewer/agent.json"; reject 'unknown profile'
printf '%s\n' '{"name":"payments-reviewer","description":"Review","profile":"inspector","tools":["Write"]}' > "$TMP/fixture/agents/payments-reviewer/agent.json"; reject 'job policy override'
printf '%s\n' '{"name":"payments-reviewer","description":"Review","profile":"inspector","extra":true}' > "$TMP/fixture/agents/payments-reviewer/agent.json"; reject 'unknown field'
printf '%s\n' '{"name":"payments-reviewer","description":"Review","profile":"inspector","skills":[42]}' > "$TMP/fixture/agents/payments-reviewer/agent.json"; reject 'invalid list values'
printf '%s\n' '{"name":"payments-reviewer","description":"Review","profile":"inspector","skills":null}' > "$TMP/fixture/agents/payments-reviewer/agent.json"; reject 'null list'
printf '%s\n' '{bad' > "$TMP/fixture/agents/payments-reviewer/agent.json"; reject 'malformed JSON'
cat "$TMP/good.json" "$TMP/good.json" > "$TMP/fixture/agents/payments-reviewer/agent.json"; reject 'JSON stream'
rm "$TMP/fixture/agents/payments-reviewer/agent.json"
ln -s "$TMP/good.json" "$TMP/fixture/agents/payments-reviewer/agent.json"
if definitions_load "$TMP/fixture" >/dev/null 2>&1; then fail 'metadata symlink accepted'; fi
rm "$TMP/fixture/agents/payments-reviewer/agent.json"
cp "$TMP/good.json" "$TMP/fixture/agents/payments-reviewer/agent.json"
rm "$TMP/fixture/agents/payments-reviewer/AGENTS.md"
if definitions_load "$TMP/fixture" >/dev/null 2>&1; then fail 'missing instructions accepted'; fi
printf 'PASS: definition registry and validation\n'
