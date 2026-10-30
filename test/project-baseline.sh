#!/bin/bash
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/crew-baseline.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT
fail=0
check() { if "$@"; then printf 'PASS: %s\n' "$label"; else printf 'FAIL: %s\n' "$label"; fail=$((fail+1)); fi; }
run() { (cd "$TMP/project space" && /bin/bash "$ROOT/bin/crew" "$@") >"$TMP/out" 2>"$TMP/err"; }
mkdir "$TMP/project space"
git -C "$TMP/project space" init -q
git -C "$TMP/project space" -c user.name=Test -c user.email=t@example.test commit --allow-empty -qm init
label='init help works without runtimes'; check run init --help
label='dry-run init does not write'; check run --dry-run init --json
label='dry-run leaves no project directory'; check test ! -e "$TMP/project space/.herdr-crew"
printf '%s\n' '{"version":1,"roles":{"driver":{"agent":"claude","model":"literal"}}}' > "$TMP/project space/.herdr-crew.json"
cp "$TMP/project space/.herdr-crew.json" "$TMP/legacy"
label='init succeeds with JSON'; check run init --json
label='JSON result has expected shape'; check jq -e '.action == "init" and (.changed|type == "array") and (.skipped|type == "array")' "$TMP/out"
label='valid legacy is imported'; check cmp -s "$TMP/legacy" "$TMP/project space/.herdr-crew/config.json"
label='legacy remains unchanged'; check cmp -s "$TMP/legacy" "$TMP/project space/.herdr-crew.json"
label='baseline manifest exists'; check test -f "$TMP/project space/.herdr-crew/baseline.json"
if test -f "$TMP/project space/.herdr-crew/agents/driver/AGENTS.md"; then printf 'custom\n' > "$TMP/project space/.herdr-crew/agents/driver/AGENTS.md"; fi
label='repeated init succeeds'; check run init --json
label='customized file retained'; check sh -c 'test "$(cat "$1")" = custom' sh "$TMP/project space/.herdr-crew/agents/driver/AGENTS.md"
label='upgrade preview succeeds'; check run upgrade --json
label='plain preview includes reviewed hash'; run upgrade; check rg -q 'agents/driver/AGENTS.md +[0-9a-f]{64}' "$TMP/out"
label='preview preserves customized file'; check sh -c 'test "$(cat "$1")" = custom' sh "$TMP/project space/.herdr-crew/agents/driver/AGENTS.md"
label='unsafe upgrade rejected'; if run upgrade --apply ../outside; then echo 'FAIL: unsafe upgrade rejected'; fail=$((fail+1)); else echo 'PASS: unsafe upgrade rejected'; fi
label='apply without reviewed hash rejected'; if run upgrade --apply agents/driver/AGENTS.md --json; then echo 'FAIL: apply without hash rejected'; fail=$((fail+1)); else echo 'PASS: apply without hash rejected'; fi
label='source drift rejected'; if run upgrade --apply agents/driver/AGENTS.md --expect 0000000000000000000000000000000000000000000000000000000000000000 --expect-target 0000000000000000000000000000000000000000000000000000000000000000 --json; then echo 'FAIL: source drift rejected'; fail=$((fail+1)); else echo 'PASS: source drift rejected'; fi
run upgrade --json
expected=$(jq -r '.sourceHashes["agents/driver/AGENTS.md"]' "$TMP/out")
expected_target=$(jq -r '.targetHashes["agents/driver/AGENTS.md"]' "$TMP/out")
printf 'changed after preview\n' > "$TMP/project space/.herdr-crew/agents/driver/AGENTS.md"
if run upgrade --apply agents/driver/AGENTS.md --expect "$expected" --expect-target "$expected_target" --json; then echo 'FAIL: target drift rejected'; fail=$((fail+1)); else echo 'PASS: target drift rejected'; fi
label='target drift preserved'; check sh -c 'test "$(cat "$1")" = "changed after preview"' sh "$TMP/project space/.herdr-crew/agents/driver/AGENTS.md"
printf 'custom\n' > "$TMP/project space/.herdr-crew/agents/driver/AGENTS.md"
printf 'user data\n' > "$TMP/project space/.herdr-crew/.manifest.tmp"
label='selected upgrade succeeds'; check run upgrade --apply agents/driver/AGENTS.md --expect "$expected" --expect-target "$expected_target" --json
label='unrelated manifest file retained'; check sh -c 'test "$(cat "$1")" = "user data"' sh "$TMP/project space/.herdr-crew/.manifest.tmp"
backup_found=0
for backup in "$TMP/project space"/.herdr-crew-stage.*.old; do
  if [[ -f "$backup/agents/driver/AGENTS.md" && "$(cat "$backup/agents/driver/AGENTS.md")" == custom ]]; then backup_found=1; fi
