# herdr-crew docs

These files record how herdr-crew got built, why it is built the way it is, and what state it is in now. Read them in this order when you come back to the project after a break.

- `STATE.md`: the current state. What works, what is only tested with dry runs, what is open, and what to do next. Start here.
- `features.md`: the current feature, option, flow, and hook reference, checked against the executable scripts and rank/persona instructions.
- `PROGRESS.md`: a dated log of each change session, newest first.
- `adr/`: architecture decision records (ADRs). Each file records one decision, its context, and its consequences.
  - `adr/0000-template.md` is the template for new ADRs.

The top-level `README.md` explains how to use the crew. These docs explain how and why it works.

`superpowers/plans/2026-10-14-project-qa.md` records the approved Q&A plan and execution limits. `research/test-concurrency.md` is a proposal, not a built feature. ADR bodies preserve historical decisions and can describe earlier behavior; use the README, feature reference, current scripts, and STATE for current behavior and acceptance.

## How to maintain these docs

- After each change session, add a dated line to the top of `PROGRESS.md`. Put the newest session first.
- When the status of anything changes, update `STATE.md`. Move items between "What works", "Only dry-run tested", and "Open issues" as needed.
- For each decision, add a new numbered ADR. Copy `adr/0000-template.md`, use the next free number, and use a short slug in the file name, such as `0013-some-decision.md`.
- Never edit an accepted ADR. If a decision changes, write a new ADR that supersedes the old one. Then set the old ADR's status to `Superseded by NNNN`. That status line is the only edit allowed on an old ADR.
- Keep the docs in plain English with full sentences.
