# Project Q&A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for inline execution, or superpowers:subagent-driven-development if the user selects delegation. Steps use checkbox syntax for tracking.

**Goal:** Answer individual or batched project questions with source evidence, using the Lead for conversation and an investigator when deeper exploration is needed.

**Architecture:** Keep the Lead's existing Explore path for quick lookups, using a read-only sub-agent with model haiku-5.5 and medium effort. Add an `investigator` job under the existing inspector rank and an `investigate` team with `worktree=none`. Give research tasks their own completion path so they do not enter the build/review pipeline.

**Tech Stack:** Existing Bash launcher, Markdown rank/persona instructions, team configuration files, tsk, and Herdr. No new dependencies.

**Spec:** The proposed behavior below is the spec for this small change. These are planning recommendations, pending user review.

## Proposed behavior

The user asks the Lead questions in ordinary language. Examples: “Does X exist?”, “How does login reach the database?”, and a numbered list of unrelated questions. No special syntax is required.

The Lead delegates a local fact that needs little tracing to a read-only Explore sub-agent using model haiku-5.5 and medium effort. The helper reads source and reports evidence; it does not edit files. Verify that the runtime accepts the exact model and effort settings. If either setting is unsupported, report the limitation instead of silently substituting a model or effort. It sends cross-module flows, conflicting evidence, substantial batches, or explicit requests for deeper investigation to the Manager as an investigation task. Batch size alone does not force delegation. Questions about runtime behavior can be answered with an explicit verification gap.

The investigator traces relevant entry points, callers, services, configuration, persistence, and tests as needed. It explains current behavior and records evidence. It does not modify code, fix discovered bugs, create branches, install tools, or run commands that may write project files. Existing rank permissions are broader than this job's intended behavior; the persona narrows their use through instructions, not an OS sandbox.

For each question, report:

1. The question number and original question.
2. A direct answer, including whether a feature is present, partial, absent within the searched scope, or uncertain.
3. A short explanation of the flow or relevant behavior.
4. Source references with `file:line`, and the repository path and branch/commit when available.
5. What was checked, what remains unknown, and whether the conclusion comes from source inspection or observed runtime evidence.

Number unnumbered batch questions in their original order. Shared exploration is allowed, but each question gets its own answer. “Absent” needs a stated search scope and checked integration points; one failed text search is insufficient. Documentation, tests, and code can disagree; identify the disagreement and avoid treating a test or comment as proof of deployed behavior.

The investigator writes one single-line `[answer Q<n>]` tsk step per question using `tsk steps <T#> add`, preserving the task body. Separate fields with semicolons; tsk rejects newlines. It marks `review` with `answers ready: <count>`. The Manager checks coverage and supporting evidence, asks for missing information through `herdr-crew say`, then marks `done` with `answered: <count> questions`. The Manager reports to the Lead and closes the investigation tab. No code-review team or pair branch is required. The Manager's check establishes answer completeness; it is not independent verification of every technical claim.

An unresolved question receives a clear “uncertain” answer if useful evidence can still be provided. Missing information blocks the task only when it prevents a useful answer, rather than merely preventing runtime confirmation.

Follow-ups during active work append a `[question Q<n>]` task step and go through the Manager. The investigator checks new task steps before reporting completion. After completion, the Lead creates a new linked investigation task when fresh exploration is needed; it uses previous answers as pointers and rechecks relevant source. It can answer an already-supported clarification from current context, identifying earlier evidence when appropriate. No permanently running investigator or persistent project index is introduced.

The Lead gives the user readable answers, with citations intact. Investigation completion must not produce the existing “branch ready to merge” message. Quick Explore answers follow the same evidence standard, without creating a tsk task for every small question.

## Global constraints

