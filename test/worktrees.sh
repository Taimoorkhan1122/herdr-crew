#!/usr/bin/env bash
# Real Git regression checks; Herdr/tsk alone are faked, and HOME is disposable.
set -euo pipefail
CREW="$(cd "$(dirname "$0")/.." && pwd)/bin/crew"
TEMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TEMP_ROOT"' EXIT
mkdir -p "$TEMP_ROOT/fake" "$TEMP_ROOT/home" "$TEMP_ROOT/repo"
cat >"$TEMP_ROOT/fake/herdr" <<'FAKE'
#!/usr/bin/env bash
case "$1 $2" in
  'agent get') exit 1 ;;
  'tab create') echo '{"result":{"root_pane":{"pane_id":"w1:p1"}}}' ;;
  'pane split') echo '{"result":{"pane":{"pane_id":"w1:p2"}}}' ;;
  'agent start'|'agent prompt'|'agent wait') exit 0 ;;
  *) echo "unexpected herdr command: $*" >&2; exit 1 ;;
esac
FAKE
cat >"$TEMP_ROOT/fake/tsk" <<'FAKE'
#!/usr/bin/env bash
echo '[{"number":7,"notes":"worktree regression"}]'
FAKE
printf '#!/usr/bin/env bash\nexit 0\n' >"$TEMP_ROOT/fake/claude"
chmod +x "$TEMP_ROOT/fake/"*
export PATH="$TEMP_ROOT/fake:$PATH" HOME="$TEMP_ROOT/home" HERDR_ENV=1 CREW_WS=w1
export CREW_REPO="$TEMP_ROOT/repo" CREW_SLUG=fixture
unset CREW_DRY_RUN CREW_AGENT CREW_TASK CREW_MANAGER
git -C "$CREW_REPO" init -q
git -C "$CREW_REPO" -c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty -qm initial
git -C "$CREW_REPO" branch crew/T7-pair
"$CREW" team pair T7 >"$TEMP_ROOT/output" 2>&1
worktree="$HOME/.herdr/worktrees/fixture/T7-pair"
[[ "$(git -C "$worktree" symbolic-ref --short HEAD)" == crew/T7-pair ]]
printf '%s\n' 'keep this work' >"$worktree/uncommitted.txt"
"$CREW" team pair T7 >"$TEMP_ROOT/output" 2>&1
[[ "$(cat "$worktree/uncommitted.txt")" == 'keep this work' ]]
echo 'PASS: existing pair branch attaches and retained worktree keeps edits'
"$CREW" team test T7 >"$TEMP_ROOT/output" 2>&1
"$CREW" team test T7 >"$TEMP_ROOT/output" 2>&1
[[ "$(git -C "$HOME/.herdr/worktrees/fixture/T7-test" symbolic-ref --short HEAD)" == crew/T7-test ]]
echo 'PASS: test team creates and reuses its branch worktree'
mkdir -p "$HOME/.herdr/worktrees/fixture/T8-pair"
if "$CREW" team pair T8 >"$TEMP_ROOT/output" 2>&1; then
  echo 'FAIL: unrelated directory was accepted'; exit 1
fi
echo 'PASS: unrelated existing directory is refused'
# A branch held elsewhere must fail normally rather than being forced into a second checkout.
git -C "$CREW_REPO" worktree add -qb crew/T9-pair "$TEMP_ROOT/elsewhere"
if "$CREW" team pair T9 >"$TEMP_ROOT/output" 2>&1; then
  echo 'FAIL: checked-out branch was forced'; exit 1
fi
[[ "$(git -C "$TEMP_ROOT/elsewhere" symbolic-ref --short HEAD)" == crew/T9-pair ]]
echo 'PASS: branch checked out elsewhere stays protected'
