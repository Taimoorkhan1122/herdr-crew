# Herdr app capability and limitation audit (for crew launcher)

Sources (primary, installed):
- `herdr-app --version`: `herdr-app 0.1.11` ([`/Users/gok/.local/bin/herdr-app`])
- `herdr-app --skill` ([`/tmp/herdr_skill.txt`])
- `herdr-app commands` ([`/tmp/herdr_commands.txt`], exit 0)
- `herdr-app ls` / `herdr-app status` ([live run 2026-11-02], exit 0)
- Config/home: [`~/.config/herdr-app/AGENTS.md`], [`herdr.d.ts`](~/.config/herdr-app/herdr.d.ts), [`gpui-kit.d.ts`](~/.config/herdr-app/gpui-kit.d.ts), [`settings.json`](~/.config/herdr-app/settings.json), [`shared.json`](~/.config/herdr-app/shared.json), [`view.json`](~/.config/herdr-app/view.json), [`layouts/main.json`](~/.config/herdr-app/layouts/main.json)
- Mods: [`mods/*/mod.json`](~/.config/herdr-app/mods/*/mod.json), shipped examples (agents/tabs/pane/spaces/workspace-status/files/changes)
- Core: [`hc --help`](~/.local/bin/hc), `hc ls --json`, `hc machine ls` ([live run])

Constraints followed: read-only; no `herdr-app do` mutators executed; recorded command+exit codes; marked inferred where needed.

## Command surface (`herdr-app commands`, `ls`, `status`)

### Takeaway
`herdr-app` is a control client for the running window (does not launch window on inspect commands). `commands` enumerates every built-in command with args/required flags and descriptions; `ls` returns spaces/tabs/terminals in the open window; `status` returns current layout/focus/overlays/zoom/errors. Mutators are invoked via `herdr-app do <cmd> [--args ... | JSON]` and return `{...ids...}` or `{ "error": "..." }` with exit 1 on error.

### Cited Findings
- `herdr-app --skill` says: "Inspect before acting: `herdr-app ls` ... `herdr-app status` ... `herdr-app commands`". "`ls` and `status` talk to the running window, not a new app. `commands` prints the built-in command list even without an open window. Do not launch bare `herdr-app` to inspect it: that opens or raises the window." — [`/tmp/herdr_skill.txt:1-80`](file:///tmp/herdr_skill.txt)
- Default-target hazard: most commands allow omitted targets, so they fall back to the focused space/tab/pane (`tab.new` needs nothing; `pane.split` needs only `direction`; `pane.close`/`pane.zoom`/`terminal.open` need nothing). Docs warn only that *unknown argument names* fail — omitted optional targets still act on focus. A launcher must always pass explicit ids. — [`/tmp/herdr_commands.txt`](file:///tmp/herdr_commands.txt), [`~/.config/herdr-app/AGENTS.md:497-545`](~/.config/herdr-app/AGENTS.md)
- `herdr-app --help`: lists `ls`, `do`, `feedback`, `commands`, `status`, `shot`, `check`, `--skill`, `--version`. Home `~/.config/herdr-app` or `$HERDR_APP_HOME`. Terminals run in `hc`. — [`/tmp/h_help.txt`](file:///tmp/h_help.txt)
- `herdr-app commands` (691 lines JSON) includes all built-ins: spaces (`space.new/close/rename/move/select/next/prev`), tabs (`tab.new/close/rename/move/select/next/prev/settle/unsettle`), panes (`pane.split/close/focus/go/swap/zoom`), terminals (`terminal.open/keep/park/peek/show/copy/paste/paste_image/right_click/kill`), agents (`agent.focus/next/prev`), layout/mod/app/window commands as listed. Args show required/optional; e.g. `space.move` requires `id,index`; `pane.split` requires `direction` (optional `pane/argv/mod/props`); `tab.new` takes optional `name,space,folder,argv,task,mod,props`. — [`/tmp/herdr_commands.txt`](file:///tmp/herdr_commands.txt)
- Error shapes from probes (exit 1, stdout JSON): `{"error":"pane.split needs direction"}`, `{"error":"pane.split direction is \"right\" or \"down\", not Some(\"sideways\")"}`, `{"error":"tab.rename: unknown argument(s): bogus; valid arguments: id, name"}`, unknown command gives similar error. `do` with `--help` gives `{"error":"unknown command \"--help\": see ... a mod's are <mod>.<command> and need the mod loaded"}`. — [`/tmp/o.txt` / probe runs]
- `herdr-app ls` (live): returns `{"spaces":[{id,name,folder,machine,active,tabs:[{id,name,active,settled,terminals:[{terminal,pane,status,app,name,sub_agents}]}]}], "recent":[]}`. Example shows `spdc6f02dc4372f0de60ea8d526c51b3db` (fox-and-cub, /Users/gok, machine null, active) with tab `tb3d621f87c7cbc7092c57591fabc239f8` "Claude Code" containing terminal `t22` (pane `pa9dab01cacd3f2fd7be13b4e01758a53`, status idle, app claude-code). Another space `sp94e14a64379d75ae767f24c029df9d50` (herdr-crew, folder /Users/gok/git/fox-and-cub, machine null) has tabs "1" and "2" with `t24` (working, opencode) and `t25` (working, opencode). — [`/tmp/herdr_ls.txt`](file:///tmp/herdr_ls.txt)
- `herdr-app status` (live): `{"zoom":1.0,"font_size":14.0,"ui_font_size":13.0,"space":"spdc6f02dc4372f0de60ea8d526c51b3db","tab":"tb3d621f87c7cbc7092c57591fabc239f8","focused_pane":"pa9dab01cacd3f2fd7be13b4e01758a53","layout":"main","agent":"t22","floats":{},"overlays":[],"errors":[]}`. — [`/tmp/herdr_status.txt`](file:///tmp/herdr_status.txt)
- `herdr-app shot` needs `.png` and running window with drawn frame; saves frame (includes terminals/images/overlays/floats) at full pixel size, no permissions needed. `HERDR_APP_HOME` selects window. — [`/tmp/h_help.txt`](file:///tmp/h_help.txt), [`~/.config/herdr-app/AGENTS.md:63-74`](~/.config/herdr-app/AGENTS.md)
- `herdr-app check <mod>` loads mod once (exits nonzero with exact error). `herdr-app feedback "<text>"` drafts feedback for person review (does not send silently). — [`/tmp/h_help.txt`](file:///tmp/h_help.txt), [`~/.config/herdr-app/AGENTS.md:49-61,945-945`](~/.config/herdr-app/AGENTS.md)
- Destructive commands ask the person unless `confirmed` is passed: `space.close {id?, confirmed?}`, `tab.close {id?, confirmed?}`. "Close a space and end its terminals (asks first unless confirmed)"; closing a space's last tab closes the space. An agent caller that omits `confirmed` gets a dialog, not a completed close. — [`/tmp/herdr_commands.txt`](file:///tmp/herdr_commands.txt), [`~/.config/herdr-app/AGENTS.md:497-545`](~/.config/herdr-app/AGENTS.md)
- Agent navigation: `agent.focus {terminal}` shows an agent (sub-agents too); `agent.next`/`agent.prev` follow the order the agents list supplies via `setAgentOrder(addresses)` (in memory; missing agents ignored, new appended). So a crew board that renders a custom order also owns that keyboard order. — [`/tmp/herdr_commands.txt`](file:///tmp/herdr_commands.txt), [`~/.config/herdr-app/herdr.d.ts:200-210`](~/.config/herdr-app/herdr.d.ts)

### Inferences
- `do` is the mutator surface; `commands` is authoritative for exact arg shapes. Errors are structured JSON with actionable messages.
- `ls` gives stable IDs (spaces/tabs/panes/terminals) and `status` gives current focus/layout; together suitable for deterministic discovery by ID.

### Gaps
- No JSON schema for `do` result shapes beyond examples in skill (`{ "pane": "...", "terminal": "..." }` or `{ "error": "..." }`); need to inspect actual results from non-mutating/controlled calls if possible (read-only constraint prevents generating new structure). Inferred from skill/AGENTS.
- Full `commands` JSON is long (691 lines) — summarized structure; exact per-command arg validation details are in the list.

## Spaces/tabs/panes model

### Takeaway
Hierarchy: Space (machine-scoped, has folder/name/status) contains Tabs; Tab contains Panes (terminal panes or mod panes). Focus/zoom/settled are screen-local (`view.json`). Commands allow creating/selecting/moving/renaming/closing spaces/tabs and splitting/focusing/swapping/zooming/closing panes; terminal lifecycle via `terminal.open/keep/park/peek/show/copy/paste/kill`. Split direction only `right` or `down`. Ratio/size control is limited to layout/node sizing (`layout.resize`) not explicit split ratio args on `pane.split`.

### Cited Findings
- Model: "A **space** is a place to work, on one machine..." names follow repo/folder or `~` if unnamed; once named stays. "A **tab** is a piece of work in a space..." unnamed called by position. "A **tab** can be **settled** (`tab.settle`)..." hidden/folded by mods; brought back when shown or agent needs user. "A **pane** is a terminal on screen, or a **mod** beside them..." closing terminal pane ends terminal; program exit closes pane. Terminal panes kept by core (`keep: true`); lost terminal gets shell in last folder same address (original command not rerun). Splits/mod panes stay. — [`~/.config/herdr-app/AGENTS.md:92-163`](~/.config/herdr-app/AGENTS.md)
- Commands (from `commands`): `space.new` args `name?,folder?,tab?,argv?,task?,machine?` (machine from `hc machine ls`; defaults to this one; terminals start in that machine's home unless folder). `space.move(id,index)`, `space.rename(id?,name)`, `space.close(id?,confirmed?)`. `tab.new` args `name?,space?,folder?,argv?,task?,mod?,props?` (or mod pane tab). `tab.move(id,index)`, `tab.rename(id?,name)`, `tab.settle(id?)`, `tab.unsettle(id?)`. `pane.split(direction,pane?,argv?,mod?,props?)` direction `right` or `down`. `pane.close(pane?)`, `pane.zoom(pane?)`, `pane.focus(pane?,terminal?)`, `pane.go(direction)`, `pane.swap(direction)`. `terminal.open(argv?,folder?,place?,name?)` place default tab or `right`/`down`. `terminal.keep(terminal,place?)`, `terminal.park(terminal)`, `terminal.peek(terminal)`, `terminal.show(terminal?,pane?)`. — [`/tmp/herdr_commands.txt`](file:///tmp/herdr_commands.txt)
- Layout/pane arrangement: `layouts/main.json` shows root row with sidebar (spaces/agents mods) and work column (tabs block, work-body row with main block containing tab's panes arranged by pane config, plus optional panel stack). Pane config in layout block content: `"pane": {"gap":8,"radius":10,"background":"background","lone":true,"border":{...},"focus":{...},"header":{"content":{"mod":"pane"},...}}`. Layout nodes support `size {px|weight}`, `min/max`, `resizable`, `movable` (inheritable; panes draggable by grip, center swap/edge drop), `gap`, `divider`. Root `titlebar:"none"`, traffic lights positions. — [`~/.config/herdr-app/layouts/main.json`](~/.config/herdr-app/layouts/main.json), [`~/.config/herdr-app/AGENTS.md:165-360`](~/.config/herdr-app/AGENTS.md)
- `herdr.d.ts` PaneInfo: `pane, terminal|null, mod?, tab, title, cwd, branch, status, app, program, focused, zoomed, movable`. `panes()` lists all panes; `focused()` gives context (pane/terminal may be null if layout terminal block focused). — [`~/.config/herdr-app/herdr.d.ts:180-240`](~/.config/herdr-app/herdr.d.ts)
- Live state at capture: `ls` showed one terminal per tab, so splits were not exercised in this snapshot; `view.json` tracks `focused` pane per tab plus `before/zoomed/settled` (screen-local), and `herdr-app status` names only the focused pane. Splits therefore add panes/terminals to the tab list but no geometry is recorded in either file. — [`/tmp/herdr_ls.txt`](file:///tmp/herdr_ls.txt), [`~/.config/herdr-app/view.json`](~/.config/herdr-app/view.json), [`/tmp/herdr_status.txt`](file:///tmp/herdr_status.txt)

### Inferences
- `pane.split` creates adjacent pane (right/down) with new terminal or mod; no explicit ratio parameter in args. Layout-level sizing controls distribution via node `size/weight/gap/divider` and `layout.resize` on layout nodes. A specific complex layout (e.g. 2x2 with board under Lead) is expressible via layout tree structure, but ratios/splits are controlled by layout structure/resizing rather than `pane.split` ratio args.
- Focus behavior: `pane.focus` can take pane or terminal; `pane.go` moves focus directionally; zoom toggles single-pane view.
- **A tab is a binary split tree, not a grid**: only `right`/`down` splits exist, so 2x2 = split right, then split each side down. There is no "split at 30%" and no "put pane left of pane X" command.
- **Arrangement is not readable from the CLI.** `ls` lists a tab's terminals flat (terminal, pane, status, app, name, sub_agents) with no direction/order/size; `status` gives only `focused_pane`; `view.json` has per-tab `focused/before/zoomed/settled` but no geometry. So a launcher cannot verify "board is under Lead" after building it — only that both panes exist in the tab.
- **The human can rearrange panes afterwards**: `movable` (default true) lets them drag a pane by the top-center grip (edge drop places beside, center drop swaps) and drag dividers. A launcher must treat its built arrangement as a starting point, not a guarantee, unless the layout sets `movable: false` and `resizable: false`.

### Gaps
- Exact returned shape of `do` results for create operations not captured (read-only). Inferred from skill: prints created IDs like `{ "pane": "...", "terminal": "..." }` or `{ "error": "..." }`.
- Whether split ratio is settable at creation time: no arg in `pane.split` schema shown; inferred not directly controllable via split command. Only manual divider drag (screen-local) or layout-node sizing exists.
- Pane order within a tab is returned flat, so "which pane is the second child" is not exposed; cannot assert layout geometry programmatically.

## hc terminals in the app (`herdr.space`/`herdr.tab` protocol), labeling, auto-creation

### Takeaway
App labels terminals it starts with `herdr.space=<id>` and `herdr.tab=<id>`. A terminal with those labels shows up there even if started externally via `hc run --label herdr.space=... --label herdr.tab=...`. Unlabeled workers stay hidden (do not add labels just to run background worker). Without `herdr.tab`, app creates a tab in that space. Labels use machine-local ids; remote ids shown with `<machine>/` prefix — strip prefix when writing labels on that machine. Adoption enables core keep; `terminal.park` removes pane and disables keep. Terminals without labels or from other machines stay out unless started by app for that machine.

### Cited Findings
- Skill: "A terminal started with hc opts into the window with `herdr.space=<id>`. `herdr.tab=<id>` chooses its tab; without it, Herdr creates a tab in that space. Unlabeled workers stay hidden. Do not add labels just to run a background worker. Use app commands when the user wants to see a new tab or split, hc for orchestration that need not change the screen." — [`/tmp/herdr_skill.txt:80-120`](file:///tmp/herdr_skill.txt)
- AGENTS: "Every terminal is a core terminal. Herdr labels the ones it starts with `herdr.space=<id>` and `herdr.tab=<id>`. **A terminal with those labels shows up there**, even one you start yourself: `hc run --keep --label herdr.space=<id> --label herdr.tab=<id> -- claude`. Labels use ids local to that machine; remote ids shown by the app have a `<machine>/` prefix (strip it when writing labels on that machine). Adoption also enables core keep; `terminal.park` removes the pane and disables keep. When a core change is needed, `terminal.keep` / `terminal.park` acknowledge with `pending: true`, then apply after the machine replies; failures show a toast. ... An id Herdr doesn't know becomes a new space or tab (unnamed: Herdr's names). Terminals without the labels (another app's) stay out of Herdr's screens, and so do other machines' terminals, unless Herdr started them for a space on that machine." — [`~/.config/herdr-app/AGENTS.md:144-163`](~/.config/herdr-app/AGENTS.md)
- hc help mentions labels: `label <t> k=v...            set labels` (and `--keep` affects recovery). — [`hc --help`](file:///tmp/h_help.txt)
- Live `hc ls --json` shows terminals with addresses `t22,t24,t25`, agents, cwd, state/status/turn/where; app maps them via labels to spaces/tabs (ls shows them placed). — [`hc ls --json`](live)
- `hc get t22 --json` (live, exit 0) confirms the label keys byte-for-byte: `"labels":{"herdr.space":"spdc6f02dc4372f0de60ea8d526c51b3db","herdr.tab":"tb3d621f87c7cbc7092c57591fabc239f8","where":"fox-and-cub / Claude Code"}`, plus `"keep":true`, `"title":"Fox-and-cub crew handoff"`, `"identity":"ghostty"`, `"state":"live"`, `"status":{"app":"claude-code","msg":"...","state":"working"}`. So a third, informational `where` label exists and is what `hc ls` reports as `where`. — [`hc get t22 --json`](live)

### Inferences
- Claiming into existing tab/pane: set `herdr.space=<existing space id>` and `herdr.tab=<existing tab id>` on the hc terminal (labels). App will place it in that tab/pane context if compatible; adoption enables keep behavior.
- Auto-creation: if space unknown -> new unnamed space; if space known but tab unknown/missing -> new unnamed tab in that space.
- Unlabeled terminals remain hidden from Herdr UI (not adopted).

### Gaps
- Exact behavior when label points to non-existent pane vs tab vs space needs to be verified empirically (read-only constraint; inferred from docs).
- Whether labels can be set after terminal starts to claim it (hc has `label` command) — inferred possible if adoption logic applies on label change, but not explicitly stated as guaranteed.

## Titles and metadata

### Takeaway
Tab names set via `tab.rename(id?, name)` ("": reverts to number/name auto). Space names via `space.rename`. Terminal/pane titles come from programs (`program.title` in PaneInfo/AgentInfo) or mod names for mod panes. No explicit `pane report-metadata` command visible in `commands` or `herdr.d.ts`. External processes (hc/crew) cannot directly set app tab titles via a dedicated app API command except by going through app commands; hc can set labels and run programs but app tab naming is controlled by app commands (`tab.rename`). No obvious mod/API path exposed for arbitrary tab title updates from outside except `run("tab.rename", ...)`.

### Cited Findings
- Commands: `tab.rename(id?, name)` "Rename a tab (asks the person when no name; an empty name: called by its number again)". `space.rename(id?,name)` similar. `terminal.open` takes optional `name`? Args show `terminal.open(?argv, ?folder, ?place, ?name)` in commands list (line ~250-280 in commands). Also `tab.new` takes `name?`. — [`/tmp/herdr_commands.txt`](file:///tmp/herdr_commands.txt)
- PaneInfo: `title` is "The terminal's title (what the program set), or the mod's name". AgentInfo has `title`. — [`~/.config/herdr-app/herdr.d.ts:168-210`](~/.config/herdr-app/herdr.d.ts)
- AGENTS: tabs unnamed called by position ("1","2"...); `tab.rename` names it. — [`~/.config/herdr-app/AGENTS.md:120-140`](~/.config/herdr-app/AGENTS.md)
- Skill: picking explicit useful names when creating spaces/tabs. — [`/tmp/herdr_skill.txt:80-100`](file:///tmp/herdr_skill.txt)

### Inferences
- External process can call `herdr-app do tab.rename --id <tabId> --name "T7 pair: started"` if it has access to app CLI and window is running (agent can run shell commands). This is an app command (mutator) — allowed if user wants automation, but our task says "do not run `herdr-app do` for mutating commands" so we don't test; capability exists per schema.
- No `pane report-metadata` equivalent found. Mods can read `panes()` data but cannot directly rename tabs except by calling `run("tab.rename", ...)` if they have permission (mods can call `run`). So mod path exists via `run`.
- Setting terminal title is up to the program running in terminal (OSC sequences) — app displays it as `title`. Live proof: `hc get t22 --json` returns `"title":"Fox-and-cub crew handoff"`, and the shipped `pane` mod header renders `p.title` when the program is an agent/shell. **This is the cheapest crew-side title channel**: the crew can write an OSC 0/2 title escape into its own terminal (e.g. `printf '\033]0;T7 pair: started\007'` or the program's title API) and the pane header updates with no app command. It does not change the tab pill name.
- `terminal.open` also accepts `name?` per `commands`, but neither the command's `about` text nor `herdr.d.ts`'s `run` doc explains it. Likely the hc terminal's `name` (address alias) rather than a pane title; unverified.

### Gaps
- Whether `tab.rename` can be called without `id` when a tab is focused/selected: `id` is optional in the schema and the skill's examples always pass ids; untested under read-only rules.
- No documented `pane report-metadata`; no way to set a tab's title from inside the terminal (OSC only changes the pane/`title` field).
- Semantics of `terminal.open {name}` unresolved (gap, not a claim).

## Discovery (ls enumeration, stable IDs, finding crew space/tab)

### Takeaway
`herdr-app ls` enumerates spaces/tabs/terminals with stable IDs (space ids like `sp...`, tab ids `tb...`, pane ids `pa/pb/p...`, terminal addresses `t22,t24,t25`). `status` gives current space/tab/focused pane. Can find crew deterministically by matching space name/folder or by tracking IDs from `ls`. `hc ls --json` gives terminal details; combined with `ls` provides full mapping.

### Cited Findings
- `herdr-app ls` output shows full tree with IDs as above. — [`/tmp/herdr_ls.txt`](file:///tmp/herdr_ls.txt)
- `herdr.d.ts`: `spaces()` returns `SpaceInfo[]` with `id,index,name,named,folder,machine,branch,active,status,tabs[]`; `TabInfo` has `id,index,name,named,active,status,panes,zoomed,settled,settled_at,changed_at,working_since`; `panes()` has `pane,terminal,mod,tab,title,cwd,branch,status,app,program,focused,zoomed,movable`. `terminals()` returns core terminal objects. — [`~/.config/herdr-app/herdr.d.ts:81-240`](~/.config/herdr-app/herdr.d.ts)
- `view.json` stores current active space/tab and per-tab focus/settled state. — [`~/.config/herdr-app/view.json`](~/.config/herdr-app/view.json)
- AGENTS notes remote ids have `<machine>/` prefix in display; labels on that machine omit it. — [`~/.config/herdr-app/AGENTS.md:148`](~/.config/herdr-app/AGENTS.md)

### Inferences
- Script can do `herdr-app ls --json` equivalent (it outputs JSON) and find space where `name` contains "herdr-crew" or `folder` matches crew repo; get its tabs/terminals and IDs. Deterministic if names/IDs stable.
- `hc ls --json` gives `where` like "herdr-crew / 2" which matches tab names; useful cross-reference.

### Gaps
- None significant; discovery surface is well-defined.

## Mods

### Takeaway
Mods live in `mods/<name>/` with `main.js` and `mod.json`. Shipped mods are read-only (replaced on start); duplicate with `mod.clone` before editing. Trusted JS with command/network access (no DOM/HTML/webview/Node APIs/setTimeout). API via `herdr` module (`run`, `hc`, `exec`, `readTextFile`, `writeTextFile`, `knownAgents`, `pickFolder`, `playSound`, `home()`, `appHome()`, live data like `spaces()/tabs()/panes()/agents()/terminals()/focused()/layout()/theme()/settings()/keys()/commands()`, overlays, shared state, `nextCommand()`, `watchFolder()`). Lifecycle: `init(props,cx)`, `render(cx)`, optional `async close(cx)` (250ms budget on quit). No retained `cx` across callbacks. Native animations preferred over timers. `herdr-app check <mod>` validates load/render; `status` shows errors; `shot` for visual check. Could build crew board/status UI as mod, but with constraints.

### Cited Findings
- Structure: `mods/<name>/ main.js, mod.json, *.js, *.svg, fonts/` etc. mod.json can have `place` (`left|right|top|bottom|none`), `size`, `title`, `overlay{width,height,kind,at,offset}`, etc. Shipped mods have `place:"none"` mostly (used by layout). — [`~/.config/herdr-app/AGENTS.md:716-767`](~/.config/herdr-app/AGENTS.md), [`mods/*/mod.json`](~/.config/herdr-app/mods/*/mod.json)
- Rules: default export class extending `View`; `init(props,cx)`, `render(cx)`. Never keep `cx`. Use `cx.spawn`, `cx.timer`. No `setTimeout/setInterval`. `on_size_change` on root. `async close(cx)` for cleanup (max 250ms on quit, shared). Animate with `frames()`, `svg().spin()`, `.loop()`, `.transition()` not timers. — [`~/.config/herdr-app/AGENTS.md:767-865`](~/.config/herdr-app/AGENTS.md)
- Docking + command routing: the first time Herdr sees a mod folder it docks one copy per `mod.json` into the shown layout (`"none"`: only where a layout or another mod puts it); after that layouts decide. A copy starts the first time it shows and stays alive while its block is in the layout even when hidden (timers keep running → poll gently). `<mod>.<command>` reaches **shown** copies only, delivered through `nextCommand()`; mods' own commands are not in `herdr-app commands`. — [`~/.config/herdr-app/AGENTS.md:716-760`](~/.config/herdr-app/AGENTS.md)
- `nextCommand()` contract: "Waits for the next key command for this mod ("alt-s": "<mod>:<command>" in keys.json)" with an infinite `for(;;)` loop in `cx.spawn`. So a board can expose its own keys without the app knowing them. — [`~/.config/herdr-app/herdr.d.ts:395-410`](~/.config/herdr-app/herdr.d.ts)
- `herdr.d.ts` exports cover all APIs listed; mods trusted (commands/network unrestricted). `localStorage` per copy, `console.log`, `fetch`, `import * as fs from "fs/promises"`. — [`~/.config/herdr-app/herdr.d.ts`](~/.config/herdr-app/herdr.d.ts), [`~/.config/herdr-app/AGENTS.md:865-945`](~/.config/herdr-app/AGENTS.md)
- Check flow: `herdr-app check <mod>` loads once, renders once, exits nonzero with exact error (doesn't check layout/paint/deferred/nested/async). After change run check, then `status`, then `shot`. — [`/tmp/herdr_skill.txt:170-210`](file:///tmp/herdr_skill.txt), [`~/.config/herdr-app/AGENTS.md:49-61,758-767`](~/.config/herdr-app/AGENTS.md)
- Live evidence: `herdr-app check ~/.config/herdr-app/mods/spaces` → exit 0, stdout `check passed: /Users/gok/.config/herdr-app/mods/spaces`. So `check` is non-mutating and usable as a smoke test on existing mods. — [live run]
- `herdr-app shot /tmp/herdr-audit.png` → exit 0, prints absolute path, 859 KB PNG of the current frame. (Captured as evidence; this audit's model could not view PNG content, so visual claims below rest on layout files and mod sources, not the image.) — [live run]
- Example mod patterns: `mods/pane/main.js` reads `panes().find(p => p.pane === props()?.pane)` and renders `p.title` / program name / status, with buttons calling `run("pane.split"|"pane.zoom"|"pane.close", …)`; `mods/workspace-status/main.js` is a one-row status bar reading `spaces()/agents()/theme()/window()/keys()` and calling `run("app.palette")`. Both show the read-live-data + `run(command)` shape a crew board would use. — [`mods/pane/main.js`](~/.config/herdr-app/mods/pane/main.js), [`mods/workspace-status/main.js`](~/.config/herdr-app/mods/workspace-status/main.js)
- mod.json observed keys across the 22 shipped mods: `place` (21), `title` (9), `overlay.width/height/kind/at/offset` (few). No other fields in this install. — [`jq` over `~/.config/herdr-app/mods/*/mod.json`](~/.config/herdr-app/mods/*/mod.json)
- Examples: shipped mods like `agents`, `spaces`, `tabs`, `pane`, `files`, `changes`, `workspace-status`, `menu`, `toast`, `worktree` provide patterns. — [`mods/`](~/.config/herdr-app/mods/)