- Use existing ranks, task states, messaging, restart, and handoff behavior.
- Keep user interaction through the Lead by default. Direct `launch investigator -` remains an optional standalone entry point.
- Use source inspection and existing read-only observations. Do not claim production behavior without production evidence.
- Do not edit project files or run write-producing project commands during investigation. Writing answer steps to tsk is allowed.
- Preserve original question text and task notes. Use numbered append-only steps for added questions and answers.
- Quick lookup helpers use haiku-5.5 with medium effort and read-only access, as requested in review. The investigator continues to inherit inspector model/effort. Do not change global models or permissions for this feature.
- Do not add web research, automatic fixes, embeddings, vector stores, a new CLI command, or a long-lived Q&A service.
- Implementation must load writing-for-agents/writing-skills guidance before changing rank/persona/skill instructions.
- This directory currently has no Git repository. Do not initialize one or claim commits; use an authorized source checkout if one is provided.
- No implementation, live agent launch, push, merge, or global installation is authorized by this planning request.

## Current implementation evidence

- `ranks/crew-lead.md` already sends quick read-only questions to Explore and other work to the Manager.
- `ranks/crew-manager.md` lists build, bug validation, review, and test teams, then describes the build/review completion pipeline.
- `bin/crew` discovers jobs and teams from files. `cmd_team()` starts in `$REPO` and creates worktrees only for the configured worktree modes that require them.
- `teams/lead.conf` already uses `worktree=none`. An investigation team can use the same mode.
- `ranks/crew-inspector.md` forbids Edit and Write. It permits source inspection and tsk steps, but also tests; the investigator must explicitly avoid commands that write artifacts.
- Lead completion instructions currently assume a `crew/T<n>-pair` branch. They need a research-specific reporting path.
- `test/dry-run.sh` runs the actual launcher with fake Herdr, tsk, and Git; it can verify launch behavior, not the quality of live agent answers.

## Review focus

- A missing feature: report search scope and uncertainty instead of claiming universal absence.
- Partial or conflicting integration: distinguish a definition from a reachable flow and documentation from current code.
- A follow-up after code changes: recheck relevant evidence and identify the inspected source version.
- A batch with one unresolved item: preserve order, answer covered questions, and explain the remaining gap.
- Research completion: never trigger code review, branch reporting, merging, or a default fix task.

## Task 1: Add the investigation job and launch route

**Files:** Create `personas/investigator.md` and `teams/investigate.conf`; modify `test/dry-run.sh`. No launcher changes are expected.

**Interfaces:** `investigator` and `inspector@investigator` resolve to the same job. `herdr-crew team investigate T<n>` launches one inspector in `$CREW_REPO`. Team configuration: `members=inspector@investigator` and `worktree=none`.

- [ ] Add regression checks to the existing fake-tool harness: both launch specs create a task and start an inspector with the investigator brief; direct team launch starts one inspector; cwd is the repo; no worktree creation or checkout occurs.
- [ ] Verify `member@investigator` fails before tsk/Herdr/Git mutations. Verify domain composition with `inspector@investigator+nestjs-expert` reaches the brief and preserves inspector restrictions.
- [ ] Run `bash test/dry-run.sh`; new investigator cases must fail before the persona/team files exist. Record the direct exit and failures.
- [ ] Add the persona and team files. The persona contains the answer contract, batch numbering, read-only boundaries, source freshness, follow-up step checks, handoff behavior, and `review` completion note defined above. Do not introduce dependencies on unavailable skills.
- [ ] Run `bash test/dry-run.sh` again. All existing and new cases must pass, with direct exit 0. If launcher changes appear necessary, first show the failing case and limit changes to that proven boundary.

## Task 2: Route Q&A and complete investigation tasks

**Files:** Modify `ranks/crew-lead.md` and `ranks/crew-manager.md`.

**Interfaces:** Lead dispatches `T<n> (investigate)` through the Manager. The investigator's `[answer Q<n>]` steps and `answers ready:` note are the result contract. Manager's `answered:` note tells the Lead to report answers rather than a branch.

