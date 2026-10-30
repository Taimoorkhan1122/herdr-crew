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
