---
name: herdr-crew
description: Launch an agent crew in Herdr for development or project questions. Usage - /herdr-crew <spec> <instructions>. Spec - lead (starts the crew), or <rank>[@<persona>[+<persona>]] with ranks member or inspector, or a bare job persona including investigator or planner.
allowed-tools: Bash(herdr-crew *)
---

When asked to configure the project's agents, run `herdr-crew configure --show` first, then use `herdr-crew configure <rank-or-job> <claude|opencode> [--model MODEL] [--effort EFFORT]` with the user's requested assignments. `all` sets rank defaults while preserving job overrides. The human wizard is `herdr-crew configure`; agents use arguments instead of an interactive prompt. Settings are in the main project's `.herdr-crew.json`, shared across its worktrees. Unsupported agents fail explicitly. OpenCode requires version 2 and has no separate effort or model-variant setting. Existing sessions retain saved selections on restart.

Run the launcher. Pass the instructions on stdin so quoting never breaks:

```bash
herdr-crew launch <spec> - <<'EOF'
<instructions from the user, verbatim>
EOF
```

Spec forms:
- `lead`: starts the crew (lead + manager + board) in a new Herdr tab. Re-running it sends the new instructions to the running lead.
- `<rank>@<job>`, e.g. `member@driver`, `inspector@navigator`.
- `<job>` alone is shorthand: `driver` = `member@driver`, rank taken from the persona.
- Add domain personas with `+`: `member@driver+nestjs-expert`, `inspector@code-reviewer+security-paranoid`.

Ranks (permissions, `ranks/`):
- `lead`: talks to the user, owns the tsk board, asks before any merge.
- `manager`: started by lead. Spawns teams, watches workers. Never edits code.
- `member`: read-write in its own worktree, commits on its branch, never pushes.
- `inspector`: read-only. Investigates, reviews, navigates, triages, tests.

Job personas (`personas/`, have `rank:`): driver, tester, qa-bug-reproducer, planner (member); navigator, code-reviewer, qa-bug-triager, investigator (inspector). A job sets the team slot and its skills.

Domain personas (`personas/`, no `rank:`, stackable on any job): pragmatic-senior (default when none given), nestjs-expert, react-expert, ui-expert, security-paranoid.

For clean UI design and development, use the `ui-expert` domain. It combines Impeccable with React engineering, preserves existing design systems, and requires desktop/mobile browser verification. The manager selects it for UI tasks and keeps it on each review round:

```bash
herdr-crew team pair T7 --persona driver=ui-expert --persona navigator=ui-expert
herdr-crew team review T7 --persona code-reviewer=ui-expert
```

To create a new task directly, launch `member@driver+ui-expert` with the user's instructions on stdin. That attaches the domain to the driver; use the explicit pair command above when both pair members need it.

Teams (`teams/`), chosen from the job:
- pair: driver, navigator. Own worktree.
- bug-validate: qa-bug-triager, qa-bug-reproducer. Own worktree.
- review: code-reviewer. Detached checkout of `crew/T#-pair`, so run pair first. A review spec on a new task is refused before anything starts.
- test: tester. New branch `crew/T#-test` from `crew/T#-pair` if it exists, else HEAD.
- investigate: investigator. Reads the current repo without a new branch or worktree. Saves answers in tsk.
- plan: planner. Own worktree and planning branch. Writes Markdown/Mermaid plus an uncommitted local review page; product files stay unchanged.

For requested visual planning, Lead sends `Run T<n> (plan)` through Manager. Read the installed `docs/planning/visual-plan-contract.md` and template. Manager's `plan ready:`/done result completes drafting only. Lead presents the page or Markdown, records explicit user approval against commit/hash and scope in tsk, then dispatches implementation. Test/simulation feedback is not authorization. Revisions reopen the same planning task and retain version/approval history; material revisions need new approval. A standalone planner stays at review for manual acceptance. Lead/Manager remain without file-writing tools.

The manager runs pair -> review -> fix rounds (max 3) -> done on its own for authorized development; the user merges.

For project questions, send one question or a numbered batch to the Lead. Quick lookups use a read-only Explore helper with `model: haiku` (expected resolution: Haiku 5.5, `claude-haiku-5-5`) and `effort: medium`. Deeper questions go through the Manager to `investigate`. Answers include source citations, inspected source version, and verification gaps. The Manager checks answer coverage and marks done without the development review loop.

Follow-ups to active investigations become numbered task steps. After completion, fresh exploration uses a linked new task and refreshed evidence. Investigation does not authorize a fix. A direct `herdr-crew launch investigator -` saves answers at `review`; without a running Manager, the user reads them with `tsk list T<n> --json` and accepts them manually.

Examples:
- `herdr-crew launch lead -` starts the crew.
- `herdr-crew launch driver -` creates a task and runs the pair team.
- `herdr-crew launch member@driver+nestjs-expert -` same, with the NestJS persona on the driver.
- `herdr-crew launch investigator -` creates a read-only project investigation task.
- `herdr-crew launch planner -` creates a documentation-only visual planning task; it does not authorize implementation.

The manager can add domain personas to a team slot: `herdr-crew team pair T2 --persona navigator=security-paranoid`.

Invalid input (unknown rank, unknown persona, job persona with the wrong rank) fails before anything starts.

Then relay the command output to the user in one or two lines (tab label, agents started, or the error).

Other commands: `herdr-crew status`, `herdr-crew close <T#> [<team>]` (closes the tab only, prints the worktree removal command, never removes it), `herdr-crew watch` (the lead runs it in Monitor: one line per board change), `herdr-crew handoff "<status>" < body` (an agent saves its handoff when it nears the context budget), `herdr-crew restart <agent|T#>` (starts an agent again from its handoff).

Context budget: Claude agents get a hook at 135000 tokens. OpenCode has no automatic crew context warning or asynchronous Monitor tool; its runtime brief specifies direct lookups, portable skills and bounded waits with explicit monitoring limits. Subagents are disabled under its native rank policy. Agents write a handoff before compaction; their initiator restarts them.

If the output says "not inside Herdr", tell the user to start Herdr and rerun there.

AXI tools: personas and ranks can declare `axi:` (AXI CLIs, e.g. gh-axi). The brief lists them; the launcher warns if one is not on PATH.

Install: missing persona skills, plugins and AXI tools are reported by `~/.claude/skills/herdr-crew/bin/install-skills [--check] [-y]`; it asks before each install. Sources are in `skills.sources`.