done
label='original customized directory is retained'; check test "$backup_found" = 1
label='selected upgrade restores baseline'; check cmp -s "$ROOT/agents/driver/AGENTS.md" "$TMP/project space/.herdr-crew/agents/driver/AGENTS.md"
rm "$TMP/project space/.herdr-crew/personas/security-paranoid.md"
run upgrade --json
missing_source=$(jq -r '.sourceHashes["personas/security-paranoid.md"]' "$TMP/out")
missing_target=$(jq -r '.targetHashes["personas/security-paranoid.md"]' "$TMP/out")
label='preview records absent target'; check test "$missing_target" = absent
label='apply accepts reviewed absent target'; check run upgrade --apply personas/security-paranoid.md --expect "$missing_source" --expect-target "$missing_target" --json
label='absent target restored'; check cmp -s "$ROOT/personas/security-paranoid.md" "$TMP/project space/.herdr-crew/personas/security-paranoid.md"
mkdir "$TMP/shims"
cat > "$TMP/shims/cp" <<'SH'
#!/bin/bash
/bin/cp "$@" || exit $?
if [[ "${1:-}" == -R && "${2:-}" == */.herdr-crew/. ]]; then
  : > "$COPY_READY"
  while [[ ! -e "$COPY_CONTINUE" ]]; do sleep 0.05; done
