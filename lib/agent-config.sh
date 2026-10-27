# Sourced by bin/crew. Project configuration is JSON data, never executable shell.
OPENCODE_CATALOG=""
config_load() {
  local entry common gitdir
  CONFIG_ROOT=$REPO
  if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
    # The primary checkout can be separate from its Git metadata directory.
    IFS= read -r -d '' entry < <(git -C "$REPO" worktree list --porcelain -z) || die "cannot resolve primary project checkout for $REPO"
    [[ "$entry" == "worktree "* ]] || die "invalid worktree inventory for $REPO"
    if ! CONFIG_ROOT=$(git -C "${entry#worktree }" rev-parse --show-toplevel 2>/dev/null); then
      common=$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir)
      gitdir=$(git -C "$REPO" rev-parse --absolute-git-dir)
      [[ "$gitdir" == "$common" ]] || die "cannot locate primary checkout for separate Git metadata; set CREW_REPO to the primary project directory"
      CONFIG_ROOT=$(git -C "$REPO" rev-parse --show-toplevel) || die "configuration requires a project working directory"
    fi
  fi
  CONFIG_FILE="$CONFIG_ROOT/.herdr-crew.json"
  AGENT_CONFIG='{"version":1,"roles":{}}'
  [[ ! -L "$CONFIG_FILE" ]] || die "refusing symlink configuration: $CONFIG_FILE"
  if [[ -e "$CONFIG_FILE" ]]; then
    AGENT_CONFIG=$(cat "$CONFIG_FILE") || die "cannot read $CONFIG_FILE"
  fi
  config_validate "$AGENT_CONFIG"
}

