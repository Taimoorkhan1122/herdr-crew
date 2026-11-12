# Configuring herdr-crew

This page covers project setup, per-project agent definitions, runtime assignments, and upgrades. For installation, see the [quick start](./quickstart.md). For the bundled profiles, personas and teams, see the [reference](./reference.md).

## Set up project agents

The first `launch` or `team` in a project creates `.herdr-crew/` from the installed baseline before starting agents. To set it up explicitly without launching a crew, run `herdr-crew init`. Initialization adds missing files and keeps files already present. It creates `config.json` and `baseline.json` alongside copied `agents/`, `personas/`, `teams/`, and `hooks/` content.

Existing valid `.herdr-crew.json` assignments are imported into `config.json` during first initialization; the old file is retained unchanged. If both formats already exist, `.herdr-crew/config.json` is used and the legacy file is reported.

To review bundled changes later, run `herdr-crew upgrade`. Preview output lists each changed path with the installed-source and current-project SHA-256 values. Apply only a path selected from that preview, supplying both hashes exactly:

```bash
herdr-crew upgrade --apply agents/driver/AGENTS.md \
  --expect <source-sha256> --expect-target <project-sha256-or-absent>
```

Both values are required so the source and project file must still match the preview. `upgrade --json` returns these maps in `sourceHashes` and `targetHashes`; add one `--apply ... --expect ... --expect-target ...` group for each selected path. Customized or unselected files are left alone. `--dry-run init` reports the plan without writing. Initialization and upgrade do not install dependencies or start agents.

Edit a project's `.herdr-crew/agents/<id>/AGENTS.md` and `agent.json` to customize a named agent. Metadata chooses one of the four existing profiles (`lead`, `manager`, `member`, `inspector`); job guidance cannot expand the profile's native tools or permission mode. Project edits apply to new launches. A running session and its restart retain the saved definition; use a new launch to adopt edits. Updating the installed baseline does not change existing projects until selected paths are applied with `upgrade`.

## Configure runtime assignments

Run the setup in your project directory:

```bash
herdr-crew configure
```

It lists installed supported CLIs and asks for a role and agent. For OpenCode and Command Code it reads the project's available model catalog: choose a number, enter a full model ID, or type a search term. For OpenCode you then choose one of that model's effort variants, and models without variants skip the effort question. Blank or `0` keeps the runtime default. Command Code model IDs carry no `#variant`, so effort is a separate value there. Claude keeps its model/effort prompts. Choose `all` to set the four rank defaults, then add individual job overrides. Existing job overrides remain in place. The wizard saves once at the end; EOF cancels its pending changes. For scripts or direct changes:

```bash
herdr-crew configure all claude
herdr-crew configure driver opencode --model provider/model --effort high
herdr-crew configure tester command-code --model claude-sonnet-5-5 --effort high
herdr-crew configure code-reviewer claude --model inherit --effort high
herdr-crew configure --show
```

Replace `provider/model` with a model available in your authenticated OpenCode installation, and `claude-sonnet-5-5` with an ID that `cmd --list-models` prints. Supported agents are `claude`, `opencode` (version 2) and `command-code`. The configuration token is exactly `command-code`; the executable is `cmd`, and the product is also written command-code or commandcode, but those spellings belong in your shell and your prompt, not in `config.json`. Other agent kinds, including Codex and Gemini, need permission/lifecycle adapters before they can be selected. Unsupported selections fail explicitly.

Runtime assignments live in `.herdr-crew/config.json` in the primary project checkout. Each project's linked worker worktrees read that same file, including uncommitted configuration edits. For a manually entered linked checkout with separate Git metadata that does not identify its primary working directory, set `CREW_REPO` to the primary project directory; crew-created workers already receive it. Ambiguous checkout discovery fails rather than writing into Git metadata. You can commit it to share assignments, or keep it local. It contains agent/model settings, never credentials:

```json
{
  "version": 1,
  "roles": {
    "member": { "agent": "claude", "model": "haiku" },
    "driver": { "agent": "opencode", "model": "provider/model" },
    "tester": { "agent": "command-code", "model": "claude-sonnet-5-5", "effort": "high" }
  }
}
```

Valid keys are `lead`, `manager`, `member`, `inspector`, and the job personas below. Job settings override their rank; project settings override the bundled defaults. Changing agent clears inherited model/effort values from the previous runtime. With the same agent, omitted model/effort retains the inherited setting; changing an OpenCode model clears its inherited variant because variants belong to that model; `inherit` explicitly uses that agent's own default. For OpenCode, `--effort` selects a catalog variant of the explicit `--model`; supported names vary by model, so an unsupported choice fails without saving. Keep the variant in `effort`, rather than embedding `#variant` in the model field. The adapter writes the native `#variant` only on the crew agent selection, because OpenCode's root model default drops variants. The wizard and explicit OpenCode efforts query `opencode api --standalone model.list` in the primary checkout; this uses a private metadata server, creates no agent session and submits no model prompt. Catalog errors cancel setup without writing pending changes. Deleting a role entry restores inheritance. Without a config file, the existing Claude defaults apply. There are no user-wide overrides.