### Inferences
- Crew board/status UI is feasible as a mod (can read `spaces()/tabs()/agents()/terminals()/panes()`, call `run()` to control, use `exec/hc` to query core). Constraints: no retained `cx`, cleanup budget, native animations only, check+shot validation required, shipped mods read-only (clone if modifying). No retained cx means state must be stored in instance properties; callbacks get fresh cx.
- Trust model: trusted JS with full access — acceptable for internal tooling if controlled.

### Gaps
- Exact `close()` budget enforcement details and quit behavior nuances need runtime observation (inferred from docs).
- Performance characteristics of full-window redraw on mod changes noted but not benchmarked.

## Layouts

### Takeaway
Layouts are trees in `layouts/<name>.json` (types `row/column/stack/block`). Shipped layouts read-only; clone with `layout.clone`. Layouts control structure/look (theme/fonts/sizes/pane frames), clicks/sizes stored in `layouts/.state/` and survive restarts. Can define complex layouts (e.g. 2x2) via nesting rows/columns. Can bind dynamic content via `content: {tab:"active"}` for tab panes or `{mod:"..."}` or `{terminal:"..."}` or `{agent:"focused"}`. Binding dynamic terminals: panes are created by commands/splits; layout defines how they're arranged/framed. Cannot directly "bind" arbitrary pre-existing terminals except by placing them via commands into that layout structure.

