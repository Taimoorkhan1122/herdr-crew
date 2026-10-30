# Sourced by bin/crew; project state is shared by linked worktrees.
project_root() {
  local entry common gitdir
  CONFIG_ROOT=$REPO
  if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
    IFS= read -r -d '' entry < <(git -C "$REPO" worktree list --porcelain -z) || die "cannot resolve primary project checkout for $REPO"
    [[ "$entry" == "worktree "* ]] || die "invalid worktree inventory for $REPO"
    if ! CONFIG_ROOT=$(git -C "${entry#worktree }" rev-parse --show-toplevel 2>/dev/null); then
      common=$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir)
      gitdir=$(git -C "$REPO" rev-parse --absolute-git-dir)
      [[ "$gitdir" == "$common" ]] || die "cannot locate primary checkout for separate Git metadata; set CREW_REPO to the primary project directory"
      CONFIG_ROOT=$(git -C "$REPO" rev-parse --show-toplevel) || die "configuration requires a project working directory"
    fi
  fi
}

project_manifest_validate() {
  jq -se 'length == 1 and (.[0] | type == "object" and (keys == ["files","source","version"]) and .version == 1 and (.source|type == "string" and length > 0) and (.files|type == "object") and all(.files|to_entries[]; (.key | test("^(agents|personas|teams|hooks)/[a-zA-Z0-9._/-]+$") and (contains("..")|not)) and (.value|type == "string" and test("^[0-9a-f]{64}$"))))' "$1" >/dev/null 2>&1 || die "invalid baseline provenance: $1"
}

# A preview binds both the source and current project bytes.
project_target_hash() {
  local file=$1
  [[ ! -L "$file" ]] || return 1
  if [[ -f "$file" ]]; then shasum -a 256 "$file" | awk '{print $1}'
  elif [[ ! -e "$file" ]]; then printf 'absent\n'
  else return 1; fi
}

# A partial project can refer to both its custom agents and missing baseline agents.
project_validate_planned_config() (
  local input=$1 project=$2 validation_base=$ROOT role filtered
  project_base() { printf '%s' "$validation_base"; }
  jq -se 'length == 1 and (.[0].roles | type == "object" and all(keys[]; test("^[a-z][a-z0-9-]*$")))' <<<"$input" >/dev/null 2>&1 || die "invalid agent configuration in $CONFIG_FILE"
  filtered=$(jq -c '.roles = {}' <<<"$input") || die "invalid agent configuration in $CONFIG_FILE"
  config_validate "$filtered"
  while IFS= read -r role; do
    validation_base=$ROOT
    [[ ! -f "$project/agents/$role/agent.json" ]] || validation_base=$project
    filtered=$(jq -c --arg role "$role" '.roles |= with_entries(select(.key == $role))' <<<"$input") || die "invalid agent configuration in $CONFIG_FILE"
    config_validate "$filtered"
  done < <(jq -r '.roles | keys[]' <<<"$input")
)

