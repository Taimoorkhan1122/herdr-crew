# 0013. AXI tools are declared per persona and rank

- Status: Accepted
- Date: 2026-10-13

## Context

Agents waste tokens when they call raw command-line tools such as `gh` and `quota`. Their output is long and inconsistent. AXI (https://axi.md) is a set of command-line tools built for agents. Their output is short and consistent, and they show the next step in a `help[]` list. Crew agents need a clear way to use them, and the user must keep control of what gets installed on the machine.

## Decision

A persona or rank file may declare an `axi:` key in its frontmatter, with a comma-separated list of AXI tool names. `brief` lists the declared tools in each agent's brief, with a line that asks the agent to prefer them over raw CLIs. If a declared tool is not on PATH, the launcher prints a warning and still launches the agent. `bin/install-skills` checks each AXI tool. For a missing tool it shows the `npm i -g <pkg>` command from its `<tool> axi npm:<pkg>` line in `skills.sources`, and it asks before it runs the command. The default answer is No.

The inspector rank gets only read-only AXI patterns in its tool list: `gh-axi` read commands and `chrome-devtools-axi` snapshot, screenshot, console and network commands. The inspector rank has no `axi:` line, so its brief does not list them. `tasks-axi` is not used, because tsk is the task board (ADR 0003).

## Consequences

- Agents get the AXI tools they need in their brief, and the cost of raw CLI output goes down.
- A missing AXI tool does not stop a launch. The warning appears in the launcher output.
- The installer changes the machine only after the user answers yes, the same rule as ADR 0010.
- The lead's tool list allows `Bash(gh-axi *)`, which technically includes `pr merge`. The rule in the lead's persona that it asks before any merge (ADR 0011) is the only guard against that.
- The inspector's read-only rule depends on the tool patterns in its rank file. Nothing else enforces it.
- The installer's missing-tool branch, which runs `npm i -g`, is not yet exercised by any test or live run (STATE.md).