- [ ] Update Lead instructions: delegate quick lookups to a read-only Explore sub-agent with model haiku-5.5 and medium effort; define deeper-investigation triggers; preserve question order; require citations and uncertainty; handle investigation completion separately from development completion. Update the Lead's description and quick-lookup instruction together so they do not retain conflicting model or effort defaults.
- [ ] Update Manager instructions: dispatch `investigate`; handle `answers ready:` outside the code-review loop; check every requested question has an answer and evidence or a stated gap; request corrections before `done`; report and close the tab.
- [ ] Define active follow-ups as numbered task steps plus existing messages. Define completed follow-ups as linked new tasks when new exploration is required. Never replace the original tsk notes.
- [ ] Inspect the composed investigator brief through the fake harness. Ensure the default domain and optional domain skills do not override the persona's no-write rules or cause automatic fixes.
- [ ] Review the instructions against all five Review Focus cases. Do not describe prompt-string assertions as proof of real routing behavior; live acceptance in Task 3 supplies that evidence.

## Task 3: Document usage and verify end-to-end behavior

**Files:** Modify `README.md`, `SKILL.md`, `docs/STATE.md`, and `docs/PROGRESS.md`; create `docs/adr/0016-project-qa.md` after confirming the ADR number is still free.

**Interfaces:** Normal questions go to the Lead. Optional direct usage is `printf '%s\n' '<question>' | herdr-crew launch investigator -`, with `HERDR_ENV=1` in a valid Herdr environment.

- [ ] Document one question, a numbered batch, an active follow-up, and a follow-up after completion. Add the persona/team to reference lists. Explain source-only versus runtime evidence and the cost of an extra investigator.
- [ ] Record the decision and preserve existing accepted ADRs. Update state/progress with the exact verification scope achieved.
- [ ] Run `bash -n bin/crew test/dry-run.sh test/worktrees.sh`, `bash test/dry-run.sh`, and `bash test/worktrees.sh`. Record each direct exit; all must be 0.
- [ ] Once live testing is authorized, use a disposable committed fixture with: a wired feature, an unused definition, a documented but absent feature, and one flow whose entry point, service, and persistence are in separate files. Keep the fixture outside production projects.
- [ ] Ask the Lead one simple existence question. Verify it delegates to a read-only sub-agent using exactly haiku-5.5 with medium effort, confirmed through invocation metadata, and returns checked source evidence without starting a build team. If the runtime cannot express those settings, record that incompatibility and leave this acceptance step pending.
- [ ] Ask a batch covering the wired feature, unused definition, absent feature, and cross-file flow. Verify one investigation task, original order, accurate conclusions, valid file/line citations, and explicit source-only limits.
- [ ] Add a follow-up while the investigator is active. Verify the new numbered question is answered before completion or becomes a linked follow-up if completion races with delivery; it must not be silently lost.
- [ ] After completion, change the fixture's flow in a new commit and ask another follow-up. Verify refreshed citations/conclusions and a linked task when needed. Verify no stale claim is presented as a current check.
- [ ] Verify investigation reaches `done` without a review team, pair branch, or merge message. Compare tracked/untracked fixture files before and after investigation, excluding only explicitly recorded fixture changes; verify investigation itself writes no project files.
- [ ] Request a fresh review of the routing instructions, result contract, and acceptance evidence. Fix findings within this scope. If live checks are not run, leave them unchecked and record “launcher verified; live Q&A acceptance pending.”

## Tradeoffs and deferred work

A permanent investigator would preserve more conversational context, but costs a running pane and risks stale source knowledge. Linked tasks and saved tsk answers are the proposed smaller first version. A separate general researcher role would need web access and a different evidence policy; it is outside this project-Q&A scope.

Inherited Haiku settings may be insufficient for difficult architecture questions. Measure answer quality with the fixture first; a model change is a separate decision if this reveals failures. The Manager checks completeness but can miss plausible incorrect claims; source citations and live acceptance reduce this risk without adding a review agent to every answer.

## Planning verification

This plan was checked against the current launcher, Lead/Manager instructions, inspector permissions, persona/team discovery, and fake-tool test structure. No implementation tests or live agent checks were run for this documentation-only change. The plan intentionally relies on existing launcher behavior and records runtime acceptance separately.

## Execution result (2026-10-14)

Implemented and independently reviewed. Quick-answer evidence gap fixed and rechecked live. Syntax, 136 launcher checks, four worktree checks, live quick lookup, and batch plus active follow-up passed. Source-change follow-up created a linked task; its final answer verification was stopped to conserve tokens. One compound-launch test variant is deferred. See docs/STATE.md for limits.