### Cited Findings
- Layout commands: `layout.switch`, `layout.clone(name,as?)` (duplicates and switches), `layout.set` (personal tree edits; shipped only click/look), `layout.reset`, `layout.toggle/show/hide/resize/select`. — [`/tmp/herdr_commands.txt`](file:///tmp/herdr_commands.txt)
- Layout structure: block types as above, properties include `size/min/max/hidden/background/border/radius/shadow/focus/padding/gap/divider/resizable/movable/floating/window_drag`. Root can have `titlebar`, `traffic_lights`, `terminal_menu`, `preview`. Pane config under block content with tab panes. — [`~/.config/herdr-app/AGENTS.md:165-497`](~/.config/herdr-app/AGENTS.md)
- Live: `layouts()` lists names; `layout()` returns shown layout. `shared("layout")` is shown layout name. — [`~/.config/herdr-app/herdr.d.ts:224-235`](~/.config/herdr-app/herdr.d.ts)
- "Add a layout by writing a new file." Layout files are live-reloaded; clicks (`sizes`, shown/hidden, stack child, floating spots, theme picks, background, text size, pane header height/border/focus) live in `layouts/.state/` and survive restarts. A deliberate layout-file edit beats a click on that field. — [`~/.config/herdr-app/AGENTS.md:165-225`](~/.config/herdr-app/AGENTS.md)
- Shipped layouts on this install: `main`, `terminals`, `win98` (`layouts/main.json`, `terminals.json`, `win98.json` + `win98.svg`); `installed.json` tracks `layout:main|terminals|win98` hashes. — [`~/.config/herdr-app/layouts/`](~/.config/herdr-app/layouts), [`~/.config/herdr-app/installed.json`](~/.config/herdr-app/installed.json)
- Example `main.json` shows structure with sidebar and work area. — [`~/.config/herdr-app/layouts/main.json`](~/.config/herdr-app/layouts/main.json)

### Inferences
- Crew layout can be defined/cloned/reused as JSON file. Dynamic terminals appear in panes created by commands; layout arrangement is structural.
- Ratio control: via node sizes/weights/gaps/dividers and `layout.resize(id,px|weight)`; not via `pane.split` args.

### Gaps
- Programmatic creation of arbitrary layout trees via API: `layout.set` accepts layout tree for personal edits (shipped limited to click/look). Creating new layout file directly is possible if written to `layouts/` (app watches files). Feasibility depends on exact schema validation.

## Platform, packaging, headless limits, multi-machine, updates

### Takeaway
macOS app at `/Applications/Herdr.app` (bundle), CLI at `/Users/gok/.local/bin/herdr-app` (v0.1.11). Config in `~/.config/herdr-app` or `$HERDR_APP_HOME`. Multi-machine via `hc machine add/ls/...` and `space.new --machine <name>` / `terminal.open` with machine context; remote spaces live on that machine, labels need prefix stripping on remote. Headless limits: `ls/status/shot` talk to running window; without running window inspect is limited (commands still work). `herdr-app shot` needs running window with drawn frame. No screen capture permissions needed. Updates: `app.check_updates`, `app.update_core` (terminals kept), `app.update` restarts into downloaded update. Linux sandbox script mentioned for app development.

### Cited Findings
- Platform: macOS bundle present; CLI binary at `~/.local/bin/herdr-app`. Version 0.1.11. — [`/Applications/Herdr.app`](file:///Applications/Herdr.app), [`herdr-app --version`](live)
- Multi-machine: `space.new` takes `machine` (from `hc machine ls`), space lives there, terminals start in that machine's home unless folder, tabs/splits stay there. Remote ids shown with `<machine>/` prefix (strip when labeling on that machine). `hc machine ls/add/login/update/rename/rm` available. `exec` takes `on` for remote. — [`/tmp/herdr_skill.txt:100-140`](file:///tmp/herdr_skill.txt), [`~/.config/herdr-app/AGENTS.md:144-163`](~/.config/herdr-app/AGENTS.md), [`hc --help`](file:///tmp/h_help.txt)
- Reliability: `machines()` reports per-machine `layout: "loading" | "ready" | "unavailable"`; "structural commands fail while that machine's layout is unavailable" and newest accepted document wins on simultaneous edits (no merging). So a launcher must check machine readiness before creating tabs on a remote space. — [`~/.config/herdr-app/herdr.d.ts:130-133`](~/.config/herdr-app/herdr.d.ts), [`~/.config/herdr-app/AGENTS.md:92-100`](~/.config/herdr-app/AGENTS.md)
- Headless: "ls and status talk to the running window, not a new app. commands prints the built-in command list even without an open window. Do not launch bare herdr-app to inspect it: that opens or raises the window." Shot needs running window. — [`/tmp/herdr_skill.txt:1-80`](file:///tmp/herdr_skill.txt)
- Multi-window: there is **one app window per home**. `shot`/`status` say "`HERDR_APP_HOME` selects which running window to ask", `window.json` holds a single `{state,bounds,display}`, and `windows.json` is documented as *mods'* floating windows, not app windows. No command creates or selects an app window (`window.*` only minimize/maximize/close). — [`/tmp/herdr_skill.txt:1-80`](file:///tmp/herdr_skill.txt), [`~/.config/herdr-app/window.json`](~/.config/herdr-app/window.json), [`~/.config/herdr-app/AGENTS.md:74-92`](~/.config/herdr-app/AGENTS.md), [`/tmp/herdr_commands.txt`](file:///tmp/herdr_commands.txt)
- Live machines: `hc machine ls` → `{"machines":[]}` (exit 0). No remote machine is configured on this Mac, so every remote claim in this audit is documentation-based, not observed. — [live run]
- Live `herdr-app ls` reports `machine: null` for both spaces, consistent with local-only. — [`/tmp/herdr_ls.txt`](file:///tmp/herdr_ls.txt)
- Updates: `app.check_updates()` looks for newer Herdr/herdr-core now; settings reports Up to date only after successful check. `app.update_core()` updates herdr-core to latest of this generation (terminals keep running). `app.update()` restarts into downloaded update. `updates()` in herdr.d.ts shows app/core versions, ready, managed, checked times. — [`/tmp/herdr_commands.txt`](file:///tmp/herdr_commands.txt), [`~/.config/herdr-app/herdr.d.ts:300-340`](~/.config/herdr-app/herdr.d.ts)
- Linux sandbox: `scripts/sandbox` provides isolated home/core/display for app development on Linux (`up`, `do`, `status`, `shot`, `down`). — [`~/.config/herdr-app/AGENTS.md:945`](~/.config/herdr-app/AGENTS.md)

### Inferences
- Full replacement on macOS is feasible if app is installed; multi-machine supported. Headless automation requires running window for `ls/status/shot/do` to read or change window state; `commands` works offline. A true "headless" crew cannot use the app at all — but terminals are hc's, so a crew can run with the window closed and only `commands` + `hc` available.
- Multi-window = one window per `HERDR_APP_HOME`. Two independent windows require two homes and two cores (inferred; no command selects a window).

### Gaps
- Exact behavior of `--machine` spaces across restarts/network conditions needs runtime testing (inferred; no machine configured here).
- Update channel details not exposed in read-only files; `updates()` exposes version/ready/managed/checked but not channel name.
- Single-window claim is based on docs + one `window.json`; not tested against a second instance.

## What crew launcher needs but app does NOT expose (and workarounds)

### Takeaway
Key gaps: no explicit split ratio control in `pane.split`; no direct API to set arbitrary tab titles from external process without calling `herdr-app do tab.rename` (mutator via CLI) or mod calling `run`; no `pane report-metadata` equivalent; layout tree creation/modification constrained (shipped limited); no built-in crew board/status UI (would need mod). Also need to ensure deterministic discovery across restarts (IDs persist in core docs?).

### Cited Findings
- Split ratio: `pane.split` args only direction/pane/argv/mod/props — no ratio/size. Layout sizing via nodes/resizing. — [`/tmp/herdr_commands.txt`](file:///tmp/herdr_commands.txt), [`~/.config/herdr-app/AGENTS.md:165-360`](~/.config/herdr-app/AGENTS.md)
- Titles: `tab.rename` exists as command but no non-mutator way to set; external process can use `herdr-app do tab.rename` (CLI mutator). Mods can call `run("tab.rename",...)`. No `pane report-metadata` found. Pane titles come from the program (`p.title`). — [`/tmp/herdr_commands.txt`](file:///tmp/herdr_commands.txt), [`~/.config/herdr-app/herdr.d.ts`](~/.config/herdr-app/herdr.d.ts), [`mods/pane/main.js`](~/.config/herdr-app/mods/pane/main.js)
- Agent registry: `knownAgents()` gives agents people can start; no explicit "agent registry" API for crew internals beyond what hc/core provides. — [`~/.config/herdr-app/herdr.d.ts:20-40`](~/.config/herdr-app/herdr.d.ts)
- Layout binding: dynamic terminals appear via commands; no direct "bind existing hc terminal to specific pane in layout" command except via labels/placement and layout `content: { terminal: "t7" }`. — [`~/.config/herdr-app/AGENTS.md:165-230`](~/.config/herdr-app/AGENTS.md)

### Need → capability → workaround

| Crew launcher need | Exposed? | Closest workaround |
|---|---|---|
| Create space/tab/split, name them | Yes: `space.new`, `tab.new`, `tab.rename`, `pane.split` | — |
| Split ratio / resize panes | No on `pane.split`; yes on layout nodes (`layout.resize`, `size.weight/px`) only | Build the arrangement in a personal layout; accept the app's default divider position for model splits, drag manually |
| 2x2 with board under Lead | Partly: only right/down binary splits | `pane.split right` (Lead \| B), `pane.split down` on Lead (A under Lead), `pane.split down` on B; no explicit ordering/ratio readback |
| Verify arrangement after building | No: `ls`/`status` give flat terminals + focused pane, no geometry | Assert only membership (pane/terminal ids present in tab); screenshot with `shot` for a human |
| Set tab pill title from crew (e.g. `T7 pair: started`) | Yes but mutator-only: `do tab.rename --id --name`, or mod `run("tab.rename")` | Call `herdr-app do tab.rename` from the launcher; or have the board mod derive labels and render them itself |
| Set pane title | Indirect: program's OSC title becomes `panes()[i].title`, rendered by `pane` mod | Crew writes `\033]0;T7 pair: started\007` to its own terminal |
| Show hc terminals created by crew | Yes via `herdr.space`/`herdr.tab` labels; unlabeled stays hidden | Label at `hc run --keep --label ...`; unknown id creates unnamed space/tab |
| Deterministic discovery | Yes: `ls` JSON with `sp*`/`tb*`/`p*`/`t*` ids | Match by space name/folder or cache ids; `hc ls --json`'s `where`/labels cross-check |
| Add metadata beyond name/status | No `pane report-metadata` | Labels on hc terminals; mod `shared()` state; files |
| Status/board UI | No built-in; mods are the extension point | Crew board mod reading `spaces()/agents()/panes()/terminals()`, calling `run()`/`hc()` |
| Reuse a crew layout | Yes: `layout.clone`, layout files in `layouts/`, `layout.set` for personal trees | Ship `layouts/crew.json` + cloned mods; switch with `layout.switch` |
| Multi-machine | Yes via `hc machine` + `space.new --machine`; remote ids prefixed `<machine>/` | Strip prefix when labelling on the remote machine |
| Headless operation | No: `ls/status/shot/do` need a running window; `commands` only offline | Run crew entirely in hc; treat app as optional viewer |

### Gaps
- No confirmed way to set tab title without mutator command — capability exists but requires execution path.
- Ratio control not directly exposed — workaround via layout structure is the intended approach.
- Whether `tab.rename` works without id when focused is implied but not explicitly tested (read-only).
- `terminal.open {name}` semantics unexplained by docs.
- Everything remote/multi-machine is documentation-only here: `hc machine ls` returned none.

### Quick reference (for crew launcher)

- **Inspect**: `herdr-app ls`, `herdr-app status`, `herdr-app commands` (read-only; don't run bare `herdr-app`)
- **Control**: `herdr-app do <cmd> [--args|json]` (mutators) — returns IDs or `{error:...}`, exit 1 on error
- **hc label protocol**: `herdr.space=<id>`, `herdr.tab=<id>` on hc terminal; unlabeled hidden; unknown ids create unnamed space/tab
- **Discovery**: use `ls` tree + IDs; cross-ref with `hc ls --json` and `where` field
- **Titles**: `tab.rename` via `do` or mod `run` (no direct non-mutator API found)
- **Mods**: trusted JS in `mods/`, clone shipped, `herdr-app check` + `status` + `shot` after changes
- **Layouts**: clone shipped, structure controls splits/ratios; dynamic terminals placed by commands
- **Multi-machine**: `--machine` on space.new, labels need prefix stripping, `hc machine ls` for list
- **Headless**: `commands` works without window; `ls/status/shot/do` need running window
- **Label check**: `hc get <t> --json` shows `labels{herdr.space,herdr.tab,where}`, `keep`, `title`

### Evidence log (direct exit codes)

| Command | Exit | Output |
|---|---|---|
| `herdr-app --version` | 0 | `herdr-app 0.1.11` |
| `herdr-app --skill` | 0 | 128 lines, agent manual |
| `herdr-app --help` | 0 | usage; lists `ls/do/feedback/commands/status/shot/check` |
| `herdr-app commands` | 0 | 691-line JSON array (name/args/about) |
| `herdr-app ls` | 0 | spaces→tabs→terminals JSON |
| `herdr-app status` | 0 | zoom/fonts/space/tab/focused_pane/layout/agent/floats/overlays/errors |
| `herdr-app shot /tmp/herdr-audit.png` | 0 | path printed, 859 KB PNG |
| `herdr-app check ~/.config/herdr-app/mods/spaces` | 0 | `check passed: …/mods/spaces` |
| `herdr-app do --help` | 1 | `{"error":"unknown command \"--help\": …"}` |
| `herdr-app do no.such.command` | 1 | `{"error":"unknown command \"no.such.command\": …"}` |
| `herdr-app do pane.split` | 1 | `{"error":"pane.split needs direction"}` |
| `herdr-app do pane.split --direction sideways` | 1 | `{"error":"pane.split direction is \"right\" or \"down\", not Some(\"sideways\")"}` |
| `herdr-app do tab.rename '{"bogus":1}'` | 1 | `{"error":"tab.rename: unknown argument(s): bogus; valid arguments: id, name"}` |
| `hc machine ls` | 0 | `{"machines":[]}` |
| `hc ls --json` | 0 | 3 live terminals (`t22`,`t24`,`t25`), `hidden_finished:17` |
| `hc get t22 --json` | 0 | labels incl. `herdr.space`/`herdr.tab`/`where`, `keep:true`, `title` |

Mutating commands were **not** executed: no `space.*`/`tab.*`/`pane.*`/`terminal.*`/`layout.*` writes, no bare `herdr-app`, no edits to mods/settings/layouts.
