# Sourced by bin/crew before any dependency check, so `--help` and `--version`
# work on a machine without tsk, herdr or jq.
# Colour and symbols decorate output only. Every word a test or a script matches
# stays exactly as it was, and colour is off when stdout is not a terminal.

crew_tty=0
if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then crew_tty=1; fi
U_RED="" U_GRN="" U_YEL="" U_BLU="" U_CYN="" U_MAG="" U_DIM="" U_BLD="" U_UNDER="" U_OFF=""
U_OK="" U_INFO="" U_WARN="" U_ERR="" U_ARROW="" U_BULLET=""
if (( crew_tty )); then
  U_RED=$'\033[31m'; U_GRN=$'\033[32m'; U_YEL=$'\033[33m'; U_BLU=$'\033[34m'
  U_MAG=$'\033[35m'; U_CYN=$'\033[36m'; U_DIM=$'\033[2m'; U_BLD=$'\033[1m'; U_UNDER=$'\033[4m'; U_OFF=$'\033[0m'
  U_OK="${U_GRN}✓${U_OFF}"; U_INFO="${U_CYN}ℹ${U_OFF}"; U_WARN="${U_YEL}⚠${U_OFF}"; U_ERR="${U_RED}✗${U_OFF}"; U_ARROW="${U_CYN}→${U_OFF}"; U_BULLET="${U_DIM}•${U_OFF}"
else
  U_OK="✓"; U_INFO="ℹ"; U_WARN="⚠"; U_ERR="✗"; U_ARROW="->"; U_BULLET="•"
fi

# crew_out TEXT: the standard result line. Only "crew:" is coloured.
crew_out() { printf '%screw:%s %s\n' "$U_BLU" "$U_OFF" "$*"; }
# crew_step TEXT: progress line for a long operation (an agent start can take minutes).
crew_step() { printf '%s%s%s %s\n' "$U_CYN" "$U_ARROW" "$U_OFF" "$*"; }
# crew_info TEXT: informational message
crew_info() { printf '%s %s\n' "$U_INFO" "$*"; }
# crew_ok TEXT: success message
crew_ok() { printf '%s %s\n' "$U_OK" "$*"; }
# crew_warn TEXT: warning on stderr; never fails the command.
crew_warn() { printf '%s %swarning:%s %s\n' "$U_WARN" "$U_YEL" "$U_OFF" "$*" >&2; }
# crew_err TEXT: error on stderr
crew_err() { printf '%s %serror:%s %s\n' "$U_ERR" "$U_RED" "$U_OFF" "$*" >&2; }

teams_list() { ls "$ROOT/teams" 2>/dev/null | sed 's/\.conf$//' | xargs echo; }
crew_version() { git -C "$ROOT" describe --tags --always --dirty 2>/dev/null || printf 'dev\n'; }

