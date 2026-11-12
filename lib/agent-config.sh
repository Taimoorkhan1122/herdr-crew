# Sourced by bin/crew. Project configuration is JSON data, never executable shell.
OPENCODE_CATALOG=""
COMMAND_CODE_CATALOG=""

# Runtime traits. A runtime that ignores the Claude aliases of a rank profile has no
# usable model there; a variant-effort runtime carries the effort inside the model.
runtime_ignores_profile_model() { [[ "$1" == opencode || "$1" == command-code ]]; }

# agent_bin KIND: the installed binary of a runtime. Command Code documents `cmd`;
# `command-code` and `commandcode` are accepted aliases.
agent_bin() {
  local kind=$1 name path
  if [[ "$kind" == command-code ]]; then
    for name in cmd command-code commandcode; do
      path=$(command -v "$name" 2>/dev/null) || continue
      [[ -z "$path" ]] || { printf '%s\n' "$path"; return 0; }
    done
    return 1
  fi
  command -v "$kind"
}

# version_at_least VERSION MAJOR MINOR PATCH: compares X.Y.Z, ignoring a leading v and a suffix.
version_at_least() {
  local version=${1#v} major minor patch
  [[ "$version" =~ ^([0-9]+)\.([0-9]+)(\.([0-9]+))? ]] || return 1
  major=$((10#${BASH_REMATCH[1]})); minor=$((10#${BASH_REMATCH[2]}))
  patch=0; [[ -z "${BASH_REMATCH[4]}" ]] || patch=$((10#${BASH_REMATCH[4]}))
  (( major > $2 )) && return 0
  (( major < $2 )) && return 1
  (( minor > $3 )) && return 0
  (( minor < $3 )) && return 1
  (( patch >= $4 )) && return 0
  return 1
}

config_load() {
  project_root
  CONFIG_FILE="$CONFIG_ROOT/.herdr-crew.json"
  if [[ -e "$CONFIG_ROOT/.herdr-crew" || -L "$CONFIG_ROOT/.herdr-crew" ]]; then
    [[ -d "$CONFIG_ROOT/.herdr-crew" && ! -L "$CONFIG_ROOT/.herdr-crew" ]] || die "refusing invalid project configuration directory"
    CONFIG_FILE="$CONFIG_ROOT/.herdr-crew/config.json"
    [[ ! -e "$CONFIG_ROOT/.herdr-crew.json" ]] || printf 'warning: legacy configuration retained at %s\n' "$CONFIG_ROOT/.herdr-crew.json" >&2
  fi
  AGENT_CONFIG='{"version":1,"roles":{}}'
  [[ ! -L "$CONFIG_FILE" ]] || die "refusing symlink configuration: $CONFIG_FILE"
  if [[ -e "$CONFIG_FILE" ]]; then
    AGENT_CONFIG=$(cat "$CONFIG_FILE") || die "cannot read $CONFIG_FILE"
  fi
  load_definitions
  config_validate "$AGENT_CONFIG"
  CONFIG_ORIGINAL=$AGENT_CONFIG
  CONFIG_EXISTED=0
  [[ ! -e "$CONFIG_FILE" ]] || CONFIG_EXISTED=1
}

config_validate() {
  local roles="$RANKS" f
  for f in "$(project_base)"/agents/*/agent.json; do
    [[ -f "$f" ]] || continue
    local id=${f%/agent.json}; id=${id##*/}
    job_exists "$id" && roles="$roles $id"
  done
  jq -se --arg roles "$roles" '
    def text: type == "string" and length > 0 and (test("[\\x00-\\x1f\\x7f]")|not);
    def explicit_model: has("model") and .model != "inherit";
    length == 1 and (.[0] |
    type == "object" and (keys - ["version","roles"] == []) and .version == 1 and
    (.roles | type == "object") and
    all(.roles | to_entries[];
      .key as $role | ($roles|split(" ")|index($role)) != null and
      (.value | type == "object" and (keys - ["agent","model","effort"] == []) and
        (.agent == "claude" or .agent == "opencode" or .agent == "command-code") and
        (if has("model") then .model|text else true end) and
        (if .agent == "command-code" then
          (if explicit_model then .model|test("^[A-Za-z0-9][A-Za-z0-9._:/-]*$") else true end)
         elif .agent == "claude" then true
         else (if explicit_model then .model|test("^[^/#]+/[^#]+$") else true end) end) and
        (if has("effort") then
          if .agent == "claude" then
            (.effort as $e | ["inherit","low","medium","high","xhigh","max"]|index($e)) != null
          elif .agent == "command-code" then
            (.effort as $e | ["inherit","off","low","medium","high","xhigh","max"]|index($e)) != null and
            (if .effort == "inherit" then true else explicit_model end)
          else if .effort == "inherit" then (.effort | text and (contains("#")|not))
          else (.effort | text and (contains("#")|not)) and has("model") and (.model != "inherit") end end
         else true end))))
  ' <<<"$1" >/dev/null 2>&1 || die "invalid agent configuration in $CONFIG_FILE (version 1; known roles; agent claude/opencode/command-code; optional model and effort; OpenCode model must be provider/model, with its variant in effort; Command Code model must be an exact id from 'cmd --list-models' with no spaces or '#', effort one of off/low/medium/high/xhigh/max, and a non-inherit effort needs an explicit model). Run: herdr-crew configure --help"
}

# agent_selection RANK JOB: sets AGENT_KIND/MODEL/EFFORT and a JSON snapshot.
agent_selection() {
  local rank=$1 job=${2:-} kind model effort
  # Only OpenCode carries the effort in the model variant.
  local variant_efforts='["opencode"]'
  local def
  def=$(agent_definition "${job:-crew-$rank}") || die "unknown agent '${job:-crew-$rank}'"
  [[ "$(jq -r .profile <<<"$def")" == "$rank" ]] || die "agent '$job' does not use profile '$rank'"
  kind=$(jq -r '.kind // "claude"' <<<"$def")
  model=$(jq -r '.model // ""' <<<"$def"); effort=$(jq -r '.effort // ""' <<<"$def")
  if runtime_ignores_profile_model "$kind"; then model=""; effort=""; fi
  AGENT_JSON=$(jq -nc --argjson config "$AGENT_CONFIG" --arg rank "$rank" --arg job "$job" \
    --arg agent "$kind" --arg model "$model" --arg effort "$effort" --argjson variant_efforts "$variant_efforts" '
    def variant_effort($agent): ($variant_efforts | index($agent)) != null;
    def overlay($next): if $next == null then . else
      (if .agent != $next.agent then {agent:$next.agent,model:"",effort:""}
       elif variant_effort(.agent) and $next.model != null and .model != $next.model then .effort=""
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
  for f in "$(project_base)"/agents/*/agent.json; do
    job=${f%/agent.json}; job=${job##*/}; job_exists "$job" || continue
    rank=$(job_meta "$job" profile); agent_selection "$rank" "$job"
    printf '%s\t%s\t%s\t%s\n' "$job" "$AGENT_KIND" "${AGENT_MODEL:-default}" "${AGENT_EFFORT:-default}"
  done
}

config_set() {
  local role=$1 agent=$2 model=$3 effort=$4 value variants
  [[ "$role" == all || " $RANKS $(for f in "$(project_base)"/agents/*/agent.json; do basename "$(dirname "$f")"; done | tr '\n' ' ') " == *" $role "* ]] || die "unknown role '$role'; use a rank ($RANKS) or job (driver, navigator, planner, ...)"
  if [[ "$agent" == opencode && -n "$effort" && "$effort" != inherit ]]; then
    [[ -n "$model" && "$model" != inherit ]] || die "OpenCode effort requires an explicit --model provider/model"
    opencode_catalog
    variants=$(jq -c --arg model "$model" '[.[] | select(.model == $model) | .variants[]]' <<<"$OPENCODE_CATALOG")
    jq -e --arg effort "$effort" 'index($effort) != null' <<<"$variants" >/dev/null ||
      die "unsupported OpenCode effort '$effort' for $model; supported: $(jq -r 'join(", ")' <<<"$variants"); use inherit for the model default"
  fi
  if [[ "$agent" == command-code ]]; then
    if [[ -n "$effort" && "$effort" != inherit ]]; then
      [[ -n "$model" && "$model" != inherit ]] || die "Command Code effort requires an explicit --model (an exact id from 'cmd --list-models')"
    fi
    if [[ -n "$model" && "$model" != inherit ]]; then
      if command_code_catalog; then
        grep -qxF -e "$model" <<<"$COMMAND_CODE_CATALOG" ||
          die "unsupported Command Code model '$model' for this runtime; run 'cmd --list-models' and pass one exact id with --model (ids may be provider/model or plain, and a variant belongs in --effort)"
      else
        crew_warn "cannot read the Command Code model list; saving '$model' after syntax validation only"
      fi
    fi
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
  local tmp='' lock="$CONFIG_ROOT/.herdr-crew.lock" current
  mkdir "$lock" 2>/dev/null || die "project configuration is locked: $lock"
  trap '[[ -z "$tmp" ]] || rm -f "$tmp"; rmdir "$lock" 2>/dev/null || :' EXIT
  [[ ! -L "$CONFIG_FILE" ]] || die "refusing symlink configuration: $CONFIG_FILE"
  if [[ "$CONFIG_FILE" == "$CONFIG_ROOT/.herdr-crew.json" && ( -e "$CONFIG_ROOT/.herdr-crew" || -L "$CONFIG_ROOT/.herdr-crew" ) ]]; then
    die "project configuration changed; retry configure"
  fi
  if [[ "$CONFIG_EXISTED" == 1 ]]; then
    [[ -f "$CONFIG_FILE" ]] || die "configuration changed; retry configure"
    current=$(cat "$CONFIG_FILE") || die "cannot read configuration"
    [[ "$current" == "$CONFIG_ORIGINAL" ]] || die "configuration changed; retry configure"
  else [[ ! -e "$CONFIG_FILE" ]] || die "configuration changed; retry configure"; fi
  tmp=$(mktemp "$(dirname "$CONFIG_FILE")/.crew-config.XXXXXX") || die "cannot write configuration in $CONFIG_ROOT"
  printf '%s\n' "$AGENT_CONFIG" >"$tmp"
  mv -f "$tmp" "$CONFIG_FILE"
  tmp=''
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

# The Command Code model table creates no session and submits no prompt. The list is cached
# for a day under the crew home; a failed read falls back to a stale cache, and with no
# cache at all it returns 1 so the caller can validate the model syntax only.
command_code_catalog() {
  local bin cache list
  [[ -z "$COMMAND_CODE_CATALOG" ]] || return 0
  bin=$(agent_bin command-code) || return 1
  cache="$HOME/.herdr/crew/command-code-models"
  if [[ -f "$cache" && ! -L "$cache" && -n "$(find "$cache" -mtime 0 -prune 2>/dev/null)" ]]; then
    list=$(cat "$cache" 2>/dev/null) || list=""
    if [[ -n "$list" ]]; then COMMAND_CODE_CATALOG=$list; return 0; fi
  fi
  # --list-models prints a blank line, an "Available models" header, category headers and
  # "<model id>   <description>" rows: the first column of a row is the model id.
  list=$("$bin" --list-models 2>/dev/null | awk '
    { line = $0; sub(/^[ \t]+/, "", line) }
    line == "" { next }
    index(line, "Available models") == 1 { next }
    index(line, "  ") == 0 { next }
    { split(line, fields, /  +/); model = fields[1]; sub(/[ \t]+$/, "", model) }
    model != "" && index(model, " ") == 0 && !seen[model]++ { print model }
  ' 2>/dev/null) || list=""
  if [[ -z "$list" ]]; then
    if [[ -f "$cache" && ! -L "$cache" ]]; then list=$(cat "$cache" 2>/dev/null) || list=""; fi
    [[ -n "$list" ]] || return 1
    crew_warn "cannot read the Command Code model list; using the cached list in $cache"
    COMMAND_CODE_CATALOG=$list
    return 0
  fi
  mkdir -p "${cache%/*}" 2>/dev/null || true
  if [[ ! -e "$cache" || ( -f "$cache" && ! -L "$cache" ) ]]; then
    printf '%s\n' "$list" >"$cache" 2>/dev/null || crew_warn "cannot cache the Command Code model list at $cache"
  fi
  COMMAND_CODE_CATALOG=$list
  return 0
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
  config_load
  if [[ "${1:-}" == --show ]]; then
    [[ $# == 1 ]] || die "--show takes no other arguments"
    config_show; return
  fi
  if [[ $# == 0 || "${1:-}" == --interactive ]]; then
    [[ $# == 0 || $# == 1 ]] || die "--interactive takes no other arguments"
    [[ $# == 1 || -t 0 ]] || die "use configure ROLE AGENT for automation, or configure --show to inspect assignments"
    for tool in claude opencode command-code; do agent_bin "$tool" >/dev/null && found="$found $tool"; done
    printf 'Installed supported agents:%s\n' "${found:- none}"
    config_show
    while :; do
      read -r -p 'Role [all]: ' role || die "configuration cancelled; no changes saved"
      role=${role:-all}
      read -r -p 'Agent [claude]: ' agent || die "configuration cancelled; no changes saved"
      agent=${agent:-claude}
      agent_bin "$agent" >/dev/null || die "$agent not found on PATH; no changes saved"
      if [[ "$agent" == opencode ]]; then
        opencode_catalog
        config_choose Model "$(jq -c '[.[].model]' <<<"$OPENCODE_CATALOG")"; model=$CONFIG_CHOICE
        effort=inherit
        variants=$(jq -c --arg model "$model" '[.[] | select(.model == $model) | .variants[]]' <<<"$OPENCODE_CATALOG")
        if [[ "$variants" != '[]' ]]; then
          config_choose Effort "$variants"; effort=$CONFIG_CHOICE
        else printf 'Using model default effort (no selectable variants).\n'; fi
      elif [[ "$agent" == command-code ]]; then
        if command_code_catalog; then
          config_choose Model "$(jq -Rsc 'split("\n") | map(select(length > 0))' <<<"$COMMAND_CODE_CATALOG")"; model=$CONFIG_CHOICE
        else
          printf 'Command Code model ids come from cmd --list-models: provider/model or a plain id.\n'
          read -r -p 'Model [inherit]: ' model || die "configuration cancelled; no changes saved"
        fi
        read -r -p 'Effort [inherit]: ' effort || die "configuration cancelled; no changes saved"
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
  local version bin raw
  case "$AGENT_KIND" in
    claude|opencode) ;;
    command-code)
      bin=$(agent_bin command-code) || die "command-code not found on PATH (install Command Code; the binary is cmd or command-code)"
      [[ -z "$AGENT_MODEL" || "$AGENT_MODEL" =~ ^[A-Za-z0-9][A-Za-z0-9._:/-]*$ ]] ||
        die "Command Code model must be one exact id from 'cmd --list-models', with no spaces or '#': '$AGENT_MODEL'"
      [[ -z "$AGENT_EFFORT" || -n "$AGENT_MODEL" ]] || die "Command Code effort requires an explicit model"
      raw=$("$bin" --version 2>/dev/null) || die "cannot check the Command Code version; Command Code 1.88.5 or newer is required"
      version=""
      [[ "$raw" =~ ([0-9]+)\.([0-9]+)(\.([0-9]+))? ]] && version=${BASH_REMATCH[0]}
      [[ -n "$version" ]] || die "cannot read the Command Code version from '$raw'; Command Code 1.88.5 or newer is required"
      version_at_least "$version" 1 88 5 ||
        die "Command Code 1.88.5 or newer is required (found: $version); upgrade Command Code, then retry"
      return 0 ;;
    *) die "unsupported agent '$AGENT_KIND'; supported adapters: claude, opencode (OpenCode 2), command-code" ;;
  esac
  command -v "$AGENT_KIND" >/dev/null || die "$AGENT_KIND not found on PATH; install it or run herdr-crew configure"
  if [[ "$AGENT_KIND" == opencode ]]; then
    [[ -z "$AGENT_MODEL" || "$AGENT_MODEL" =~ ^[^/#]+/[^#]+$ ]] || die "OpenCode model must be provider/model without variants"
    [[ -z "$AGENT_EFFORT" || -n "$AGENT_MODEL" ]] || die "OpenCode effort requires an explicit model"
    version=$(opencode --version 2>/dev/null) || die "cannot check OpenCode version; OpenCode 2 is required"
    [[ "$version" =~ (^|[[:space:]])v?2\.[0-9]+\. ]] || die "OpenCode 2 is required for native crew permissions (found: $version)"
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

command_code_guidance() {
  cat <<GUIDANCE
Command Code runtime: use the native read/search/edit/shell tools within your rank permissions. Claude Skill, Agent(Explore), Monitor, alias and Claude hook instructions do not apply. A per-session native mod injects and enforces the rank policy; subagents are disabled, so perform read-only lookups yourself. The mod attempts a native context warning at CREW_CTX_LIMIT (${CREW_CTX_LIMIT:-135000} tokens); if the runtime reports no token count, monitor context and hand off before compaction. Load portable skills by name with the skill tool, or read their SKILL.md files; report missing skills rather than inventing them. Crew installation: $ROOT (read docs/planning/ here when needed).
This runtime guidance replaces runtime-specific steps in the rank body; all role scope, review and approval rules still apply.
GUIDANCE
}

# Command Code permission mode: the inspector is natively read-only, the working ranks
# keep prompting off because the session mod blocks what their rank may not do.
command_code_permission_mode() {
  case "$1" in
    inspector) printf 'plan\n' ;;
    *) printf 'yolo\n' ;;
  esac
}

# OpenCode 2 permissions are ordered; the last matching rule wins.
opencode_config() {
  local rank=$1 job=${2:-} shell_rules def system
  def=$(agent_definition "${job:-crew-$rank}") || die "cannot resolve project agent"
  shell_rules=$(jq -c '[.tools[]? | capture("^Bash\\((?<cmd>.*)\\)$")? | {action:"shell",resource:.cmd,effect:"allow"}]' <<<"$def")
  system=$(jq -r '.profileInstructions + (if .id == ("crew-" + .profile) then "" else "\n\n" + .instructions end)' <<<"$def")
  jq -nc --arg rank "$rank" --arg model "$AGENT_MODEL" --arg effort "$AGENT_EFFORT" --arg system "$system

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