For Command Code, `--model` is the exact ID that `cmd --list-models` prints. Command Code IDs may be `provider/model` or plain, such as `claude-sonnet-5-5`, and they have no `#variant` form: keep any effort in `effort` and never append it to the model string. The adapter checks the ID against that catalog and caches the response for one day at `~/.herdr/crew/command-code-models`. If the catalog cannot be read, it prints a warning and falls back to checking the ID's syntax, so an offline machine can still save an assignment that the runtime later rejects.

Selection changes apply to new launches. Restart keeps the saved agent/model/effort in the same terminal; it does not migrate a running session to another agent. Configure and `--show` need no app window or tsk. Launch preflight checks the selected executables, the OpenCode major version, and the Command Code minimum version (1.88.5) before creating tasks, worktrees or panes.

OpenCode receives a per-pane native role policy and runs with `--standalone`. Read-only ranks retain their command allowlists; members have edit/shell access and explicit Git push/merge denies. Subagents are disabled to prevent a broader helper policy bypassing the rank. Member access outside the working directory may ask for approval. Managed runtime configuration and trusted plugins remain part of the runtime's trust boundary.

Command Code receives a per-session TypeScript mod. The launcher writes the mod to a file and starts `cmd` with `-n`, `--model`, `--effort`, `--permission-mode`, `--skip-onboarding`, `--no-auto-update` and `--mod`; the bundled jiti compiles that file inside the session. The mod appends the crew rank and runtime policy to the system prompt and hooks `beforeToolCall`, `onPermissionRequest`, `afterToolCall` and `onSessionStart`. Inspectors run with `--permission-mode plan`; the lead, manager and member run with `yolo`, and the mod's deny rules still win there. Native `write_file` and `edit_file` are blocked for the manager and inspector, member `git push`/`git merge`/`gh pr merge` commands are blocked, and `onSessionStart` removes the `agent` and `agent_output` tools. See [Command Code support](./command-code-support.md).

Claude keeps its hooks, Skill/Explore and Monitor workflow. OpenCode uses portable skills and bounded shell waits; automatic crew context warnings and asynchronous Monitor wakeups are unavailable. Command Code has no Monitor wakeup and no transcript hook either; its warning is best-effort and depends on the runtime reporting a token count. Each reports its limits and hands off before compaction. Claude plugin skills are not automatically portable. The current `install-skills` installer still targets Claude; install portable skills for OpenCode and Command Code through their normal skill installation paths. The generated brief identifies the verified crew installation path. Runtime policy enforcement and full cross-agent orchestration still need live acceptance; automated fixtures are not that evidence.

## Add a project agent

After `herdr-crew init`, add a directory under `.herdr-crew/agents/` with `AGENTS.md` instructions and `agent.json` metadata:

```json
{
  "name": "payments-reviewer",
  "description": "Reviews payment code and reports risks.",
  "profile": "inspector"
}
```

Use an existing profile (`lead`, `manager`, `member`, or `inspector`). Project job metadata accepts only `name`, `description`, `profile`, and optional string-array `skills`/`axi` plus string `effort`; it cannot add tools or change native policy. Write the instructions in `AGENTS.md`. Listed skills must be installed; AXI tools need an `<tool> axi npm:<pkg>` source in `skills.sources` to be installable.

A project team can reference a custom job ID. Fake-runtime fixtures cover its launch and native configuration; live enforcement remains unverified.

## Add a team

Create a `.conf` file in `teams/`. The file name is the team name:

```
# worktree: new | from-pair | pair-branch | none
members=member@tester inspector@navigator
worktree=new
```

- `members` lists `<rank>@<job>` entries. The first gets the tab's first pane, and the rest are split off it.
- `worktree` is one of `new` (branch from HEAD), `from-pair` (branch from `crew/T#-pair` when it exists), `pair-branch` (detached checkout of `crew/T#-pair`, fails if missing), or `none` (current repo, used by the Lead layout and investigation).
- The Manager's rules name the teams, so add the new team there too. `SKILL.md` lists them as well.

## Change a bundled default model or effort

Prefer `herdr-crew configure` for project-specific changes. Editing bundled files changes the installation defaults for projects without overrides.

- Edit profile `model` or `effort` in `agents/crew-<profile>/agent.json` to change bundled defaults. `inherit` passes no `--model` flag, so Claude Code's default applies.
- Edit a bundled job's `effort` in `agents/<job>/agent.json` to change that job's default.

## Run a rank on OpenCode

Use `herdr-crew configure <rank-or-job> opencode --model provider/model`. OpenCode 2 is required. Existing OpenCode sessions without saved native-policy metadata must be relaunched rather than restarted. See [OpenCode 2 support](./opencode-support.md) for the runtime and permission details.

## Run a rank on Command Code

Use `herdr-crew configure <rank-or-job> command-code --model <exact model id> [--effort <level>]`. Command Code 1.88.5 or later is required, and the model ID must come from `cmd --list-models`. There is no `#variant`, so effort stays in its own field. Restart reuses the saved argv and mod file, so a change to the adapter's policy reaches new launches only. See [Command Code support](./command-code-support.md).