usage() {
  cat <<EOF
${U_BLD}${U_CYN}herdr-crew${U_OFF} - deterministic crew launcher for Herdr

${U_BLD}USAGE${U_OFF}
  ${U_DIM}\$${U_OFF} herdr-crew <command> [arguments]
  ${U_DIM}\$${U_OFF} herdr-crew help <command>

${U_BLD}COMMANDS${U_OFF}
  ${U_BLU}init${U_OFF}        Initialize the project baseline
  ${U_BLU}upgrade${U_OFF}     Preview or apply selected baseline updates
  ${U_BLU}configure${U_OFF}   Set the agent, model and effort of each rank and job
  ${U_BLU}launch${U_OFF}      Start a crew, or a job persona with a new task and its team
  ${U_BLU}team${U_OFF}        Start the team of an existing task
  ${U_BLU}say${U_OFF}         Send a message to a running agent
  ${U_BLU}mark${U_OFF}        Record a task status change and a note
  ${U_BLU}status${U_OFF}      Show task states and crew agent states
  ${U_BLU}close${U_OFF}       Close a task's tabs (worktrees are kept)
  ${U_BLU}watch${U_OFF}       Print one line per board change (the lead's Monitor feed)
  ${U_BLU}handoff${U_OFF}     Save a handoff file and tell the initiator
  ${U_BLU}restart${U_OFF}     Start an agent again from its saved brief and handoff
  ${U_BLU}completion${U_OFF}  Print a shell completion script
  ${U_BLU}help${U_OFF}        Show this help, or the help of one command

${U_BLD}GLOBAL OPTIONS${U_OFF}
  ${U_GRN}-h${U_OFF}, ${U_GRN}--help${U_OFF}       Show this help and exit
  ${U_GRN}-V${U_OFF}, ${U_GRN}--version${U_OFF}    Show the version and exit
      ${U_GRN}--dry-run${U_OFF}    Print every mutating herdr, tsk and git call instead of running it

  ${U_DIM}Global options come before the command, so instructions can never look like one.
  CREW_DRY_RUN=1 in the environment does the same as --dry-run.${U_OFF}

${U_BLD}TEAMS${U_OFF}
  $(teams_list)

${U_BLD}EXAMPLES${U_OFF}
  ${U_DIM}# Start a lead crew${U_OFF}
  herdr-crew launch lead - <<'EOF'
  Build the login page
  EOF

  herdr-crew launch member@driver+nestjs-expert -
  herdr-crew team pair T7 --persona navigator=security-paranoid
  herdr-crew status
  herdr-crew launch driver --help

${U_DIM}Run 'herdr-crew help <command>' for the arguments and options of one command.${U_OFF}
${U_DIM}Docs: docs/features.md in the herdr-crew installation.${U_OFF}
EOF
}

usage_init() { cat <<'EOF'
USAGE
  herdr-crew init [--json]
Initialize missing project baseline files without replacing customizations.
EOF
}
usage_upgrade() { cat <<'EOF'
USAGE
  herdr-crew upgrade [--json] [--apply RELATIVE_PATH --expect SOURCE_SHA256 --expect-target TARGET_SHA256_OR_absent]...
Preview baseline changes and source/target hashes, or apply selected paths with their reviewed values.
EOF
}
usage_configure() {
  cat <<'EOF'
USAGE
  herdr-crew configure [--interactive | --show | ROLE AGENT [--model MODEL] [--effort EFFORT]]
  herdr-crew configure --help

DESCRIPTION
  Saves .herdr-crew.json in the primary project checkout; worktrees share it.
  Needs jq only. It does not call Herdr, tsk or any agent.

ARGUMENTS
  ROLE    all, a rank (lead, manager, member, inspector), or a job (driver, navigator, ...)
  AGENT   claude, or opencode (OpenCode 2). Job settings override rank defaults.

OPTIONS
  --interactive       Wizard. Lists models, and the variants of the chosen model.
  --show              Print the effective settings and change nothing.
  --model MODEL       Model name, or 'inherit' for the agent default.
  --effort EFFORT     low, medium, high, xhigh, max, or 'inherit'. An OpenCode
                      effort selects a variant the explicit model supports.

EXAMPLES
  herdr-crew configure
  herdr-crew configure driver opencode --model provider/model --effort high
  herdr-crew configure --show
EOF
}

usage_launch() {
  cat <<EOF
${U_BLD}USAGE${U_OFF}
  herdr-crew launch <spec> [instructions...]
  herdr-crew launch <spec> -

${U_BLD}ARGUMENTS${U_OFF}
  ${U_GRN}<spec>${U_OFF}            lead | <rank>@<job>[+<domain>] | <job>
                    ranks: $RANKS
                    jobs and domains: $(persona_names)
  ${U_GRN}instructions...${U_OFF}   The work for the agent. One job persona per spec.
  ${U_GRN}-${U_OFF}                 Read the instructions from stdin. Use it when the text holds
                    quotes, newlines or shell characters.

${U_BLD}DESCRIPTION${U_OFF}
  lead starts the Lead, the Manager and the board pane. A job persona creates a
  ready task and starts its configured team. Re-running lead sends the new
  instructions to the running lead instead of starting a second crew.
  Invalid input fails before any task, workspace or agent is created.

${U_BLD}EXAMPLES${U_OFF}
  ${U_DIM}# Start lead crew${U_OFF}
  herdr-crew launch lead - <<'EOF'
  Build the login page
  EOF

  herdr-crew launch member@driver+nestjs-expert -
  herdr-crew launch inspector - "Is there a race in bin/crew?"
EOF
}

usage_team() {
  cat <<EOF
USAGE
  herdr-crew team <team> <T#> [--persona <job>=<domain>[+<domain>]]... [instructions...]

ARGUMENTS
  <team>             $(teams_list)
  <T#>               Existing task number.
  instructions...   Overrides the task notes in the brief. Without it, the task
                     notes are used.

OPTIONS
  --persona <job>=<domain>[+<domain>]   Attach a domain persona to one job slot.
                                        Repeat it for different slots.

DESCRIPTION
  Prepares the worktree the team needs, then starts one agent per member in one
  tab. review needs a task that already has crew/T#-pair, so run pair first.

EXAMPLES
  herdr-crew team pair T7 --persona driver=ui-expert --persona navigator=ui-expert
  herdr-crew team review T7
EOF
}

usage_say() {
  cat <<EOF
USAGE
  herdr-crew say <agent> "<message>"

ARGUMENTS
  <agent>    Agent name, as shown by 'herdr-crew status'.
  <message>  The text to deliver.

DESCRIPTION
  Prompts an idle or done agent. A busy agent is waited on for up to 20 seconds;
  if it stays busy and has a task, the message is queued as a step on that task
  and the agent reads it from there. Lead and Manager have no task, so a message
  to a busy one is reported as not delivered. The command exits 0 either way:
  read the output.

EXAMPLES
  herdr-crew say $SLUG-manager "T7 is ready for review"
EOF
}

usage_mark() {
  cat <<'EOF'
USAGE
  herdr-crew mark <T#> <status> "<note>"

ARGUMENTS
  <T#>      Task number.
  <status>  New task status, for example started, blocked, review or done.
  <note>    Note appended to the task, and shown in the pane title.

DESCRIPTION
  Runs three separate calls: the status change, the note as a step, and the pane
  metadata. They are not one atomic transaction.
EOF
}

usage_status() {
  cat <<EOF
USAGE
  herdr-crew status [--json]

DESCRIPTION
  Prints one line per open task (T number, status, title) and one line per known
  crew agent (name, state), tab separated. Agents are probed by the names the
  crew would use. Completed tasks are excluded by tsk's default list.

OPTIONS
  --json   Print the raw task JSON instead, for scripts.

EXAMPLES
  herdr-crew status
  herdr-crew status --json | jq -r '.[].title'
EOF
}

usage_close() {
  cat <<'EOF'
USAGE
  herdr-crew close <T#> [<team>]

ARGUMENTS
  <T#>    Task number.
  <team>  Optional. Without it every tab labelled "T# " is closed. With it only
          the tab labelled "T# <team>" is closed.

DESCRIPTION
  Closes tabs only. Worktrees are kept, and the command prints the git command
  that removes each one, so nothing is deleted by surprise.
EOF
}

usage_watch() {
  cat <<'EOF'
USAGE
  herdr-crew watch

DESCRIPTION
  Prints one line per change and never repeats unchanged state: task status
  changes, agents that reach blocked or done, agents that disappear, and new
  handoff files. The first poll only sets the baseline. The lead runs it with
  the Monitor tool. Press Ctrl+C to stop.
  CREW_WATCH_SECS sets the interval (default 20 seconds).
EOF
}

usage_handoff() {
  cat <<'EOF'
USAGE
  herdr-crew handoff "<status>" < handoff text

ARGUMENTS
  <status>  Short status, for example "half done".

DESCRIPTION
  Saves the body from stdin as the handoff file, or keeps the file already
  there. Records a step on the task and tells the initiator, which restarts the
  agent with 'herdr-crew restart'. It does not terminate the agent itself.

EXAMPLES
  herdr-crew handoff "context limit" <<'EOF'
  Goal: fix login. Done: failing test written.
  Next: make it pass, then mark review.
  EOF
EOF
}

usage_restart() {
  cat <<'EOF'
USAGE
  herdr-crew restart <agent|T#>

ARGUMENTS
  <agent>  Agent name, as shown by 'herdr-crew status'.
  <T#>     Restart every saved agent of that task.

DESCRIPTION
  Starts the agent again from its saved rank, job, pane, task and brief, in the
  same pane, so its original environment and session policy are preserved. An
  existing handoff is pointed at, then archived. Configuration edits apply only
  to new launches; a restart keeps the settings it started with.
EOF
}

usage_completion() {
  cat <<'EOF'
USAGE
  herdr-crew completion <bash|zsh>

ARGUMENTS
  <bash|zsh>   Print the completion script for that shell on stdout.

EXAMPLES
  herdr-crew completion bash > ~/.bash_completion.d/herdr-crew
  herdr-crew completion zsh > ~/.zfunc/_herdr-crew
EOF
}

cmd_completion() {
  case "${1:-}" in
    bash) cat <<'EOF'
# bash completion for herdr-crew. Source it, or place it in a completion directory.
_herdr_crew() {
  local cur commands
  cur="${COMP_WORDS[COMP_CWORD]}"
  commands="init upgrade configure launch team say mark status close watch handoff restart completion help"
  if (( COMP_CWORD == 1 )); then
    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
  else
    COMPREPLY=( $(compgen -W "--dry-run --help --version" -- "$cur") )
  fi
}
complete -F _herdr_crew herdr-crew
EOF
      ;;
    zsh) cat <<'EOF'
#compdef herdr-crew
# zsh completion for herdr-crew. Source it from a directory on your fpath.
_herdr_crew() {
  local -a commands
  commands=(init upgrade configure launch team say mark status close watch handoff restart completion help)
  _describe -t commands 'herdr-crew command' commands
}
_herdr_crew "$@"
EOF
      ;;
    *) die "usage: herdr-crew completion <bash|zsh>" ;;
  esac
}