fi
SH
chmod +x "$TMP/shims/cp"
printf 'unrelated before\n' > "$TMP/project space/.herdr-crew/notes"
printf 'custom again\n' > "$TMP/project space/.herdr-crew/agents/driver/AGENTS.md"
run upgrade --json
expected=$(jq -r '.sourceHashes["agents/driver/AGENTS.md"]' "$TMP/out")
expected_target=$(jq -r '.targetHashes["agents/driver/AGENTS.md"]' "$TMP/out")
(cd "$TMP/project space" && PATH="$TMP/shims:$PATH" COPY_READY="$TMP/ready" COPY_CONTINUE="$TMP/continue" /bin/bash "$ROOT/bin/crew" upgrade --apply agents/driver/AGENTS.md --expect "$expected" --expect-target "$expected_target" --json) >"$TMP/concurrent-out" 2>"$TMP/concurrent-err" &
pid=$!
for i in {1..200}; do [[ ! -e "$TMP/ready" ]] || break; sleep 0.05; done
if [[ -e "$TMP/ready" ]]; then printf 'unrelated edited\n' > "$TMP/project space/.herdr-crew/notes"; fi
: > "$TMP/continue"
if wait "$pid"; then echo 'FAIL: unrelated concurrent edit rejected'; fail=$((fail+1)); else echo 'PASS: unrelated concurrent edit rejected'; fi
label='unrelated concurrent edit preserved'; check sh -c 'test "$(cat "$1")" = "unrelated edited"' sh "$TMP/project space/.herdr-crew/notes"
label='unsupported option rejected'; if run init --bad; then echo 'FAIL: unsupported option rejected'; fail=$((fail+1)); else echo 'PASS: unsupported option rejected'; fi
mkdir "$TMP/invalid"
printf '{}\n{}\n' > "$TMP/invalid/.herdr-crew.json"
if (cd "$TMP/invalid" && /bin/bash "$ROOT/bin/crew" init --json) >"$TMP/out" 2>"$TMP/err"; then echo 'FAIL: invalid legacy refused'; fail=$((fail+1)); else echo 'PASS: invalid legacy refused'; fi
label='invalid legacy creates no directory'; check test ! -e "$TMP/invalid/.herdr-crew"
mkdir -p "$TMP/badconfig/.herdr-crew/config.json"
if (cd "$TMP/badconfig" && /bin/bash "$ROOT/bin/crew" init --json) >"$TMP/out" 2>"$TMP/err"; then echo 'FAIL: config directory refused'; fail=$((fail+1)); else echo 'PASS: config directory refused'; fi
label='config directory untouched'; check test -d "$TMP/badconfig/.herdr-crew/config.json"
mkdir "$TMP/partial" "$TMP/partial/.herdr-crew"
printf '%s\n' '{"version":1,"roles":{"driver":{"agent":"claude","model":"legacy-only"}}}' > "$TMP/partial/.herdr-crew.json"
(cd "$TMP/partial" && /bin/bash "$ROOT/bin/crew" init --json) >"$TMP/out" 2>"$TMP/err"
label='existing directory does not import legacy'; check jq -e '.roles == {}' "$TMP/partial/.herdr-crew/config.json"
mkdir -p "$TMP/partial-agent/.herdr-crew"
printf '%s\n' '{"version":1,"roles":{"driver":{"agent":"claude","model":"keep"}}}' > "$TMP/partial-agent/.herdr-crew/config.json"
cp "$TMP/partial-agent/.herdr-crew/config.json" "$TMP/partial-config"
if (cd "$TMP/partial-agent" && /bin/bash "$ROOT/bin/crew" init --json) >"$TMP/out" 2>"$TMP/err"; then echo 'PASS: partial project validates completed definitions'; else echo 'FAIL: partial project validates completed definitions'; fail=$((fail+1)); fi
label='partial project preserves config bytes'; check cmp -s "$TMP/partial-config" "$TMP/partial-agent/.herdr-crew/config.json"
label='partial project gets driver definition'; check test -f "$TMP/partial-agent/.herdr-crew/agents/driver/agent.json"
mkdir -p "$TMP/partial-custom/.herdr-crew/agents/custom-reviewer"
printf '%s\n' '{"name":"custom-reviewer","description":"Custom review","profile":"inspector"}' > "$TMP/partial-custom/.herdr-crew/agents/custom-reviewer/agent.json"
printf 'Custom guidance\n' > "$TMP/partial-custom/.herdr-crew/agents/custom-reviewer/AGENTS.md"
printf '%s\n' '{"version":1,"roles":{"driver":{"agent":"claude"},"custom-reviewer":{"agent":"claude"}}}' > "$TMP/partial-custom/.herdr-crew/config.json"
if (cd "$TMP/partial-custom" && /bin/bash "$ROOT/bin/crew" --dry-run init --json) >"$TMP/out" 2>"$TMP/err"; then echo 'PASS: dry-run accepts custom and baseline roles'; else echo 'FAIL: dry-run accepts custom and baseline roles'; fail=$((fail+1)); fi
label='dry-run leaves partial definitions untouched'; check test ! -e "$TMP/partial-custom/.herdr-crew/agents/driver"
if (cd "$TMP/partial-custom" && /bin/bash "$ROOT/bin/crew" init --json) >"$TMP/out" 2>"$TMP/err"; then echo 'PASS: partial custom and baseline roles accepted'; else echo 'FAIL: partial custom and baseline roles accepted'; fail=$((fail+1)); fi
label='custom agent retained'; check sh -c 'test "$(cat "$1")" = "Custom guidance"' sh "$TMP/partial-custom/.herdr-crew/agents/custom-reviewer/AGENTS.md"
mkdir -p "$TMP/partial-invalid/.herdr-crew"
printf '%s\n' '{"version":1,"roles":{"unknown-agent":{"agent":"claude"}}}' > "$TMP/partial-invalid/.herdr-crew/config.json"
cp "$TMP/partial-invalid/.herdr-crew/config.json" "$TMP/invalid-config"
if (cd "$TMP/partial-invalid" && /bin/bash "$ROOT/bin/crew" init --json) >"$TMP/out" 2>"$TMP/err"; then echo 'FAIL: unknown role in partial config rejected'; fail=$((fail+1)); else echo 'PASS: unknown role in partial config rejected'; fi
label='invalid partial config unchanged'; check cmp -s "$TMP/invalid-config" "$TMP/partial-invalid/.herdr-crew/config.json"
label='invalid partial project gets no definitions'; check test ! -e "$TMP/partial-invalid/.herdr-crew/agents"
mkdir "$TMP/link" "$TMP/external"
ln -s "$TMP/external" "$TMP/link/.herdr-crew"
if (cd "$TMP/link" && /bin/bash "$ROOT/bin/crew" init --json) >"$TMP/out" 2>"$TMP/err"; then echo 'FAIL: symlink destination refused'; fail=$((fail+1)); else echo 'PASS: symlink destination refused'; fi
label='symlink target untouched'; check test -z "$(ls -A "$TMP/external")"
git -C "$TMP/project space" worktree add -qb other "$TMP/worker space"
(cd "$TMP/worker space" && /bin/bash "$ROOT/bin/crew" init --json) >"$TMP/out" 2>"$TMP/err"
label='linked worktree uses primary project'; check jq -e --arg root "$(git -C "$TMP/project space" rev-parse --show-toplevel)" '.project == $root' "$TMP/out"
label='linked worktree has no own configuration'; check test ! -e "$TMP/worker space/.herdr-crew"
cp "$TMP/project space/.herdr-crew/baseline.json" "$TMP/provenance"
printf '{}\n{}\n' > "$TMP/project space/.herdr-crew/baseline.json"
if run init --json; then echo 'FAIL: invalid provenance refused'; fail=$((fail+1)); else echo 'PASS: invalid provenance refused'; fi
cp "$TMP/provenance" "$TMP/project space/.herdr-crew/baseline.json"
ln -s "$TMP/external" "$TMP/project space/.herdr-crew/unsafe"
if run init --json; then echo 'FAIL: nested symlink refused'; fail=$((fail+1)); else echo 'PASS: nested symlink refused'; fi
rm "$TMP/project space/.herdr-crew/unsafe"
mkdir "$TMP/locked"
mkdir "$TMP/locked/.herdr-crew.lock"
if (cd "$TMP/locked" && /bin/bash "$ROOT/bin/crew" init --json) >"$TMP/out" 2>"$TMP/err"; then echo 'FAIL: lock refused'; fail=$((fail+1)); else echo 'PASS: lock refused'; fi
if (cd "$TMP/locked" && /bin/bash "$ROOT/bin/crew" configure driver claude) >"$TMP/out" 2>"$TMP/err"; then echo 'FAIL: configure honors setup lock'; fail=$((fail+1)); else echo 'PASS: configure honors setup lock'; fi
label='unowned lock retained'; check test -d "$TMP/locked/.herdr-crew.lock"
label='locked init does not write project'; check test ! -e "$TMP/locked/.herdr-crew"
printf '%s failures\n' "$fail"
(( fail == 0 ))
