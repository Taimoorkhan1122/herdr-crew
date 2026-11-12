# herdr-crew FAQ

Short answers to the questions people ask before installing herdr-crew. For setup steps, see the [quick start](./quickstart.md).

## What is herdr-crew?

herdr-crew is a Claude Code skill that launches a multi-agent development crew inside Herdr. One command starts a Lead agent that talks to you, a Manager agent that starts worker teams, and a shared task board (tsk). Development teams work in separate Git worktrees; the investigation team reads the current repository without a new branch or worktree.

## Is this the same as the other GitHub project called herdr-crew?

No. More than one repository shares the name. This one is a Claude Code skill and Bash launcher that uses `herdr-app`, `herdr-core` (`hc`) and tsk. The most visible alternative is a Rust Herdr plugin configured by `.herdr/crew.toml`. See [herdr-crew vs other Herdr crew tools](./comparison.md) for a side-by-side comparison.

## Do I need Herdr to use it?

Yes. The app owns spaces, tabs and panes, and `hc` owns send, read, wait, status and kill. Install both from <https://herdr.dev/download>. `help`, `--version`, `completion`, `init`, `upgrade` and `configure` work without a running app window, but launching agents does not.

## Does it work on a server, in a container, or in CI?

No. Runtime commands need a desktop session and a running app window. Headless use on a server, container or CI runner is unsupported.

## Which coding agents can run in a crew?

Claude Code is the default. OpenCode 2 is supported for roles assigned to it. Codex, Gemini and other agent kinds need permission and lifecycle adapters before they can be selected; unsupported selections fail explicitly. See [OpenCode 2 support](./opencode-support.md).

## Does herdr-crew push or merge my changes?

No. Merging is always your decision. Crew instructions require approval before a push, merge, or worktree removal. Member sessions also receive explicit Bash denies for `git push` and `git merge`. A completed development task leaves a branch such as `crew/T7-pair` for you to merge.

## What is the task board?

The board is tsk, a small command-line task list installed separately (`brew install smarzban/tap/tsk`). The Lead, Manager and workers share one board. Tasks move through `open -> ready -> started -> review -> done`, and `blocked` when information prevents progress.

## Where does herdr-crew store state?

Worktrees live at `~/.herdr/worktrees/<slug>/T<n>-<team>`. Handoffs live at `~/.herdr/crew/<slug>/handoff-<agent>.md`. Project configuration lives in `.herdr-crew/config.json` in the primary checkout. The `<slug>` is six characters of the repository folder name plus four hex characters from a hash of the repository path.

## Does every agent run its own session?

Yes. Each role is a separate agent session. A separate investigator, for example, costs another agent session and coordination on top of the crew.

## Can I start one team without a Lead?

Yes. For a small job, run a job spec directly, such as `/herdr-crew driver "Fix the login redirect loop"` or `herdr-crew team pair T<n>`. See [Using herdr-crew](./usage.md#start-one-team-directly).

## Can I add my own agents and personas?

Yes. After `herdr-crew init`, add a directory under `.herdr-crew/agents/` with an `AGENTS.md` and an `agent.json`. Metadata must choose one of the four existing profiles (`lead`, `manager`, `member`, `inspector`); it cannot add tools or change the native permission mode. Domain personas can be added to any job. See [Configuring herdr-crew](./configuration.md#add-a-project-agent).

## What happens when an agent runs out of context?

Claude agents have a 135000-token warning budget, set with `CREW_CTX_LIMIT`. A saved context hook warns once per session; the agent then writes a handoff and stops, and the Manager restarts it with the saved brief. OpenCode agents must monitor context themselves and hand off before compaction. See [Context budget and handoffs](./usage.md#context-budget-and-handoffs).

## Does it work on Windows?

Herdr's supported desktops include Windows x64. The herdr-crew launcher also needs Bash and a `readlink` command that supports `-f`.

## How do I ask questions about an existing codebase?

Send questions to the Lead. Quick lookups go to a read-only Explore sub-agent; deeper questions start the `investigate` team, which reads the current repository and answers with `file:line` evidence and any verification gaps. See [Ask questions about the project](./usage.md#ask-questions-about-the-project).

## Is it production-ready?

It is experimental. Automated launcher checks pass, but full live development acceptance is pending. See [known limitations](./troubleshooting.md) and [verification status](./STATE.md) before relying on it.
