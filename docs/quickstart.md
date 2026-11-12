# Quick start: install herdr-crew and start your first crew

herdr-crew is a Claude Code skill that launches a multi-agent development crew inside Herdr. One command opens a Lead that talks to you, a Manager that starts worker teams, and a shared tsk task board. Development teams work in isolated Git worktrees; the investigation team reads the current repository without a new branch.

This page takes you from nothing to a running crew. For the command list, see the [reference](./reference.md). For runtime-specific behavior, see [Claude Code support](./claude-support.md) and [OpenCode 2 support](./opencode-support.md).

## Before you start

You need:

- **herdr-app** and **herdr-core** (`hc`) on your PATH. Install both from <https://herdr.dev/download>; the app installer also installs `herdr-core` when it is missing. Supported desktops are Apple Silicon macOS, Linux x86-64 or ARM64 with Vulkan, and Windows x64.
- **A desktop session.** `launch`, `team`, `say`, `mark`, `status`, `watch`, `close` and `restart` need a running app window that answers `herdr-app status`. A server, container or CI runner without a desktop session cannot run them.
- **A CLI for every role you assign**: **Claude Code** (the default), **OpenCode 2**, or **Command Code** (`cmd`, version 1.88.5 or later). Mixed-agent teams need each selected CLI on PATH. Authenticate each CLI separately before launching a crew; the launcher does not check credentials or model access.
- **tsk**, the task board: `brew install smarzban/tap/tsk`, then run `tsk setup claude` once to register tsk with Claude Code.
- **jq**, **git**, **rg** (ripgrep), and **shasum**.
- **npm**, only if you want `install-skills` to install the AXI tools.
- Bash and a `readlink` command supporting `-f`.

The full dependency list is in [Requirements](../README.md#requirements).

## 1. Install the runtime

Download the Herdr desktop app from <https://herdr.dev/download>, and install `herdr-core` if the app installer did not. Confirm both commands:

```bash
hc --version
herdr-app --version
```

The app and core update independently, and no compatibility matrix is published. If a runtime command fails, report both versions with the error.

## 2. Install herdr-crew

Clone or download this repository, then run the following from its root. Keep the checkout in a permanent location: these links point to it.

```bash
project_dir="$(pwd -P)"
mkdir -p "$HOME/.local/bin" "$HOME/.claude/skills"
ln -s "$project_dir/bin/crew" "$HOME/.local/bin/herdr-crew"
ln -s "$project_dir" "$HOME/.claude/skills/herdr-crew"
```

If a link already exists, inspect it before replacing it; the commands above do not overwrite existing files. Make sure `~/.local/bin` is on your PATH. The launcher loads definitions from the installed package and supplies them to each Claude session; no global rank-agent links are needed.

## 3. Install the persona skills

Check first:

```bash
~/.claude/skills/herdr-crew/bin/install-skills --check
```

`--check` changes nothing. It prints `ok` or `MISSING` for each skill and exits with status 1 if anything is missing. To install what is missing, run the script with no flags:

```bash
~/.claude/skills/herdr-crew/bin/install-skills
```

For each missing item it shows the command and asks `[y/N]`. Nothing installs unless you answer `y`. Add `-y` to accept every prompt, but only if you trust the sources in `skills.sources`.

**Manual prerequisite:** the Manager requires the `caveman:caveman` plugin skill. Install that plugin separately before launching a crew. `install-skills --check` does not currently detect this requirement, so a passing check alone does not mean all required skills are installed. Several domain skills also need manual installation because their sources are listed as `UNKNOWN`; see [Troubleshooting](./troubleshooting.md#skills-with-unknown-sources).

## 4. Start a crew

Open a terminal in the Herdr desktop app, change into your repository, and invoke the herdr-crew skill from your configured agent (or run `herdr-crew launch lead "<instructions>"` in the shell). For the default Claude installation, type:

```
/herdr-crew lead "Add a CSV export button to the reports page"
```

Then this happens:

1. The launcher finds your repository with `git`, then selects the space from `CREW_WS`, the caller app terminal's `herdr.space` label, or the `crew-<slug>` fallback outside an app terminal.
2. It opens a tab named `crew <slug>` with the Lead, the Manager, and the board. The tab opens in the background, so switch to it yourself.
3. The Lead reads your request, may ask you a question in its pane, creates tasks on the board, and marks them `ready`.
4. The Lead sends the task numbers to the Manager, which opens a tab for each task.
5. The command prints a line or two, such as the tab name. The rest happens in the crew tab.

Watch progress in three places: the board pane, the team tab titles (such as `T7 pair · <agent>: started`), and `herdr-crew status`.

## What a normal session looks like

1. In your repository, run `/herdr-crew lead "Add a CSV export button to the reports page"`.
2. Switch to the `crew <slug>` tab. The Lead proposes tasks and may ask you a question.
3. The Manager opens a tab per task, such as `T1 pair`. The driver writes a failing test first, then the code, and commits to `crew/T1-pair`. The navigator reviews as the work goes.
4. When the driver marks the task `review`, the Manager runs the `review` team. If the reviewer asks for changes, the driver fixes them and the review runs again, up to three rounds. No action is needed from you.
5. To run tests, ask the Lead. The Manager runs the `test` team on the same task.
6. When the Lead reports the task `done`, read the branch, run the tests yourself, and merge when satisfied. The Manager closes the team tabs. Run the printed removal command when you no longer need the worktree.

## Next steps

- [Using herdr-crew](./usage.md): teams, personas, status, handoffs and merges.
- [Configuration](./configuration.md): project agents, runtime assignments and upgrades.
- [Reference](./reference.md): profiles, personas, teams, commands and environment variables.
- [Troubleshooting](./troubleshooting.md): known limits and failure modes.
