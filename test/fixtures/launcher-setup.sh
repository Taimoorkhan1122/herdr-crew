#!/usr/bin/env bash
# Shared disposable launcher fixture.
# The real launcher code runs (jq parsing included). No live Herdr, agents or tasks.
set -euo pipefail

CREW="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/bin/crew"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FAKE="$TMP/fake"; STATE="$TMP/state"; export LOG="$TMP/log" STATE TMP
mkdir -p "$FAKE" "$STATE" "$TMP/home"; : >"$LOG"
export REAL_GIT; REAL_GIT=$(command -v git)
REPO="$TMP/crew-demo"; mkdir -p "$REPO"; "$REAL_GIT" -C "$REPO" init -q
REPO=$(cd "$REPO" && pwd -P)
cd "$REPO"
S="crew-d-$(printf %s "$REPO" | shasum | cut -c1-4)"

cat >"$FAKE/tsk" <<'SH'
#!/usr/bin/env bash
echo "tsk $*" >>"$LOG"
case "$1" in
  add) echo '{"number":7,"outcome":"created"}' ;;
  list) if [[ " $* " == *" -p "* && " $* " == *" --done "* ]]; then
          # done list: T7 only once the open list read it as done (like the real tsk, which hides done tasks)
          if [[ "$(cat "$STATE/tsk-last" 2>/dev/null)" == done ]]; then echo '[{"number":7,"status":"done","title":"fix the login bug","notes":""}]'; else echo '[]'; fi
        elif [[ " $* " == *" -p "* ]]; then
          # board read: T7 status comes from $STATE/tsk-seq (one status per poll), T8 stays ready. Done T7 is left out.
          if [[ -f "$STATE/tsk-empty" ]]; then echo '[]'
          else
            st=ready
            if [[ -f "$STATE/tsk-seq" ]]; then st=$(head -1 "$STATE/tsk-seq"); tail -n +2 "$STATE/tsk-seq" >"$STATE/tsk-seq.n"; mv -f "$STATE/tsk-seq.n" "$STATE/tsk-seq"; fi
            echo "$st" >"$STATE/tsk-last"
            if [[ "$st" == done ]]; then echo '[{"number":8,"status":"ready","title":"other","notes":""}]'
            else echo "[{\"number\":7,\"status\":\"$st\",\"title\":\"fix the login bug\",\"notes\":\"\"},{\"number\":8,\"status\":\"ready\",\"title\":\"other\",\"notes\":\"\"}]"; fi
          fi
        else echo '[{"number":7,"notes":""}]'; fi ;;
esac
SH
cat >"$FAKE/git" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"rev-parse --path-format=absolute --git-common-dir"*) echo "$TMP/crew-demo/.git" ;;
  *"symbolic-ref --short HEAD"*) echo crew/T7-pair ;;
  *"rev-parse --verify"*) [[ -n "${BRANCH_EXISTS:-}" && "${*: -1}" == refs/heads/crew/T7-pair ]] ;;
  *"worktree add"*|*"checkout --detach"*) echo "git $*" >>"$LOG" ;;
  *) exec "$REAL_GIT" "$@" ;;
esac
SH
printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE/claude"
chmod +x "$FAKE"/*
export PATH="$FAKE:$PATH" HOME="$TMP/home" HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 CREW_WS=w1
unset CREW_SLUG CREW_REPO CREW_AGENT CREW_TASK CREW_MANAGER CREW_DRY_RUN BRANCH_EXISTS
source "$ROOT/test/fixtures/fake-runtime.sh"
install_fake_runtime "$FAKE" "$STATE"
touch "$STATE/auto-ready"
