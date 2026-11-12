# herdr-crew vs other Herdr crew tools

More than one GitHub repository is named **herdr-crew**. The two most visible are different projects with different architectures. If you arrived here from a search result, this page tells you which one you are looking at.

This comparison describes each project's public README on 2026-11-12. Check the linked repository for the current state.

## Side by side

| | **This project** — [Taimoorkhan1122/herdr-crew](https://github.com/Taimoorkhan1122/herdr-crew) | **rarce/herdr-crew** — [github.com/rarce/herdr-crew](https://github.com/rarce/herdr-crew) |
|---|---|---|
| What it is | Claude Code skill and Bash launcher | Rust plugin for Herdr |
| Install | Symlink `bin/crew` and the repository into `~/.local/bin` and `~/.claude/skills` | `herdr plugin install rarce/herdr-crew` |
| Configuration | `.herdr-crew/` project agents, `config.json`, `teams/`, `personas/` | `.herdr/crew.toml` |
| Agent kinds | Claude Code (default), OpenCode 2, Command Code | Claude, Codex, pi |
| Task tracking | tsk shared task board | `.herdr/status.json` status board |
| Team model | Lead, Manager, job agents and stackable domain personas | Roles, presets and a board writer |
| Isolation | Git worktree per team | Git worktree per role |
| Runtime dependency | `herdr-app` and `herdr-core` (`hc`), tsk, jq, git, rg, shasum, Bash | herdr 0.9.1+, Rust and Cargo, git, selected agents |
| Main commands | `launch`, `team`, `say`, `read`, `wait`, `mark`, `status`, `close`, `watch`, `handoff`, `restart`, `init`, `upgrade`, `configure` | `init`, `up`, `add`, `close`, `send`, `board`, `check`, `startup`, `codex-*`, `pi-*` |
| Distribution | Manual symlinks | Herdr plugin marketplace and public launcher |
| Status | Experimental; automated checks pass, live development acceptance pending | Released; latest tag `v0.4.2` |

## How to tell which one you have

- A project containing `.herdr/crew.toml` is **rarce/herdr-crew**.
- A project containing `.herdr-crew/config.json`, or `.herdr-crew/agents/` and `teams/`, is **this project**.
- `herdr plugin list` showing `herdr-crew` means **rarce/herdr-crew** is installed as a plugin.
- `herdr-crew help` listing `launch`, `team` and `say` is **this project**. Listing `up`, `add`, `send` and `board` is **rarce/herdr-crew**.

Both projects install a command named `herdr-crew`, so a PATH symlink can point at either one. Check the command list before reporting a problem.

## Which should you use?

- Choose **this project** if you work mainly in Claude Code, want a Lead/Manager hierarchy with rank and persona permissions, and want a shared tsk board that agents update as they work.
- Choose **rarce/herdr-crew** if you want a Herdr plugin distributed through the marketplace, a TOML-defined role list, and first-class Codex or pi sessions.

Neither project is a drop-in replacement for the other: configuration files, commands and task storage differ.

## Related reading

- [Herdr](https://herdr.dev/) — the desktop app both projects run inside.
- [tsk](https://github.com/smarzban/tsk) — the task board this project uses.
- [This project's quick start](./quickstart.md) and [FAQ](./faq.md).
