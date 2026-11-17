---
name: herdr-crew
description: Launch an agent crew in Herdr for development or project questions. Usage - /herdr-crew <spec> <instructions>. Spec - lead (starts the crew), or <rank>[@<persona>[+<persona>]] with ranks member or inspector, or a bare job persona including investigator or planner.
allowed-tools: Bash(herdr-crew *)
---

herdr-crew launches a multi-agent development crew in the Herdr desktop app: a Lead that talks to you, a Manager that starts worker teams, and a shared tsk task board. Teams work in isolated Git worktrees; investigations read the repository without one. If a launch fails, run `herdr-crew doctor` and relay its fixes. Runtime adapter detail lives in the linked pages at the end.

Run the launcher. Pass the instructions on stdin so quoting never breaks:

```bash
herdr-crew launch <spec> - <<'EOF'
<instructions from the user, verbatim>
EOF
```

Spec forms:
- `lead`: starts the crew (lead + manager + board) in a new app tab. Re-running it sends the new instructions to the running lead.
- `<rank>@<job>`, e.g. `member@driver`, `inspector@navigator`.
- `<job>` alone is shorthand: `driver` = `member@driver`, profile taken from its metadata.
- Add domain personas with `+`: `member@driver+nestjs-expert`, `inspector@code-reviewer+security-paranoid`.

Profiles: `lead` talks to the user, owns the board, asks before any merge. `manager` spawns teams, watches workers, never edits code. `member` is read-write in its own worktree, commits on its branch, never pushes. `inspector` is read-only: investigates, reviews, navigates, triages, tests. Bundled job personas (driver, tester, planner, navigator, code-reviewer, investigator, qa-bug-*) and domain personas (pragmatic-senior, nestjs-expert, react-expert, ui-expert, security-paranoid) are listed in the [reference](docs/reference.md).

Teams, chosen from the job: `pair` (driver, navigator), `review` (code-reviewer; needs an existing pair task), `test` (tester), `bug-validate`, `investigate` (read-only), `plan` (documentation only). Worktree rules and details are in the [reference](docs/reference.md).

Invalid input (unknown profile or agent, or a job assigned to an incompatible profile) fails before anything starts.

Then relay the command output to the user in one or two lines (tab label, agents started, or the error).

If a launch fails, run `herdr-crew doctor` (add `--json` for a machine-readable report) and relay its fixes to the user in one or two lines.

Further reading:

- Day-to-day use, visual planning and project questions: [usage](docs/usage.md)
- Project setup, agent customization and runtime assignments: [configuration](docs/configuration.md)
- Profiles, personas, teams, commands, output conventions: [reference](docs/reference.md)
- Per-runtime behavior: [Claude Code](docs/claude-support.md), [OpenCode 2](docs/opencode-support.md), [Command Code](docs/command-code-support.md)
- Known limits and failure modes: [troubleshooting](docs/troubleshooting.md)
