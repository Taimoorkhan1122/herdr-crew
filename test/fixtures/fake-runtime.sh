#!/usr/bin/env bash

install_fake_runtime() {
  if [[ $# != 2 ]]; then
    printf 'usage: install_fake_runtime FAKE STATE\n' >&2
    return 2
  fi

  local fake=$1 state=$2
  mkdir -p "$fake" "$state"
  STATE=$state
  export STATE

  cat >"$fake/hc" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

log_call() { jq -nc --args '$ARGS.positional' -- hc "$@" >>"$LOG"; }
has_term() { [[ -f "$STATE/term.$1" ]]; }
missing() { printf '{"error":{"kind":"missing"}}\n' >&2; exit 3; }

log_call "$@"
command=${1:-}; shift || true
case "$command" in
  get)
    terminal=${1:-}; shift || true
    has_term "$terminal" || missing
    if [[ -f "$STATE/get-seq.$terminal" ]]; then
      next=$(head -1 "$STATE/get-seq.$terminal")
      sed '1d' "$STATE/get-seq.$terminal" >"$STATE/get-seq.$terminal.tmp"
      mv "$STATE/get-seq.$terminal.tmp" "$STATE/get-seq.$terminal"
      if [[ "$next" == null ]]; then
        jq '.status = null' "$STATE/term.$terminal" >"$STATE/term.$terminal.tmp"
      else
        jq --arg status "$next" '.status = $status' "$STATE/term.$terminal" >"$STATE/term.$terminal.tmp"
      fi
      mv "$STATE/term.$terminal.tmp" "$STATE/term.$terminal"
    elif [[ -f "$STATE/auto-ready" ]] && [[ $(jq -r '.status // empty' "$STATE/term.$terminal") == "" ]]; then
      jq '.status = "idle"' "$STATE/term.$terminal" >"$STATE/term.$terminal.tmp"
      mv "$STATE/term.$terminal.tmp" "$STATE/term.$terminal"
    fi
    jq -nc --arg address "$terminal" --argjson term "$(cat "$STATE/term.$terminal")" '{
      address: $address,
      state: ($term.state // "running"),
      status: (if ($term.status // null) == null then null else {state: $term.status} end),
      labels: ($term.labels // {}),
      argv: ($term.argv // []),
      pid: ($term.pid // null),
      turn: ($term.turn // 0)
    }'
    ;;
  ls)
    terms='[]'
    for file in "$STATE"/term.*; do
      [[ -f "$file" ]] || continue
      address=${file##*/term.}
      terminal=$(jq -nc --arg address "$address" --argjson term "$(cat "$file")" '{address:$address,state:($term.state // "running"),status:(if ($term.status // null) == null then null else {state:$term.status} end),labels:($term.labels // {}),argv:($term.argv // []),pid:($term.pid // null)}')
      terms=$(jq --argjson terminal "$terminal" '. + [$terminal]' <<<"$terms")
    done
    jq -nc --argjson terms "$terms" '{terminals:$terms}'
    ;;
  send)
    terminal=${1:-}; shift || true
    has_term "$terminal" || missing
    if [[ $(jq -r '.status // empty' "$STATE/term.$terminal") == blocked ]]; then
      printf '{"error":{"kind":"blocked"}}\n' >&2
      exit 9
    fi
    send_exit=$(jq -r '.sendExit // 0' "$STATE/term.$terminal")
    if [[ "$send_exit" == 9 ]]; then
      printf '{"error":{"kind":"blocked"}}\n' >&2
      exit 9
    elif [[ "$send_exit" == 3 ]]; then
      missing
    fi
    message=${1:-}
    printf '%s\n' "$message" >>"$STATE/sent.$terminal"
    if [[ "$message" == "/exit" ]]; then
      # The app wrapper returns to a shell prompt when the agent exits normally.
      jq '.status = null | .turn = ((.turn // 0) + 1)' "$STATE/term.$terminal" >"$STATE/term.$terminal.tmp"
      mv "$STATE/term.$terminal.tmp" "$STATE/term.$terminal"
      printf '%s\n' 'fixture shell %' >"$STATE/screen.$terminal"
    elif [[ -f "$STATE/ambiguous" ]]; then
      printf '%s\n' 'unrelated screen' >"$STATE/screen.$terminal"
    elif [[ -f "$STATE/quick-done" ]]; then
      jq '.status = "done" | .turn = ((.turn // 0) + 1)' "$STATE/term.$terminal" >"$STATE/term.$terminal.tmp"
      mv "$STATE/term.$terminal.tmp" "$STATE/term.$terminal"
    elif [[ $(jq -r '.swallow // false' "$STATE/term.$terminal") == true ]]; then
      printf '%s\n' "$message" >"$STATE/screen.$terminal"
    elif [[ $(jq -r '.keepTurn // false' "$STATE/term.$terminal") == true ]]; then
      jq '.status = "working"' "$STATE/term.$terminal" >"$STATE/term.$terminal.tmp"
      mv "$STATE/term.$terminal.tmp" "$STATE/term.$terminal"
    else
      jq '.status = "working" | .turn = ((.turn // 0) + 1)' "$STATE/term.$terminal" >"$STATE/term.$terminal.tmp"
      mv "$STATE/term.$terminal.tmp" "$STATE/term.$terminal"
    fi
    printf '{"started":true}\n'
    ;;
  keys|read|wait|kill|label)
    terminal=${1:-}; shift || true
    has_term "$terminal" || missing
    case "$command" in
      read)
        cat "$STATE/screen.$terminal" 2>/dev/null || true
        ;;
      keys)
        keys="$*"
        if [[ "$keys" == "down enter" ]] && rg -qiF 'trust this folder' "$STATE/screen.$terminal" 2>/dev/null; then
          jq '.status = "idle"' "$STATE/term.$terminal" >"$STATE/term.$terminal.tmp"
          mv "$STATE/term.$terminal.tmp" "$STATE/term.$terminal"
        elif [[ "$keys" == enter && $(jq -r '.swallow // false' "$STATE/term.$terminal") == true ]]; then
          jq '.status = "working" | .turn = ((.turn // 0) + 1)' "$STATE/term.$terminal" >"$STATE/term.$terminal.tmp"
          mv "$STATE/term.$terminal.tmp" "$STATE/term.$terminal"
        fi
        ;;
      wait)
        reason=timeout
        if [[ -f "$STATE/wait-status.$terminal" ]]; then
          wait_status=$(cat "$STATE/wait-status.$terminal")
          jq --arg status "$wait_status" '.status = $status' "$STATE/term.$terminal" >"$STATE/term.$terminal.tmp"
          mv "$STATE/term.$terminal.tmp" "$STATE/term.$terminal"
          rm -f "$STATE/wait-status.$terminal"
          reason=status
        fi
        jq -nc --arg reason "$reason" --argjson term "$(cat "$STATE/term.$terminal")" '{ended:false,reason:$reason,status:($term.status // null),turn:($term.turn // 0),exit_code:null,signal:null,children:[],from:null}'
        ;;
      kill)
        jq '.state = "finished"' "$STATE/term.$terminal" >"$STATE/term.$terminal.tmp"
        mv "$STATE/term.$terminal.tmp" "$STATE/term.$terminal"
        ;;
      label)
        pair=${1:-}
        key=${pair%%=*}; value=${pair#*=}
        jq --arg key "$key" --arg value "$value" '.labels = (.labels // {}) | .labels[$key] = $value' "$STATE/term.$terminal" >"$STATE/term.$terminal.tmp"
        mv "$STATE/term.$terminal.tmp" "$STATE/term.$terminal"
        ;;
    esac
    ;;
  *)
    printf '{"error":{"kind":"unsupported","command":"%s"}}\n' "$command" >&2
    exit 2
    ;;
esac
SH

  cat >"$fake/sleep" <<'SH'
#!/usr/bin/env bash
if [[ -f "$STATE/watch-mutations" ]]; then
  while IFS=$'\t' read -r terminal status; do
    if [[ "$status" == gone ]]; then
      rm -f "$STATE/term.$terminal"
    else
      jq --arg status "$status" '.status = $status' "$STATE/term.$terminal" >"$STATE/term.$terminal.tmp"
      mv "$STATE/term.$terminal.tmp" "$STATE/term.$terminal"
    fi
  done <"$STATE/watch-mutations"
  rm -f "$STATE/watch-mutations"
fi
exit 0
SH

  cat >"$fake/herdr-app" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

log_call() { jq -nc --args '$ARGS.positional' -- herdr-app "$@" >>"$LOG"; }
option_value() {
  local option=$1
  shift
  while [[ $# -gt 1 ]]; do
    if [[ "$1" == "$option" ]]; then printf '%s' "$2"; return 0; fi
    shift 2
  done
  return 1
}
next_id() {
  local kind=$1 prefix=$2 count=0
  [[ ! -f "$STATE/next.$kind" ]] || count=$(cat "$STATE/next.$kind")
  count=$((count + 1))
  printf '%s\n' "$count" >"$STATE/next.$kind"
  printf '%s%s' "$prefix" "$count"
}
new_terminal() {
  local terminal=$1 pane=$2 argv=$3 space=$4 tab=$5 name=$6
  local status=null send_exit=0 swallow=false keep_turn=false
  [[ ! -f "$STATE/status-on-create" ]] || status=$(cat "$STATE/status-on-create")
  [[ ! -f "$STATE/send-exit-on-create" ]] || send_exit=$(cat "$STATE/send-exit-on-create")
  [[ ! -f "$STATE/swallow-send-on-create" ]] || swallow=true
  [[ ! -f "$STATE/keep-turn-on-create" ]] || keep_turn=true
  jq -n --arg address "$terminal" --arg pane "$pane" --arg space "$space" --arg tab "$tab" --arg name "$name" --arg status "$status" --argjson argv "$argv" --argjson send_exit "$send_exit" --argjson swallow "$swallow" --argjson keep_turn "$keep_turn" '{agent:$name,status:(if $status == "null" then null else $status end),state:"running",turn:0,sendExit:$send_exit,swallow:$swallow,keepTurn:$keep_turn,argv:$argv,labels:{"herdr.space":$space,"herdr.tab":$tab},pid:null,address:$address,pane:$pane}' >"$STATE/term.$terminal"
  [[ ! -f "$STATE/status-sequence-on-create" ]] || cp "$STATE/status-sequence-on-create" "$STATE/get-seq.$terminal"
  [[ ! -f "$STATE/screen-on-create" ]] || cp "$STATE/screen-on-create" "$STATE/screen.$terminal"
}
rebuild_ls() {
  local tabs='[]' terms='{}' file id term tab
  for file in "$STATE"/term.*; do
    [[ -f "$file" ]] || continue
    id=${file##*/term.}
    term=$(cat "$file")
    terms=$(jq --arg id "$id" --argjson term "$term" '.[$id] = $term' <<<"$terms")
  done
  for file in "$STATE"/tab.*; do
    [[ -f "$file" ]] || continue
    tab=$(jq --argjson terms "$terms" '.terminals |= map(. as $entry | .status = ($terms[$entry.terminal].status // null))' "$file")
    tabs=$(jq --argjson tab "$tab" '. + [$tab]' <<<"$tabs")
  done
  if [[ -f "$STATE/space" ]]; then
    jq -n --argjson space "$(cat "$STATE/space")" --argjson tabs "$tabs" '{spaces:[{id:$space.id,name:$space.name,folder:$space.folder,tabs:$tabs}]}' >"$STATE/ls.json"
  else
    printf '{"spaces":[]}\n' >"$STATE/ls.json"
  fi
}

if [[ ${1:-} == status ]]; then
  [[ ! -f "$STATE/no-window" ]] || exit 1
  printf '{"space":"sp1"}\n'
  exit 0
fi
log_call "$@"
[[ ${1:-} == do ]] || {
  if [[ ${1:-} == ls ]]; then
    if [[ -f "$STATE/ls.json" ]]; then jq -c . "$STATE/ls.json"; else printf '{"spaces":[]}\n'; fi
    exit 0
  fi
  printf '{"error":{"kind":"unsupported"}}\n' >&2
  exit 2
}
shift
operation=${1:-}; shift || true
case "$operation" in
  space.new)
    name=$(option_value --name "$@")
    folder=$(option_value --folder "$@")
    tab_name=$(option_value --tab "$@" || true)
    argv=$(option_value --argv "$@" || printf '[]')
    [[ -n "$name" && -n "$folder" ]] || exit 2
    jq -n --arg id "$(next_id space sp)" --arg name "$name" --arg folder "$folder" '{id:$id,name:$name,folder:$folder}' >"$STATE/space"
    space=$(jq -r '.id' "$STATE/space")
    if [[ -z "$tab_name" ]]; then
      rebuild_ls
      jq -nc --arg space "$space" '{space:$space}'
      exit 0
    fi
    tab=$(next_id tab tb); pane=$(next_id pane p); terminal=$(next_id terminal t)
    new_terminal "$terminal" "$pane" "$argv" "$space" "$tab" "$tab_name"
    jq -n --arg id "$tab" --arg name "$tab_name" --arg space "$space" --arg terminal "$terminal" --arg pane "$pane" '{id:$id,name:$name,space:$space,terminals:[{terminal:$terminal,pane:$pane,status:null,app:"",name:$name,sub_agents:[]}]}' >"$STATE/tab.$tab"
    rebuild_ls
    jq -nc --arg space "$space" --arg tab "$tab" --arg terminal "$terminal" '{space:$space,tab:$tab,terminal:$terminal}'
    ;;
  tab.new)
    space=$(option_value --space "$@"); name=$(option_value --name "$@"); folder=$(option_value --folder "$@"); argv=$(option_value --argv "$@" || printf '[]')
    [[ -n "$space" && -n "$name" && -n "$folder" && -f "$STATE/space" ]] || exit 2
    [[ $(jq -r '.id' "$STATE/space") == "$space" ]] || exit 3
    tab=$(next_id tab tb); pane=$(next_id pane p); terminal=$(next_id terminal t)
    new_terminal "$terminal" "$pane" "$argv" "$space" "$tab" "$name"
    jq -n --arg id "$tab" --arg name "$name" --arg space "$space" --arg terminal "$terminal" --arg pane "$pane" '{id:$id,name:$name,space:$space,terminals:[{terminal:$terminal,pane:$pane,status:null,app:"",name:$name,sub_agents:[]}]}' >"$STATE/tab.$tab"
    rebuild_ls
    jq -nc --arg space "$space" --arg tab "$tab" --arg terminal "$terminal" '{space:$space,tab:$tab,terminal:$terminal}'
    ;;
  pane.split)
    direction=$(option_value --direction "$@"); parent=$(option_value --pane "$@"); argv=$(option_value --argv "$@" || printf '[]')
    [[ "$direction" == right || "$direction" == down ]] || exit 2
    found=
    for file in "$STATE"/tab.*; do
      [[ -f "$file" ]] || continue
      if jq -e --arg pane "$parent" 'any(.terminals[]; .pane == $pane)' "$file" >/dev/null; then found=$file; break; fi
    done
    [[ -n "$found" ]] || { printf '{"error":{"kind":"missing"}}\n' >&2; exit 3; }
    space=$(jq -r '.space' "$found"); tab=${found##*/tab.}; name=$(jq -r '.name' "$found")
    pane=$(next_id pane p); terminal=$(next_id terminal t)
    new_terminal "$terminal" "$pane" "$argv" "$space" "$tab" "$name"
    jq --arg terminal "$terminal" --arg pane "$pane" --arg name "$name" '.terminals += [{terminal:$terminal,pane:$pane,status:null,app:"",name:$name,sub_agents:[]}]' "$found" >"$found.tmp"
    mv "$found.tmp" "$found"
    rebuild_ls
    jq -nc --arg pane "$pane" --arg terminal "$terminal" '{pane:$pane,terminal:$terminal}'
    ;;
  tab.close)
    tab=$(option_value --id "$@"); confirmed=$(option_value --confirmed "$@")
    [[ "$confirmed" == true && -f "$STATE/tab.$tab" ]] || exit 2
    while IFS= read -r terminal; do rm -f "$STATE/term.$terminal"; done < <(jq -r '.terminals[].terminal' "$STATE/tab.$tab")
    rm -f "$STATE/tab.$tab"
    rebuild_ls
    printf '{"ok":true}\n'
    ;;
  tab.rename)
    tab=$(option_value --id "$@"); name=$(option_value --name "$@")
    [[ -f "$STATE/tab.$tab" && -n "$name" ]] || exit 2
    jq --arg name "$name" '.name = $name' "$STATE/tab.$tab" >"$STATE/tab.$tab.tmp"
    mv "$STATE/tab.$tab.tmp" "$STATE/tab.$tab"
    rebuild_ls
    printf '{"ok":true}\n'
    ;;
  *)
    printf '{"error":{"kind":"unsupported","operation":"%s"}}\n' "$operation" >&2
    exit 2
    ;;
esac
SH

  chmod +x "$fake/hc" "$fake/herdr-app" "$fake/sleep"
}

# Model an earlier team leaving its terminals before a subsequent launch.
retire_fake_task() {
  local task=$1 file terminal
  for file in "$HOME"/.herdr/crew/*/*.meta; do
    [[ -f "$file" ]] || continue
    grep -qxF "task=$task" "$file" || continue
    terminal=$(sed -n 's/^terminal=//p' "$file" | head -1)
    [[ -f "$STATE/term.$terminal" ]] || continue
    jq '.state = "finished"' "$STATE/term.$terminal" >"$STATE/term.$terminal.tmp"
    mv "$STATE/term.$terminal.tmp" "$STATE/term.$terminal"
  done
}
