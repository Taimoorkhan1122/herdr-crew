# Ecosystem and distribution: migrating herdr-crew from `herdr` to `herdr-core` (`hc`) + `herdr-app`

Research date: 2026-11-02. Read-only inspection of the local machine plus public vendor sources.
Local versions at time of research: `herdr 0.9.5`, `hc 0.1.16`, `herdr-app 0.1.11`, `tsk 0.11.6`.

Evidence labels used below:
- **Vendor-confirmed** — stated by herdrdev in a README, changelog, in-product guide, or CLI help.
- **Local-artifact** — read from this machine's installed files or command output.
- **Inferred** — my reasoning from cited facts, not a vendor statement.

---

## 1. What are `herdr`, `herdr-core`, and `herdr-app` to the vendor? Is old `herdr` deprecated, frozen, or maintained?

### Takeaway

The vendor now presents **Herdr (desktop app) + herdr-core (`hc`)** as the primary product, and keeps the old TUI multiplexer as a separate, still-shipping product called "Herdr TUI". No vendor statement declares old `herdr` deprecated, frozen, or end-of-life. The only explicit relationship statement is in `hc --skill`: `hc` "is not `herdr`, the older terminal multiplexer."

### Cited Findings

- GitHub org `herdrdev` describes itself as "open agent runtime" and hosts five repositories: `herdr` ("the runtime your coding agents live on", 47,425 stars, pushed 2026-11-01), `herdr-app` ("herdr desktop app", 1,481 stars, pushed 2026-11-02), `herdr-core` ("herdr-core: terminals for coding agents", 288 stars, pushed 2026-11-01), `herdr-layout-examples`, and `herdr-nix` — [GitHub herdrdev org](https://github.com/herdrdev).
- `herdr-app` was created 2026-10-16, i.e. roughly two weeks before this research; `herdr` has existed long enough to reach 47k stars and 1,958,074 installs — [herdr-app repo API](https://api.github.com/repos/herdrdev/herdr-app); [Herdr TUI site](https://herdr.dev/tui/).
- The vendor homepage is app-first: "Herdr is a native app for Claude Code, Codex and any other coding agent," with top-level navigation App · Core · Layouts · Mods · Guide · Blog and a separate "Herdr TUI ↗" link — [herdr.dev](https://herdr.dev).
- The TUI has its own sub-site at `/tui/` with its own install line, its own plugin gallery (1,997 community plugins), and its own docs tree. It reports version v0.9.5 and calls itself "the agent runtime" — [herdr.dev/tui](https://herdr.dev/tui/).
- The app README defines the split: "The window arranges terminals. The core runs them. Closing the window leaves them running" — [herdr-app README](https://github.com/herdrdev/herdr-app).
- The generated in-app agent guide repeats it as "Two programs": `herdr-app` is the window (spaces, tabs, layouts, panels); `herdr-core (hc)` "runs every terminal and agent. They keep running when the window closes or updates. … The Herdr app is one client of it." — local artifact `~/.config/herdr-app/AGENTS.md` lines 17–25, vendor-generated on every app start.
- `hc --skill` opens with: "The current manual for herdr-core's CLI, `hc`. It is not `herdr`, the older terminal multiplexer." — local artifact `hc --skill` output (vendor text shipped in the binary).
- `herdr-core` README: "`hc` runs programs and coding agents in terminals that stay alive after you leave. … Core draws nothing. Use it from your shell, an agent, or your own app." — [herdr-core README](https://github.com/herdrdev/herdr-core).
- Old `herdr` is still shipping updates: local release notes cache shows `0.9.5` as a hotfix for `0.9.4`, fixing prefix shortcuts, Codex hooks, Windows plugin panes, and Windows session tracking — local artifact `~/.config/herdr/release-notes.json`; repo pushed 2026-11-01 — [GitHub herdrdev org](https://github.com/herdrdev).
- The old `herdr` README still advertises plugins, the plugin marketplace, SSH machines, and 22 detected agents, and says nothing about the app or core — [herdr README](https://github.com/herdrdev/herdr).
- The vendor blog's newest post is 2026-09-08 ("Herdr raised a $6M seed"), all predating the app repository (created 2026-10-16). No post announces an app/core migration, deprecation, or roadmap — [herdr.dev/blog](https://herdr.dev/blog/).
- The vendor explicitly frames the app as open and buildable: "The app, herdr-core and Herdr TUI are open source under Apache 2.0. You can read the code, change it, or build your own app on top of herdr-core." — [herdr.dev](https://herdr.dev).

### Inferences

- The vendor's direction is visible in product surface, not in a policy statement: new investment (app repo, homepage rewrite, `/core/` page, `releases.herdr.dev` distribution) goes to app+core, while `herdr` continues as a maintained but separate TUI line.
- Because `herdr` has 47k stars, ~2M installs, and a 1,997-plugin ecosystem, the vendor has a strong incentive not to deprecate it abruptly. A herdr-crew migration is therefore a product choice, not a forced one, unless herdr-crew needs app-specific capabilities.
- The two stacks share no code path at the CLI level: `hc` has no workspace/tab/pane/agent objects, so this is a replacement of herdr-crew's control plane, not an upgrade of a dependency.

### Gaps

- No vendor statement on the support horizon of `herdr`, no EOL date, no "maintenance mode" wording, and no roadmap item recommending the app/core path. Searched: herdr.dev home, `/tui/`, `/download/`, `/guide/`, blog index, org page, both READMEs, local changelog.
- No vendor page explains how the two products will relate long term (shared features, migration of plugins, shared config formats).

---

## 2. Release and update mechanics, channels, version compatibility between app and core

### Takeaway

App and core are **separate binaries with separate updaters**, but the app drives core updates and keeps core on the "same generation". They are **not versioned in lockstep**: this machine runs app `0.1.11` with core `0.1.16`. Only old `herdr` documents a stable/preview channel; `hc` exposes version-pinned updates, and the app has no documented channel selector.

### Cited Findings

- App self-update: "an installed app downloads them by itself and offers Restart and What changed. If the app crashes or is killed with a verified newer update waiting, the next launch installs it before opening a window. The first start after an app update also updates herdr-core to the latest release of the **same generation**, keeping terminals running." — local artifact `~/.config/herdr-app/AGENTS.md` (Updates section); identical claim in the public changelog: "**herdr-core updates with Herdr.** After Herdr updates, its core moves to the latest version too. Your terminals keep running." — [herdr-app CHANGELOG 0.1.6](https://github.com/herdrdev/herdr-app/blob/master/CHANGELOG.md).
- App command surface includes `app.check_updates` ("Look for a newer Herdr and herdr-core now"), `app.update_core` ("Update herdr-core to its latest release of this generation; terminals keep running"), and `app.update` ("Restart into the update Herdr downloaded") — local artifact `herdr-app commands` output.
- Update integrity: checks SHA-256 against the release manifest, but "The app does not verify a separate cryptographic signature on update manifests." — [herdr-app docs/security.md](https://github.com/herdrdev/herdr-app/blob/master/docs/security.md).
- Core update CLI: `hc update [--version X|--from <file>]` — "latest release, at least X, or a build"; "`hc update` also restarts an older running core when the installed binary is already current … terminals keep running. Managed installs must be updated with their package manager instead" — local artifact `hc --help` / `hc --skill`.
- Old `herdr` has an explicit channel system: `herdr channel show` and `herdr channel set <stable|preview>`; direct installs default to stable and update with `herdr update`; package-manager installs update through the package manager — local artifact `herdr --help`; [Herdr agent guide](https://herdr.dev/agent-guide.md).
- `hc` has no `channel` subcommand in its help; the only update controls are version/from-file pinning and `hc update` — local artifact `hc --help`.
- The app repository publishes **no GitHub releases** (API returned an empty release list); distribution is through `releases.herdr.dev` — [herdr-app releases API](https://api.github.com/repos/herdrdev/herdr-app/releases).
- Installer behaviour: "They also install herdr-core if it is missing. The app can help install or update a core it cannot use." — [herdr-app README](https://github.com/herdrdev/herdr-app).
- Local versions confirm non-lockstep versioning: `herdr-app 0.1.11`, `hc 0.1.16`, and `hc server status` reports `version: 0.1.16`, `installed_by: null` (not app-managed on this machine) — local artifacts `herdr-app --version`, `hc --version`, `hc server status` (all exit 0).
- App changelog shows a very fast cadence: 0.1.4 → 0.1.11 between 2026-10-23 and 2026-10-31, i.e. eight releases in nine days — [herdr-app CHANGELOG](https://github.com/herdrdev/herdr-app/blob/master/CHANGELOG.md); local artifact `~/.config/herdr-app/update-notes-cache.md`.

### Inferences

- "Same generation" is the only compatibility contract published. Reading it as "0.1.x pairs with 0.1.x" is an inference; the exact minimum core build the app accepts is not documented.
- Because `hc` is independently installable and updatable, a user can accidentally run a core newer than the app supports. The app's stated remedy ("help install or update a core it cannot use") implies it detects mismatches but the detection rule is unpublished.
- For a maintainer targeting "app required", pinning is weak: the app updates itself and the core in the background. herdr-crew cannot assume a fixed core version across users.

### Gaps

- No published app↔core compatibility matrix, minimum core version, or schema-version guarantee.
- No app preview/beta channel documented (only old `herdr` has `stable|preview`).
- Not verified: what the app does when core is a *newer* generation, or when core is installed by Homebrew/mise/Nix (app's updater defers to package managers per `hc --skill`, but the app-side behaviour is unstated).

---

## 3. Platform support, headless/SSH use, and what "app required" means for non-macOS users

### Takeaway

The app is a **desktop GUI**: macOS Apple Silicon only, Linux x86-64/ARM64 with a desktop session and Vulkan, Windows x64. The core is a headless binary on all three platforms. "App required" therefore means **no supported headless Linux server path through the app** — servers run `hc` only and are reached from an app on another machine, or through `hc` CLI/SSH.

### Cited Findings

- App platforms: "Linux and macOS … Linux needs a desktop session and a working Vulkan driver. macOS builds are available for Apple Silicon; Intel Mac users can build from source. Linux builds are x86-64 and ARM64." Windows: "x64 Windows with curl and tar installed (Windows 10 1803 or newer)" — [herdr-app README](https://github.com/herdrdev/herdr-app).
- App install layout: macOS app at `~/Applications/Herdr.app`, command symlinked into `~/.local/bin`; Windows adds `%LOCALAPPDATA%\Programs\herdr-app` to user PATH — [herdr-app README](https://github.com/herdrdev/herdr-app); local artifact `herdr-app --help` ("Home: ~/.config/herdr-app").
- Intel Macs are explicitly second class: "macOS releases require Apple Silicon; Intel Macs must build from source." — local artifact `~/.config/herdr-app/AGENTS.md`; [herdr-app README](https://github.com/herdrdev/herdr-app).
- Core platforms: "Builds are available for Linux and macOS on x86_64 and aarch64, and Windows on x86_64. Linux builds are static. On Windows, templates and quoted shell commands need `sh` on PATH, such as Git for Windows provides." — [herdr-core README](https://github.com/herdrdev/herdr-core).
- Headless use is a core feature: "Core draws nothing. Use it from your shell, an agent, or your own app"; `hc connect` carries the API over stdin/stdout "including through SSH"; `hc schema` prints OpenRPC for building your own client — [herdr-core README](https://github.com/herdrdev/herdr-core); local artifact `hc --help`.
- Remote machines: `hc machine add`, `hc run --on <machine>`, `hc exec --on <machine>`, `hc file read|write|edit --on <machine>`; the app adds SSH machines from Settings → Machines or the sidebar's Add machine — [herdr-core README](https://github.com/herdrdev/herdr-core); [herdr-app README](https://github.com/herdrdev/herdr-app).
- Windows headless caveat: "On Windows, `hc server status` never starts a core. If elevated SSH startup would block the same user's desktop session, open Herdr on that Windows machine or run `hc server start` in a normal desktop terminal, then reconnect. Headless Windows machines can still start their core over SSH." — local artifact `hc --skill`.
- Vendor framing of core-only use: "Only want the runtime, for servers or your own client? Get herdr-core on its own" — [herdr.dev/download](https://herdr.dev/download/).
- Old `herdr` supports Windows too, including an "endpoint-protected Windows" install path — [herdr README](https://github.com/herdrdev/herdr); [herdr.dev/tui](https://herdr.dev/tui/).

### Inferences

- For non-macOS users, "app required" is still satisfiable: Linux desktop and Windows x64 both ship app builds. The real break is **headless**: a Linux CI box, container, or remote server cannot run the app, so any herdr-crew workflow that today runs entirely in a terminal on such a host must degrade to `hc`-only.
- SSH-first users keep parity only if herdr-crew drives `hc` over `hc connect`/`hc machine`, not the app socket. The app socket is local-only per app home (`~/.config/herdr-app/herdr-app.sock`), per local artifact.
- Apple Silicon is effectively the reference platform: every app screenshot, media asset, and signing note in the vendor docs is macOS-first; Linux is supported but documented more thinly (one Vulkan sentence).

### Gaps

- No stated minimum macOS version, no Linux distro matrix, no Wayland-vs-X11 support statement beyond changelog fixes ("On Linux, Chinese typed through fcitx or ibus on X11 comes out right").
- No statement on running the app under a remote desktop / VNC / X forwarding, which is the usual workaround for "GUI on a server".
- Not tested (read-only constraint): whether the app launches without a display server in any degraded mode.

---

## 4. Installation and onboarding impact for herdr-crew

### Takeaway

herdr-crew currently requires old `herdr` **as an API surface**, not just a terminal. `bin/crew` calls workspace, tab, pane, and agent endpoints that `hc` does not have at all. Onboarding steps `tsk setup herdr` and `herdr server reload-config` stop applying. A full replacement needs `hc` for process control plus app commands/mods for layout, and a rewrite of the launcher's coordination layer.

### Cited Findings

- Current stated requirements: "**Herdr**, with the `herdr` command on your PATH"; `tsk` plus `tsk setup claude`, `tsk setup herdr`, `herdr server reload-config`; **jq**, **git**, **rg**, **shasum**; **npm** only for the AXI tools; Bash with `readlink -f` — local artifact `/Users/gok/git/herdr-crew/README.md` lines 42–52.
- The launcher's herdr dependency is structural, not cosmetic. It calls `herdr agent get|start|prompt|wait|send-keys|read|list|rename`, `herdr workspace list|create`, `herdr tab create|list|close`, `herdr pane split|run|read|process-info|report-metadata`, and `herdr status server`, and reads `HERDR_PANE_ID` / `HERDR_WORKSPACE_ID` — local artifact `/Users/gok/git/herdr-crew/bin/crew` (lines ~108–629).
- `hc` provides **none** of those object types. Its full command set is: `run`, `ls`, `get`, `attach`, `read`, `kill`, `rm`, `label`, `keep`, `send`, `keys`, `interrupt`, `wait`, `put`, `exec`, `file`, `templates`, `events`, `server`, `update`, `machine`, `connect`, `schema` — local artifact `hc --help` (exit 0). There is no workspace, tab, pane, agent-rename, plugin, or config-reload command.
- `hc` does have partial equivalents: `hc label <t> k=v` (where herdr-crew uses pane metadata/titles), `hc run --bg --name <name>` (named terminals), `hc wait`, `hc send`, `hc read`, `hc interrupt` — local artifact `hc --help`, `hc --skill`.
- Spaces/tabs/panes live in the app, not the core: "Spaces, tabs and splits are stored in each machine's core document, not in the app home" but are driven by the app's own command socket (`herdr-app ls`, `herdr-app do`, app commands) and by mods — [herdr-app docs/security.md](https://github.com/herdrdev/herdr-app/blob/master/docs/security.md); local artifacts `herdr-app --help`, `herdr-app commands`.
- Core config path changes: `~/.config/herdr-core/config.toml` (Windows `%APPDATA%\herdr-core\config.toml`, or `$XDG_CONFIG_HOME/herdr-core/config.toml` when set); missing on this machine, meaning defaults — local artifact `hc --skill`; `ls ~/.config/herdr-core` exited 1 (no such directory).
- `hc` writes notes into parent-agent input by default and tags child reports `<hc from="t7 review">…</hc>`; `notes = false` in core config stops "notes to parent agents" and `<hc>` tags — local artifact `hc --help`, `hc --skill`. This is new prompt-surface behaviour for crew agents that old herdr does not have.
- Old `herdr` config is a different file and format (`~/.config/herdr/config.toml`, TOML with `[keys]`, `[[keys.command]]`, `[theme]`) that the app does not read; the app has its own `settings.json`, `keys.json`, `layouts/` — local artifacts `~/.config/herdr/config.toml`, `~/.config/herdr-app/settings.json`.
- App-side worktree/space creation exists only as a mod capability (`space.new` used by the bundled `worktree` mod) — local artifact `~/.config/herdr-app/mods/worktree/main.js`.

### Inferences

- Minimum onboarding changes for a full replacement:
  1. Replace "Herdr with the `herdr` command on PATH" with two requirements: `hc` (core) and, if a GUI is required, `herdr-app` installed on a supported desktop (Apple Silicon macOS, Linux with Vulkan, Windows x64).
  2. Keep jq/git/rg/shasum/npm: none are herdr-specific.
  3. Drop `tsk setup herdr` and `herdr server reload-config` (see §5). Add nothing equivalent, because `hc` has no config-reload and no plugin registration.
  4. Teach the macOS/Linux/Windows app install lines (`releases.herdr.dev/app/install.{sh,ps1}`) plus the `.dmg` for drag-and-drop.
- The launcher's control plane must be rewritten: workspace creation → app `space.new` (via app command socket or a mod) or dropped in favour of one core session per repo; pane split/run → `hc run --bg` plus app tab/space commands; pane titles → `hc label` plus app tab labels; agent status → OSC 7501 status from `hc get` instead of `herdr agent get`.
- Because `hc` terminals are children of the starting terminal and die with it unless `--outlive-parent`, the crew's process lifetime model changes. Old herdr panes persist independently in the server; hc children have parent-scoped lifetime.
- Onboarding cost rises for headless users: an app-required product cannot be installed on a remote Linux box, so docs must offer an `hc`-only path or declare the app mandatory and exclude that deployment.
- The absence of `hc` config reload is a real regression for onboarding: any config change (shell, notes) applies to next launch only.

### Gaps

- No vendor guidance for packagers or CI: whether `hc` is expected to be present in a devcontainer/CI image, and whether the app can be omitted when only `hc` is needed.
- Not verified locally (read-only): whether `tsk`'s TUI and herdr-crew's board pane behave correctly inside an `hc` terminal under `hc attach` (key handling, alternate screen, resize).
- Not verified: whether the app exposes a scriptable "create space at path" command usable from `bin/crew` without a mod; `herdr-app commands` was not fully enumerated for space creation.

---

## 5. tsk compatibility: old herdr only, or hc/app?

### Takeaway

tsk integrates with **old `herdr` only**, through herdr's plugin system and `herdr` workspace/agent CLI calls. The board TUI itself is terminal-agnostic and runs "in any terminal", so it works inside an `hc` terminal, but `tsk setup herdr`, `prefix+t`, quick capture, and dispatch lose their integrations on the new stack.

### Cited Findings

- `tsk setup` targets: `herdr | agents | claude | pi | omp | cursor | grok | codex | opencode | --skill-dir <path>`. There is no `hc`, `herdr-core`, or `herdr-app` target — local artifact `tsk setup --help` (tsk 0.11.6).
- What `tsk setup herdr` registers: a herdr plugin (`herdr-tsk`) with a `board` pane that runs `tsk`, plus actions `open-board` and `quick-capture`; manifest requires `min_herdr_version: 0.9.0`; platforms linux/macos/windows, actions linux/macos — local artifact `~/.config/herdr/plugins.json` and `~/.config/herdr/tsk-plugins/1b22da49dfc020a2/herdr-plugin.toml`.
- It also writes keybindings into old herdr's config: `prefix+t` → `herdr-tsk.open-board`, `prefix+a` → `herdr-tsk.quick-capture` — local artifact `~/.config/herdr/config.toml`.
- `tsk setup herdr --check` prints "bound when both plugin commands are already in the Herdr config, otherwise unbound" — local artifact `tsk setup --help`.
- Upstream README: "In Herdr, `prefix+t` opens or focuses your workspace's board, even across tabs. … **Without Herdr, run `tsk` in any terminal.**" — [tsk README](https://github.com/smarzban/tsk).
- Upstream dispatch depends on old herdr: "Starting an assigned task dispatches it: tsk creates a Git worktree and a Herdr workspace for the task and launches the agent there. … Dispatch runs in Herdr; on Windows it is a preview." — [tsk README](https://github.com/smarzban/tsk).
- tsk's agent docs instruct `herdr agent get t12-<assignee>` to watch a dispatch, and `herdr` workspace cleanup on done — [tsk agent docs](https://gettsk.sh/docs/agents.md).
- Latest upstream release is `v0.13.0` (2026-10-22); this machine runs `0.11.6` (2026-09-22), which predates assignees/dispatch entirely — [tsk releases](https://api.github.com/repos/smarzban/tsk/releases); local artifact `tsk --version`. Local `tsk --help` has no `dispatch` or `clean` command.
- No mention of `hc`, `herdr-core`, or `herdr-app` appears in the tsk CLI help, README, agent docs, or the 0.11.5/0.11.6/0.12.0/0.13.0 release notes examined — sources above.
- `hc` has no plugin system at all, so a `herdr-tsk`-style plugin cannot be registered against the core — local artifact `hc --help`.

### Inferences

- Migration consequences for herdr-crew:
  - Keep `tsk` as the board. Run it in an `hc` terminal (`hc run --bg --name board tsk`) or let the app show it in a pane; the TUI needs only a TTY.
  - Drop `tsk setup herdr` and `herdr server reload-config` from onboarding. There is nothing to bind, because core has no plugin actions and no keymap.
  - Lose `prefix+t`, `prefix+a`, and tsk dispatch-on-start. herdr-crew's own launcher does dispatch itself (`herdr-crew launch`), so the practical loss is smaller than for a plain tsk user, but any doc that says "press prefix+t" is wrong.
  - herdr-crew's `h`/board pane currently does `herdr pane run "$board" "tsk"`; the equivalent becomes `hc run --bg tsk` plus an app tab, or a plain pane in the app.
- Upstream tsk shows no sign of adding hc support as of 0.13.0, so herdr-crew should not block on it.

### Gaps

- I did not search tsk's GitHub issues for a planned herdr-core/app integration, so "no roadmap" is unconfirmed (only "no shipped support" is confirmed).
- Not verified: whether tsk's `config.toml` agent profiles (`prompt_append`, `review_on`) assume herdr-specific env vars such as `HERDR_PANE_ID`; local tsk 0.11.6 has no such profiles.
- Not verified live: keyboard behaviour of the tsk TUI inside `hc attach` (alternate-screen, mouse, `ctrl+s`).

---

## 6. AXI tooling: does gh-axi / chrome-devtools-axi / lavish-axi / quota-axi depend on herdr?

### Takeaway

No evidence of any herdr dependency. All four are independent npm-distributed CLIs (`npm:<pkg>`) that wrap unrelated surfaces — GitHub, Chrome DevTools, a local HTML review server, and provider auth/quota files. None reference herdr, the app socket, or `hc` in this repo's manifest.

### Cited Findings

- herdr-crew's dependency manifest lists them as standalone tools: `gh-axi axi npm:gh-axi`, `chrome-devtools-axi axi npm:chrome-devtools-axi`, `lavish-axi axi npm:lavish-axi`, `quota-axi axi npm:quota-axi`, installed globally with npm — local artifact `/Users/gok/git/herdr-crew/skills.sources`.
- Their ambient descriptions show unrelated roles: `gh-axi` is "an Agent ergonomic wrapper around Github CLI" with repo/issue/PR context; `lavish-axi` is "Agent ergonomic interface for turning rich HTML artifacts into collaborative human review surfaces"; `chrome-devtools-axi` is "Agent ergonomic interface for controlling Chrome browser session" — harness ambient context for this session (binaries in `/opt/homebrew/bin`).
- `lavish-axi` operates its own local express server on `127.0.0.1:4387` and keeps session state per HTML file; nothing in its help references herdr — ambient context / `lavish-axi` help.
- `quota-axi` reads local provider auth sources for quota windows and states "no routing, no credential minting" — skill description in this session's skill catalog.
- `bin/crew` has no reference to any AXI tool; greps for herdr usage in the launcher show only `herdr` socket calls — local artifact `bin/crew`.
- `npm` is required only "if you want `install-skills` to install the AXI tools" — local artifact `/Users/gok/git/herdr-crew/README.md` line 51.

### Inferences

- AXI tooling survives the migration unchanged. The only coupling is environmental: AXI tools are installed by `install-skills` via npm, which is orthogonal to herdr.
- Agents inside `hc` terminals keep `gh-axi`/`lavish-axi` working; `lavish-axi` opens a browser on the local machine, which is unaffected by the terminal runtime.
- `chrome-devtools-axi` and `quota-axi` are the only ones with any plausible herdr adjacency (browser automation for app UI, provider quota for agent usage), and neither references it.

### Gaps

- I did not read each tool's published package source to prove zero herdr references; the conclusion rests on their documented scope, packaging, and this repo's manifest.
- No first-party AXI integration with `herdr-app` mods or `hc` was found in either direction (AXI tools do not ship herdr mods; the app ships no AXI mod).

---

## 7. Existing examples of agent crews on hc + app: templates, mods, orchestration patterns

### Takeaway

Vendor documentation describes the **pattern** (parent agent delegates with `hc run --bg`, children report with `hc send`, parent waits with `hc wait --children`) and ships **generic** templates/mods, but there is **no first-party or community example of a multi-rank agent crew** like herdr-crew. Installed templates are empty; all 21 installed mods are vendor-shipped UI, not orchestration.

### Cited Findings

- `hc templates` on this machine returns `{"templates":[]}` (exit 0) — local artifact. Templates are Markdown files in `~/.config/herdr-core/templates/<name>.md` with frontmatter `name`, `description`, `command`; the body supplies instructions — local artifact `hc --skill`.
- The vendor's canonical delegation example is a single reviewer: `hc run --bg --name review --cwd /path/to/repo reviewer "Review only src/x.rs…"`; plus the plain-agent variant with `hc run --bg --name fix … claude "…"` — local artifact `hc --skill`.
- Reporting contract: children send `<hc from="t7 review">…</hc>` to the parent; parent waits with `hc wait --children all|any`; `hc wait` default timeout 180 s and returns `reason: message|timeout` — local artifact `hc --skill`.
- Parent/child lifetime: "Agents started inside an hc terminal become its children. … Children end with their parent unless started with `--outlive-parent`." — [herdr-core README](https://github.com/herdrdev/herdr-core).
- The app's own orchestration surface is **mods**: JavaScript using `gpui-kit`, describing native GPUI elements, with access to spaces/tabs/terminals/agents, dialogs, state, and `fetch` — local artifact `~/.config/herdr-app/AGENTS.md`; [herdr-app README](https://github.com/herdrdev/herdr-app).
- Installed mods (21, all vendor-shipped per `installed.json` hashes): `agents, changes, confirm, files, help, machine-add, menu, new-menu, pane, peek, picker, prompt, spaces, tabs, terminals-bar, terminals-pane, toast, win98, workspace-chrome, workspace-status, worktree` — local artifacts `~/.config/herdr-app/mods/`, `installed.json`.
- The bundled `worktree` mod uses `space.new` / `space.close` / `space.select`, i.e. app-level worktree-to-space mapping — local artifact `~/.config/herdr-app/mods/worktree/main.js` and `mod.json` (`{"place":"none"}`).
- There is an org-owned examples repo: "Example Herdr layouts. Not official: take them apart." (Apache-2.0, 8 stars, updated 2026-11-01) — [herdr-layout-examples](https://github.com/herdrdev/herdr-layout-examples).
- Community galleries exist for layouts and mods (`/layouts/`, `/mods/`), and the guide teaches "ask your agent" prompts such as "Make me a layout where my agents are cards in columns" and "Start a reviewer on this branch" — [herdr.dev/guide](https://herdr.dev/guide/).
- Teams/multi-rank vocabulary does not appear in vendor docs: the app models spaces → tabs → panes → agents, and hc models terminals with labels and parent/child relations — local artifacts `~/.config/herdr-app/AGENTS.md` (§ "The model: spaces, tabs, terminals"), `hc --skill`.

### Inferences

- herdr-crew would be an early adopter, not a follower: no existing crew template to copy. Its concepts (lead/manager/member/inspector ranks, per-rank permissions, worktree-per-task) must be re-expressed as hc templates + labels + app layouts.
- The natural mapping: one **space per repo**, one **tab per task**, one **pane per agent**, agents as **hc terminals with `--name` and labels**; rank metadata moves into `hc label` values and template frontmatter.
- Supervision in the new stack is weaker without a rewrite: old herdr gives `agent wait --until blocked|done` and `agent get` status; hc gives `hc wait` plus OSC 7501 status, but naming, rename, and pane-metadata reporting have no core equivalent.
- Because mods are trusted, unsandboxed JS and the app has no permission prompts, a crew dashboard mod is feasible but expands the trust boundary herdr-crew's README already discusses for OpenCode plugins.

### Gaps

- No first-party crew/orchestrator example, no `agents` team template, and no published herdr-crew-like project on hc+app was found in the sources searched.
- `hc templates` empty locally means no vendor templates ship in this install; whether `herdr-core` ships starter templates upstream (docs/templates.md) was not verified.
- Did not search Discord, X, or GitHub code search for community crews; such examples may exist outside indexed docs.

---

## 8. Public migration guidance and breaking changes from old `herdr` to app/core

### Takeaway

**No public migration guide exists.** The only vendor migration artifact is an in-app welcome added in app `0.1.6` (2026-10-29) that offers one agent prompt to carry keybinds and settings across. No deprecation notice, no breaking-changes document, no upgrade path doc, and no compatibility statement between old `herdr` config and app config was found.

### Cited Findings

- Sole vendor migration statement: "**Coming from herdr?** The welcome says what carries over and gives you one line for your agent to bring your keybinds and settings across. Open it again with Show the welcome again in the command palette." — [herdr-app CHANGELOG 0.1.6](https://github.com/herdrdev/herdr-app/blob/master/CHANGELOG.md); local artifact `~/.config/herdr-app/update-notes-cache.md`.
- It is prompt-based, not an importer: the user is given "one line for your agent", and the agent does the translation. No automatic config conversion is claimed.
- App and old TUI have entirely different config surfaces: old `~/.config/herdr/config.toml` (`[keys]`, `[[keys.command]]`, `[theme]`, `[ui.*]`) versus app `~/.config/herdr-app/settings.json`, `keys.json`, `layouts/*.json`, `mods/*` — local artifacts of both directories.
- The app globally states the split, without a migration path: "`herdr-app` controls this app; `hc` controls herdr-core" — local artifact `~/.config/herdr-app/AGENTS.md`.
- The vendor site links old docs only under `/tui/docs/` and new docs only inside the app guide; neither links to a migration page — [herdr.dev](https://herdr.dev), [herdr.dev/tui/docs](https://herdr.dev/tui/docs/), [herdr.dev/guide](https://herdr.dev/guide/).
- Blog index has no migration post; newest post 2026-09-08 predates the app repo — [herdr.dev/blog](https://herdr.dev/blog/).
- No "breaking changes", "upgrade", "migrate", or "deprecated" statement appears in the app CHANGELOG, core README, or app README — [herdr-app CHANGELOG](https://github.com/herdrdev/herdr-app/blob/master/CHANGELOG.md), [herdr-core README](https://github.com/herdrdev/herdr-core), [herdr-app README](https://github.com/herdrdev/herdr-app).
- Evidence searched and found nothing: herdr.dev home, `/tui/`, `/tui/` docs root, `/download/`, `/guide/`, blog index, GitHub org page, `herdr` README, `herdr-core` README, `herdr-app` README, app CHANGELOG, local app `AGENTS.md`, local release-notes files.

### Inferences

- herdr-crew's migration notes must be first-party. There is no upstream document to defer to, and no compatibility guarantee to cite.
- The prompt-based welcome implies the vendor expects users to translate settings via an agent, not to preserve configs mechanically. Maintainers should assume nothing carries over automatically: keybinds, themes, plugin configs, workspace layouts, and tsk bindings all need explicit re-creation.
- Because no deprecation exists, herdr-crew can run both stacks in parallel during migration and document "app+core" as the new default without claiming the old path is dead.

### Gaps

- No public herdr→app/core breaking-changes list, so any parity claims must be derived from observed API differences (documented in §4), not cited.
- The welcome's exact "one line" prompt text was not retrieved (it exists only in the app UI; `~/.config/herdr-app/AGENTS.md` does not include it, and invoking the app is out of scope for this read-only task).
- Whether the welcome handles old `herdr` **plugins** (e.g. `herdr-tsk`) is unknown; it is described only as "keybinds and settings".