project_command() (
  local action=$1; shift
  local json=0 apply=0 arg rel src dest hash version manifest changed='[]' skipped='[]' lock stage backup snapshot manifest_tmp legacy config source_list target_hash
  local selected=() expected_hashes=() expected_targets=() sources=() source_hashes='{}' target_hashes='{}' index
  while (( $# )); do
    case "$1" in
      --json) json=1; shift ;;
      --apply) [[ "$action" == upgrade && $# -ge 6 && "$3" == --expect && "$4" =~ ^[0-9a-f]{64}$ && "$5" == --expect-target && ( "$6" == absent || "$6" =~ ^[0-9a-f]{64}$ ) ]] || die "--apply PATH requires --expect SOURCE_SHA256 --expect-target TARGET_SHA256_OR_absent from preview"; selected+=("$2"); expected_hashes+=("$4"); expected_targets+=("$6"); apply=1; shift 6 ;;
      *) die "unknown $action argument '$1'" ;;
    esac
  done
  project_root
  dest="$CONFIG_ROOT/.herdr-crew"; legacy="$CONFIG_ROOT/.herdr-crew.json"
  [[ ! -L "$dest" && ( ! -e "$dest" || -d "$dest" ) ]] || die "refusing invalid project configuration directory: $dest"
  if [[ -d "$dest" ]]; then
    [[ ! -e "$dest/config.json" || ( -f "$dest/config.json" && ! -L "$dest/config.json" ) ]] || die "invalid project configuration file: $dest/config.json"
    [[ -z "$(find "$dest" -type l -print -quit)" ]] || die "refusing symlinks in project configuration: $dest"
    [[ ! -e "$dest/baseline.json" ]] || project_manifest_validate "$dest/baseline.json"
    [[ "$action" != upgrade || -f "$dest/baseline.json" ]] || die "initialize project before upgrade"
  elif [[ "$action" == upgrade ]]; then die "initialize project before upgrade"; fi
  [[ ! -L "$legacy" ]] || die "refusing symlink configuration: $legacy"
  if [[ -f "$dest/config.json" ]]; then CONFIG_FILE="$dest/config.json"; config=$(cat "$CONFIG_FILE") || die "cannot read $CONFIG_FILE"
  elif [[ ! -d "$dest" && -f "$legacy" ]]; then CONFIG_FILE="$legacy"; config=$(cat "$legacy") || die "cannot read $legacy"
  else CONFIG_FILE="$dest/config.json"; config='{"version":1,"roles":{}}'; fi
  if [[ "$action" == init ]]; then project_validate_planned_config "$config" "$dest"
  else config_validate "$config"; fi
  [[ ! -e "$legacy" || ! -d "$dest" ]] || printf 'warning: legacy configuration retained at %s\n' "$legacy" >&2
  index=0
  for arg in ${selected[@]+"${selected[@]}"}; do
    [[ "$arg" =~ ^(agents|personas|teams|hooks)/[a-zA-Z0-9._/-]+$ && "$arg" != *..* && "$arg" != */./* && "$arg" != */ && "$arg" != *//* ]] || die "invalid upgrade path: $arg"
    [[ -f "$ROOT/$arg" && ! -L "$ROOT/$arg" ]] || die "unknown baseline path: $arg"
    hash=$(shasum -a 256 "$ROOT/$arg" | awk '{print $1}')
    [[ "$hash" == "${expected_hashes[$index]}" ]] || die "baseline changed since preview: $arg"
    target_hash=$(project_target_hash "$dest/$arg") || die "invalid upgrade destination: $arg"
    [[ "$target_hash" == "${expected_targets[$index]}" ]] || die "project file changed since preview: $arg"
    index=$((index + 1))
  done
  for arg in agents personas teams hooks; do
    [[ -d "$ROOT/$arg" && ! -L "$ROOT/$arg" ]] || continue
    [[ -z "$(find "$ROOT/$arg" -type l -print -quit)" ]] || die "refusing symlinks in baseline: $arg"
    while IFS= read -r -d '' src; do sources+=("${src#"$ROOT/"}"); done < <(find "$ROOT/$arg" -type f -print0)
  done
  [[ ${#sources[@]} -gt 0 && -d "$ROOT/agents" ]] || die "agent baseline is unavailable in $ROOT"
  source "$ROOT/lib/agent-definitions.sh"
  definitions_load "$ROOT" || die "invalid installed agent baseline"
  for rel in "${sources[@]}"; do
    [[ "$rel" =~ ^(agents|personas|teams|hooks)/[a-zA-Z0-9._/-]+$ && "$rel" != *..* ]] || die "invalid baseline path: $rel"
    src="$ROOT/$rel"
    if [[ "$action" == init ]]; then
      if [[ -e "$dest/$rel" ]]; then skipped=$(jq -c --arg p "$rel" '. + [$p]' <<<"$skipped"); else changed=$(jq -c --arg p "$rel" '. + [$p]' <<<"$changed"); fi
    elif ! cmp -s "$src" "$dest/$rel"; then
      hash=$(shasum -a 256 "$src" | awk '{print $1}')
      changed=$(jq -c --arg p "$rel" '. + [$p]' <<<"$changed")
      source_hashes=$(jq -c --arg p "$rel" --arg h "$hash" '.[$p]=$h' <<<"$source_hashes")
      target_hash=$(project_target_hash "$dest/$rel") || die "invalid upgrade destination: $rel"
      target_hashes=$(jq -c --arg p "$rel" --arg h "$target_hash" '.[$p]=$h' <<<"$target_hashes")
    fi
  done
  if [[ "$action" == init && ! -e "$dest/config.json" ]]; then changed=$(jq -c '. + ["config.json"]' <<<"$changed"); fi
  if [[ "$action" == init && ! -e "$dest/baseline.json" ]]; then changed=$(jq -c '. + ["baseline.json"]' <<<"$changed"); fi
  if [[ "$action" == upgrade && "$apply" == 1 ]]; then changed='[]'; for rel in ${selected[@]+"${selected[@]}"}; do changed=$(jq -c --arg p "$rel" 'if index($p) == null then . + [$p] else . end' <<<"$changed"); done; fi
  if [[ -z "${CREW_DRY_RUN:-}" && ( "$action" == init || "$apply" == 1 ) && "$changed" != "[]" ]]; then
    lock="$CONFIG_ROOT/.herdr-crew.lock"
    mkdir "$lock" 2>/dev/null || die "project setup is locked: $lock"
    stage=''; backup=''; snapshot=''; manifest_tmp=''
    trap 'if [[ -n "$backup" && -d "$backup" && ! -e "$dest" ]]; then mv "$backup" "$dest"; fi; [[ -z "$stage" ]] || rm -rf "$stage"; [[ -z "$snapshot" ]] || rm -rf "$snapshot"; [[ -z "$manifest_tmp" ]] || rm -f "$manifest_tmp"; rmdir "$lock" 2>/dev/null || :' EXIT
    stage=$(mktemp -d "$CONFIG_ROOT/.herdr-crew-stage.XXXXXX") || die "cannot create staging directory"
    if [[ -d "$dest" ]]; then cp -R "$dest/." "$stage/" || die "cannot stage project configuration"; fi
    [[ -z "$(find "$stage" -type l -print -quit)" ]] || die "refusing symlink in staged configuration"
    if [[ -d "$dest" ]]; then
      snapshot=$(mktemp -d "$CONFIG_ROOT/.herdr-crew-snapshot.XXXXXX") || die "cannot create snapshot"
      cp -R "$stage/." "$snapshot/" || die "cannot snapshot project configuration"
      diff -qr "$snapshot" "$dest" >/dev/null || die "project configuration changed during staging; retry"
    fi
    version=$(git -C "$ROOT" describe --tags --always 2>/dev/null || printf 'dev')
    manifest="$stage/baseline.json"
    if [[ ! -e "$manifest" ]]; then jq -n --arg version "$version" '{version:1,source:$version,files:{}}' > "$manifest"; fi
    for rel in "${sources[@]}"; do
      if [[ "$action" == init ]]; then [[ ! -e "$stage/$rel" ]] || continue
      else [[ " $(printf '%s ' ${selected[@]+"${selected[@]}"})" == *" $rel "* ]] || continue; fi
      src="$ROOT/$rel"
      arg="$src"
      while [[ "$arg" != "$ROOT" ]]; do
        [[ ! -L "$arg" ]] || die "refusing baseline symlink: $rel"
        arg=$(dirname "$arg")
      done
      hash=$(shasum -a 256 "$src" | awk '{print $1}')
      if [[ "$action" == upgrade ]]; then
        index=0
        for arg in ${selected[@]+"${selected[@]}"}; do
          if [[ "$arg" == "$rel" ]]; then [[ "$hash" == "${expected_hashes[$index]}" ]] || die "baseline changed since preview: $rel"; fi
          index=$((index + 1))
        done
      fi
      mkdir -p "$(dirname "$stage/$rel")" || die "cannot stage $rel"
      cp "$src" "$stage/$rel" || die "cannot stage $rel"
      [[ "$hash" == "$(shasum -a 256 "$stage/$rel" | awk '{print $1}')" && "$hash" == "$(shasum -a 256 "$src" | awk '{print $1}')" ]] || die "baseline changed while staging: $rel"
      manifest_tmp=$(mktemp "$CONFIG_ROOT/.herdr-crew-manifest.XXXXXX") || die "cannot create provenance temporary file"
      jq --arg rel "$rel" --arg hash "$hash" --arg version "$version" '.source=$version | .files[$rel]=$hash' "$manifest" > "$manifest_tmp" || die "cannot update baseline provenance"
      mv "$manifest_tmp" "$manifest"; manifest_tmp=''
    done
    [[ -e "$stage/config.json" ]] || printf '%s\n' "$config" > "$stage/config.json"
    project_manifest_validate "$manifest"
    [[ -f "$stage/config.json" && ! -L "$stage/config.json" ]] || die "invalid staged project configuration"
    definitions_load "$stage" || die "invalid staged agent definitions"
    ( project_base() { printf '%s' "$stage"; }; CONFIG_FILE="$stage/config.json"; config_validate "$(cat "$CONFIG_FILE")" )
    if [[ -d "$dest" ]]; then
      diff -qr "$snapshot" "$dest" >/dev/null || die "project configuration changed during staging; retry"
      index=0
      for arg in ${selected[@]+"${selected[@]}"}; do
        target_hash=$(project_target_hash "$dest/$arg") || die "invalid upgrade destination: $arg"
        [[ "$target_hash" == "${expected_targets[$index]}" ]] || die "project file changed since preview: $arg"
        index=$((index + 1))
      done
      backup="$stage.old"
      [[ ! -e "$backup" && ! -L "$backup" ]] || die "recovery path already exists: $backup"
      mv "$dest" "$backup" || die "cannot stage existing configuration"
      diff -qr "$snapshot" "$backup" >/dev/null || die "project configuration changed during staging; retry"
    fi
    mv "$stage" "$dest" || die "cannot install project configuration"
    stage=''
    if [[ -n "$backup" ]]; then
      printf 'warning: prior project configuration retained for recovery: %s\n' "$backup" >&2
      backup=''
    fi
  fi
  if [[ "$json" == 1 ]]; then jq -nc --arg project "$CONFIG_ROOT" --arg action "$action" --argjson changed "$changed" --argjson skipped "$skipped" --argjson hashes "$source_hashes" --argjson targets "$target_hashes" '{project:$project,action:$action,changed:$changed,skipped:$skipped,sourceHashes:$hashes,targetHashes:$targets}'
  else
    printf '%s: %s\n' "$action" "$CONFIG_ROOT"
    if [[ "$action" == upgrade && "$apply" == 0 ]]; then jq -nr --argjson sources "$source_hashes" --argjson targets "$target_hashes" '$sources | to_entries[] | "\(.key)  \(.value)  \($targets[.key])"'
    else jq -r '.[]' <<<"$changed"; fi
  fi
)