config_validate() {
  local roles="$RANKS" f
  for f in "$ROOT"/personas/*.md; do
    [[ -z "$(fm rank "$f")" ]] || roles="$roles $(basename "$f" .md)"
  done
  jq -se --arg roles "$roles" '
    def text: type == "string" and length > 0 and (test("[\\x00-\\x1f\\x7f]")|not);
    length == 1 and (.[0] |
    type == "object" and (keys - ["version","roles"] == []) and .version == 1 and
    (.roles | type == "object") and
    all(.roles | to_entries[];
      .key as $role | ($roles|split(" ")|index($role)) != null and
      (.value | type == "object" and (keys - ["agent","model","effort"] == []) and
        (.agent == "claude" or .agent == "opencode") and
        (if has("model") then .model|text else true end) and
        (.agent == "claude" or (if has("model") and .model != "inherit" then
          .model|test("^[^/#]+/[^#]+$") else true end)) and
        (if has("effort") then
          if .agent == "claude" then
            (.effort as $e | ["inherit","low","medium","high","xhigh","max"]|index($e)) != null
          else if .effort == "inherit" then (.effort | text and (contains("#")|not))
          else (.effort | text and (contains("#")|not)) and has("model") and (.model != "inherit") end end
         else true end))))
  ' <<<"$1" >/dev/null 2>&1 || die "invalid agent configuration in $CONFIG_FILE (version 1; known roles; agent claude/opencode; optional model and effort; OpenCode model must be provider/model, with its variant in effort). Run: herdr-crew configure --help"
}

# agent_selection RANK JOB: sets AGENT_KIND/MODEL/EFFORT and a JSON snapshot.
agent_selection() {
  local rank=$1 job=${2:-} kind model effort
  kind=$(fm kind "$(rank_file "$rank")"); kind=${kind:-claude}
  model=$(fm model "$(rank_file "$rank")"); effort=$(fm effort "$(rank_file "$rank")")
  if [[ "$kind" == opencode ]]; then
    model=$(fm opencode_model "$(rank_file "$rank")"); effort=""
  elif [[ -n "$job" ]]; then
    effort=$(fm effort "$(pfile "$job")"); effort=${effort:-$(fm effort "$(rank_file "$rank")")}
  fi
  AGENT_JSON=$(jq -nc --argjson config "$AGENT_CONFIG" --arg rank "$rank" --arg job "$job" \
    --arg agent "$kind" --arg model "$model" --arg effort "$effort" '
    def overlay($next): if $next == null then . else
      (if .agent != $next.agent then {agent:$next.agent,model:"",effort:""}
       elif .agent == "opencode" and $next.model != null and .model != $next.model then .effort=""
       else . end) * $next end;
    {agent:$agent,model:$model,effort:$effort} | overlay($config.roles[$rank]) |
    overlay($config.roles[$job]) | .model = (if .model == "inherit" then "" else .model end) |
    .effort = (if .effort == "inherit" then "" else .effort end)')
  selection_fields
}

selection_fields() {
  AGENT_KIND=$(jq -r .agent <<<"$AGENT_JSON")
  AGENT_MODEL=$(jq -r '.model // ""' <<<"$AGENT_JSON")
  AGENT_EFFORT=$(jq -r '.effort // ""' <<<"$AGENT_JSON")
}

config_show() {
  local rank job f
  printf 'config: %s\n' "$CONFIG_FILE"
  printf 'role\tagent\tmodel\teffort\n'
  for rank in $RANKS; do
    agent_selection "$rank" ""
    printf '%s\t%s\t%s\t%s\n' "$rank" "$AGENT_KIND" "${AGENT_MODEL:-default}" "${AGENT_EFFORT:-default}"
  done
  for f in "$ROOT"/personas/*.md; do
    rank=$(fm rank "$f"); [[ -n "$rank" ]] || continue
    job=$(basename "$f" .md); agent_selection "$rank" "$job"
    printf '%s\t%s\t%s\t%s\n' "$job" "$AGENT_KIND" "${AGENT_MODEL:-default}" "${AGENT_EFFORT:-default}"
  done
}

config_set() {
  local role=$1 agent=$2 model=$3 effort=$4 value variants
  [[ "$role" == all || " $RANKS $(all_jobs | tr '\n' ' ') " == *" $role "* ]] || die "unknown role '$role'; use a rank ($RANKS) or job (driver, navigator, planner, ...)"
  if [[ "$agent" == opencode && -n "$effort" && "$effort" != inherit ]]; then
    [[ -n "$model" && "$model" != inherit ]] || die "OpenCode effort requires an explicit --model provider/model"
    opencode_catalog
    variants=$(jq -c --arg model "$model" '[.[] | select(.model == $model) | .variants[]]' <<<"$OPENCODE_CATALOG")
    jq -e --arg effort "$effort" 'index($effort) != null' <<<"$variants" >/dev/null ||
      die "unsupported OpenCode effort '$effort' for $model; supported: $(jq -r 'join(", ")' <<<"$variants"); use inherit for the model default"
  fi
  value=$(jq -nc --arg agent "$agent" --arg model "$model" --arg effort "$effort" \
    '{agent:$agent} + (if $model != "" then {model:$model} else {} end) + (if $effort != "" then {effort:$effort} else {} end)')
  if [[ "$role" == all ]]; then
    AGENT_CONFIG=$(jq --arg ranks "$RANKS" --argjson value "$value" 'reduce ($ranks|split(" ")[]) as $r (. ; .roles[$r]=$value)' <<<"$AGENT_CONFIG")
  else
    AGENT_CONFIG=$(jq --arg role "$role" --argjson value "$value" '.roles[$role]=$value' <<<"$AGENT_CONFIG")
  fi
  config_validate "$AGENT_CONFIG"
}

config_save() (
  local tmp
  [[ ! -L "$CONFIG_FILE" ]] || die "refusing symlink configuration: $CONFIG_FILE"
  tmp=$(mktemp "$CONFIG_ROOT/.herdr-crew.json.XXXXXX") || die "cannot write configuration in $CONFIG_ROOT"
  trap 'rm -f "$tmp"' EXIT
  printf '%s\n' "$AGENT_CONFIG" >"$tmp"
  mv -f "$tmp" "$CONFIG_FILE"
)

# The private metadata request creates no session and submits no model prompt.
opencode_catalog() {
  local response
  [[ -z "$OPENCODE_CATALOG" ]] || return 0
  response=$(cd "$CONFIG_ROOT" && opencode api --standalone model.list 2>/dev/null) ||
    die "cannot read OpenCode model catalog; check opencode authentication/configuration, then retry"
  OPENCODE_CATALOG=$(jq -ce '
    def text: type == "string" and length > 0 and (test("[\\x00-\\x1f\\x7f#]")|not);
    if (.data|type) != "array" then error("missing catalog") else
      [.data[] | select(.enabled != false) |
       if (.providerID|text) and (.id|text) and ((.variants // [])|type == "array") and
          all((.variants // [])[]; .id|text) then
         {model:(.providerID + "/" + .id),variants:[(.variants // [])[] | .id]}
       else error("invalid catalog model") end] | sort_by(.model) end
  ' <<<"$response") || die "invalid OpenCode model catalog; no changes saved"
}

# Number, exact value, or a search term; blank/0 keeps the runtime default.
config_choose() {
  local label=$1 choices=$2 matches=$2 answer count
  while :; do
    printf '%s\n' "$label choices (0: inherit):"
    jq -r 'to_entries[] | "  \(.key + 1)) \(.value)"' <<<"$matches"
    read -r -p "$label [inherit, number, or search]: " answer || die "configuration cancelled; no changes saved"
    case "$answer" in ""|0|inherit) CONFIG_CHOICE=inherit; return ;; esac
    count=$(jq length <<<"$matches")
    if [[ "$answer" =~ ^[1-9][0-9]{0,5}$ ]] && (( answer <= count )); then
      CONFIG_CHOICE=$(jq -r --argjson index "$((answer - 1))" '.[$index]' <<<"$matches"); return
    fi
    if jq -e --arg answer "$answer" 'index($answer) != null' <<<"$choices" >/dev/null; then
      CONFIG_CHOICE=$answer; return
    fi
    matches=$(jq -c --arg search "$answer" '[.[] | select(ascii_downcase | contains($search|ascii_downcase))]' <<<"$choices")
    [[ "$matches" != '[]' ]] || { printf 'No matching %s; try another search.\n' "$label"; matches=$choices; }
  done
}

cmd_configure() {
  local role agent model="" effort="" again found="" tool variants
  case "${1:-}" in
    --help|-h)
      cat <<'HELP'
usage: herdr-crew configure [--interactive | --show | ROLE AGENT [--model MODEL] [--effort EFFORT]]
Saves .herdr-crew.json in the primary project checkout; worktrees share it.
ROLE: all, lead, manager, member, inspector, or a job (driver, navigator, ...).
AGENT: claude or opencode (OpenCode 2). Job settings override rank defaults.
Use model/effort 'inherit' for the agent's default. OpenCode effort selects a
variant supported by the explicit model. The wizard lists models and variants.
Examples:
  herdr-crew configure
  herdr-crew configure driver opencode --model provider/model
  herdr-crew configure --show
HELP
      return ;;
  esac
  config_load
  if [[ "${1:-}" == --show ]]; then
    [[ $# == 1 ]] || die "--show takes no other arguments"
    config_show; return
  fi
  if [[ $# == 0 || "${1:-}" == --interactive ]]; then
    [[ $# == 0 || $# == 1 ]] || die "--interactive takes no other arguments"
    [[ $# == 1 || -t 0 ]] || die "use configure ROLE AGENT for automation, or configure --show to inspect assignments"
    for tool in claude opencode; do command -v "$tool" >/dev/null && found="$found $tool"; done
    printf 'Installed supported agents:%s\n' "${found:- none}"
    config_show
    while :; do
      read -r -p 'Role [all]: ' role || die "configuration cancelled; no changes saved"
      role=${role:-all}
      read -r -p 'Agent [claude]: ' agent || die "configuration cancelled; no changes saved"
      agent=${agent:-claude}
      command -v "$agent" >/dev/null || die "$agent not found on PATH; no changes saved"
      if [[ "$agent" == opencode ]]; then
        opencode_catalog
        config_choose Model "$(jq -c '[.[].model]' <<<"$OPENCODE_CATALOG")"; model=$CONFIG_CHOICE
        effort=inherit
        variants=$(jq -c --arg model "$model" '[.[] | select(.model == $model) | .variants[]]' <<<"$OPENCODE_CATALOG")
        if [[ "$variants" != '[]' ]]; then
          config_choose Effort "$variants"; effort=$CONFIG_CHOICE
        else printf 'Using model default effort (no selectable variants).\n'; fi
      else
        read -r -p 'Model [inherit]: ' model || die "configuration cancelled; no changes saved"
        read -r -p 'Effort [inherit]: ' effort || die "configuration cancelled; no changes saved"
      fi
      config_set "$role" "$agent" "${model:-inherit}" "${effort:-inherit}"
      read -r -p 'Configure another role? [y/N]: ' again || die "configuration cancelled; no changes saved"
      [[ "$again" == y || "$again" == Y ]] || break
    done
  else
    [[ $# -ge 2 ]] || die "usage: configure ROLE AGENT [--model MODEL] [--effort EFFORT]"
    role=$1; agent=$2; shift 2
    while [[ $# -gt 0 ]]; do
      case $1 in
        --model|--effort)
          [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || die "$1 requires a value"
          if [[ "$1" == --model ]]; then model=$2; else effort=$2; fi
          shift 2 ;;
        *) die "unknown configure argument '$1'; use --model or --effort (see configure --help)" ;;
      esac
    done
    config_set "$role" "$agent" "$model" "$effort"
  fi
  config_save
  config_show
}

agent_check() {
  local version
  case "$AGENT_KIND" in
    claude|opencode) ;;
    *) die "unsupported agent '$AGENT_KIND'; supported adapters: claude, opencode (OpenCode 2)" ;;
  esac
  command -v "$AGENT_KIND" >/dev/null || die "$AGENT_KIND not found on PATH; install it or run herdr-crew configure"
  if [[ "$AGENT_KIND" == opencode ]]; then
    [[ -z "$AGENT_MODEL" || "$AGENT_MODEL" =~ ^[^/#]+/[^#]+$ ]] || die "OpenCode model must be provider/model without variants"
    [[ -z "$AGENT_EFFORT" || -n "$AGENT_MODEL" ]] || die "OpenCode effort requires an explicit model"
    version=$(opencode --version 2>/dev/null) || die "cannot check OpenCode version; OpenCode 2 is required"
    [[ "$version" =~ (^|[[:space:]])2\.[0-9]+\. ]] || die "OpenCode 2 is required for native crew permissions (found: $version)"
  fi
}

preflight_team() {
  local m rank job
  for m in $(conf "$1" members); do
    rank=${m%%@*}; job=""
    [[ "$m" != *@* ]] || job=${m#*@}
    agent_selection "$rank" "$job"
    agent_check
  done
}

opencode_guidance() {
  cat <<GUIDANCE
OpenCode runtime: use native read/glob/grep/shell/edit/skill tools within your rank permissions. Claude-specific Skill, Agent(Explore), Monitor, aliases and hook instructions do not apply. Subagents are disabled; perform read-only lookups yourself. Load portable skills by name with the skill tool or read their SKILL.md files; report missing/plugin-only skills rather than inventing them. Use short bounded shell waits and recheck the board between waits; background Monitor wakeups are unavailable, so report that monitoring limit. Preserve your rank communication style without requiring the Claude caveman plugin. Crew installation: $ROOT (read docs/planning/ here when needed).
This runtime guidance replaces runtime-specific steps in the rank body; all role scope, review and approval rules still apply.
GUIDANCE
}

# OpenCode 2 permissions are ordered; the last matching rule wins.
opencode_config() {
  local rank=$1 shell_rules
  shell_rules=$(fm tools "$(rank_file "$rank")" | jq -Rc '[scan("Bash\\(([^)]+)\\)") | .[0] | {action:"shell",resource:.,effect:"allow"}]')
  jq -nc --arg rank "$rank" --arg model "$AGENT_MODEL" --arg effort "$AGENT_EFFORT" --arg system "$(body "$(rank_file "$rank")")

$(opencode_guidance)" \
    --argjson shell_rules "$shell_rules" '
    ([{action:"*",resource:"*",effect:"deny"}] +
     (["read","glob","grep","skill"] | map({action:.,resource:"*",effect:"allow"})) +
     (if $rank == "lead" then [{action:"question",resource:"*",effect:"allow"}] else [] end) +
     (if $rank == "member" then
       [{action:"external_directory",resource:"*",effect:"ask"},
        {action:"edit",resource:"*",effect:"allow"},
        {action:"shell",resource:"*",effect:"allow"},
        {action:"shell",resource:"git push *",effect:"deny"},
        {action:"shell",resource:"git merge *",effect:"deny"},
        {action:"shell",resource:"git -C * push *",effect:"deny"},
        {action:"shell",resource:"git -C * merge *",effect:"deny"}]
      else [{action:"external_directory",resource:"*",effect:"allow"}] + $shell_rules end)) as $permissions |
    {default_agent:"crew",agents:{crew:{mode:"primary",system:$system,permissions:$permissions}}} |
    if $model != "" then .model=$model | .agents.crew.model=($model + (if $effort != "" then "#" + $effort else "" end)) else . end'
}
