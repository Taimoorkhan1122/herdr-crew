#!/usr/bin/env bash
# First-use launch must complete a partial baseline before loading definitions.
fixture=$(mktemp)
sed -n '1,88p' "$(dirname "$0")/dry-run.sh" > "$fixture"
source "$fixture"
rm "$fixture"
mkdir -p "$REPO/.herdr-crew"
printf 'keep me\n' > "$REPO/.herdr-crew/custom.txt"
rc=0
printf 'inspect this\n' | "$CREW" launch investigator - > "$TMP/partial.out" 2>&1 || rc=$?
if [[ "$rc" == 0 && -f "$REPO/.herdr-crew/agents/investigator/agent.json" ]] && cmp -s "$REPO/.herdr-crew/custom.txt" <(printf 'keep me\n'); then
  echo 'PASS: first launch completes partial baseline and preserves customization'
else
  cat "$TMP/partial.out"
  printf 'FAIL: partial baseline launch (exit %s)\n' "$rc"
  exit 1
fi
