#!/bin/bash
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/crew-installer.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/pkg/bin" "$TMP/pkg/agents/custom" "$TMP/pkg/personas" "$TMP/home"
cp "$ROOT/bin/install-skills" "$TMP/pkg/bin/install-skills"
printf '%s\n' '{"name":"custom","description":"custom","profile":"member","skills":["test-agent-skill"],"axi":["test-agent-axi"]}' > "$TMP/pkg/agents/custom/agent.json"
printf '%s\n' '---' 'name: domain' 'skills: test-domain-skill' '---' 'domain' > "$TMP/pkg/personas/domain.md"
printf '%s\n' '---' 'rank: member' 'skills: test-obsolete-job-skill' '---' 'old job' > "$TMP/pkg/personas/old-job.md"
: > "$TMP/pkg/skills.sources"
rc=0
out=$(HOME="$TMP/home" /bin/bash "$TMP/pkg/bin/install-skills" --check 2>&1) || rc=$?
[[ "$rc" == 1 && "$out" == *test-agent-skill* && "$out" == *test-agent-axi* && "$out" == *test-domain-skill* && "$out" != *test-obsolete-job-skill* ]] || { printf 'FAIL: agent and domain dependency discovery (rc=%s): %s\n' "$rc" "$out" >&2; exit 1; }
printf 'PASS: agent and domain dependency discovery\n'

# A plugin skill declared in agent metadata with a verified plugin source is
# reported like any other requirement: missing until the plugin record exists.
mkdir -p "$TMP/pkg/agents/pman"
printf '%s\n' '{"name":"pman","description":"plugin manager","profile":"manager","skills":["caveman:caveman"]}' > "$TMP/pkg/agents/pman/agent.json"
printf '%s\n' 'caveman:caveman plugin caveman@caveman' >> "$TMP/pkg/skills.sources"
rc=0
out=$(HOME="$TMP/home" /bin/bash "$TMP/pkg/bin/install-skills" --check 2>&1) || rc=$?
[[ "$rc" == 1 && "$out" == *'MISSING plugin (would run: claude plugin install caveman@caveman)'* ]] || { printf 'FAIL: plugin skill missing report (rc=%s): %s\n' "$rc" "$out" >&2; exit 1; }
printf 'PASS: plugin skill missing report\n'
mkdir -p "$TMP/home/.claude/plugins"
printf '%s\n' '{"plugins":{"caveman@caveman":{}}}' > "$TMP/home/.claude/plugins/installed_plugins.json"
rc=0
out=$(HOME="$TMP/home" /bin/bash "$TMP/pkg/bin/install-skills" --check 2>&1) || rc=$?
printf '%s\n' "$out" | grep -Eq '^caveman:caveman +ok$' || { printf 'FAIL: installed plugin report (rc=%s): %s\n' "$rc" "$out" >&2; exit 1; }
printf 'PASS: installed plugin report\n'
