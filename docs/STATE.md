# Current state

Status as of 2026-10-14. Crew launch and project Q&A have live scratch-repo evidence; full development acceptance remains pending. Two live problems are open: the Haiku driver claimed it had no shell, and the Manager used an archived task number. Live test 3 (review and test teams) has not run. Verification is tracked per feature below; launch tests do not establish full lifecycle acceptance.

## Source review (2026-10-14)

Independent KISS review found one high-priority handoff-path race and four medium-priority issues: stale test branches, missing review-worktree ownership validation, failed agent reads reported as gone, and an undeclared required skill. These are source-review findings with no runtime fixes yet. See [the review](maintainability-review-2026-10-14.md) for locations, regression recommendations, and verification limits. Passing existing suites does not settle these gaps.

## Project Q&A (2026-10-14)

- Added investigator and investigate, quick/deep routing, evidence-based answers, numbered follow-ups, and separate answer completion (ADR 0016). No launcher changes.
- Verified live in a disposable fixture: quick lookup; four batch questions plus active Q5; citations, scoped absence, partial wiring, source version and gaps; Manager completion at done with answered: 5 questions. No pair/review branches or project-file changes.
- The quick invocation used model alias haiku and effort medium. The child transcript confirms claude-haiku-5-5. Native Agent accepts aliases rather than full model IDs; the Lead reports pinning and resolution limits.
- Independent review found a missing quick-answer evidence contract. Fixed it and verified a fresh quick answer includes Q1, repo/branch/commit, working changes, citations, and source-only limits.
- tsk rejects multiline step text. Answers use single-line steps with semicolon-separated fields.
- Shell syntax and 136 hermetic launcher checks passed. Four real-Git worktree checks passed. Tests do not prove answer quality on arbitrary projects.
- After a fixture source change, the completed-task follow-up created linked T19. Its final answer verification was stopped to conserve tokens at user request. Scratch workspace closed; this acceptance case remains pending.
- Deferred minor: no dedicated compound launch inspector@investigator+nestjs-expert test. Generic composition and investigate --persona tests cover the components separately.
- Existing scratch Manager startup issue required one manual brief delivery after confirming no prompt was recorded. No startup code was changed.

## What works (verified live)

- `/herdr-crew lead "..."` starts a crew tab with the Lead, the Manager, and the board (live test 2).
- The Lead creates tasks and messages the Manager, and the Manager starts a pair team (live test 2).
- The Haiku driver starts and runs in its own worktree (live test 2).
- Workspace trust prompts for panes the launcher starts are answered automatically. This was fixed after live test 1. Live test 2 started its panes without a stall, but this was not checked separately.
- Re-running `/herdr-crew lead "..."` sends the text to the running Lead and does not start a second crew.

## Automated checks and partial live coverage

- The hermetic test `test/dry-run.sh` runs 136 checks with fake `herdr`, `tsk`, and `git` shims. All pass under `/bin/bash` (bash 3.2). It covers launch, team, say, mark, status, close, the AXI brief lines, and the fixes below.
- Autonomous task completion (ADR 0014). The manager runs pair, then review, then fix rounds (max 3), and marks `done` after the reviewer approves. `close <T#> <team>` closes one team tab, and a review re-run reuses its worktree. Dry-run checks cover the launcher and the prompt text only. The loop has not run live.
- The Lead monitor (ADR 0015). `herdr-crew watch` polls the board every 20 seconds and prints one line per change. The Lead runs it with the Monitor tool. Dry-run checks cover task changes and unchanged-task silence. A board Monitor started during live Q&A; independent agent/handoff wake-up coverage remains pending.
- The context budget (ADR 0015). `bin/ctx-guard` warns each agent once at 135K tokens, and the launcher registers it with `--settings`. `handoff` writes the handoff file, and `restart` starts the agent again from its saved brief. Dry-run checks cover the hook output, the once-per-session marker, the settings flag, the handoff and restart flow. Live threshold crossing and a full handoff/resume cycle remain unverified.
- Launching a review spec (`code-reviewer`) is refused before any `tsk`, `herdr`, or `git` call. Before this fix it created an orphan task.
- `team` outside a crew pane uses `HERDR_WORKSPACE_ID` inside Herdr, and the `crew-<slug>` workspace outside it. Before this fix it stopped with `no workspace known`.
- `launch` sets a new task to `ready` after `tsk add`. Before this fix it stayed `open`.
- The AXI tools: the `axi:` lines reach the brief, and a missing tool prints a warning. The Manager ran `quota-axi --no-credential-refresh` during live Q&A. The Lead's own Lavish review flow remains unverified; direct Lavish use by the implementing agent is separate evidence.
- The `nestjs-expert` persona now lists the two Supabase skills. Their source is `supabase/agent-skills`, added to `skills.sources`.
- Lead, Manager, and inspector ran in live Q&A. Quick-helper metadata confirmed Haiku 5.5 with a medium-effort invocation. Complete per-rank/provider effort verification and the member settings remain pending.
- The live Q&A Manager used the caveman skill and the Lead produced readable answers. Formal compliance with every communication-style rule was not audited.
- Investigator instructions and some default skills ran in live Q&A. Complete skill loading and compatibility for every job/domain remain unverified.
- Section 22 of the hermetic suite covers visible-paste Enter recovery, one submission for ambiguous input, and fast completion. A scratch Manager still required one inspected manual brief delivery; full startup reliability remains unresolved.
- `bin/install-skills` has not been run against a clean machine. Its missing-AXI branch, which runs `npm i -g`, is not exercised. The machine where it was checked has all AXI tools installed, so only `--check` ran.

## Open issues

1. Live: the Haiku driver said it had no shell, so it did not commit. The cause is unknown. It could be a hook, or Haiku misreading its tools.
2. Live: the Manager used an archived task number (T3, not T4).
3. Remaining live coverage: every rank/provider/effort, formal style compliance, all persona skills, and all AXI flows. Q&A smoke coverage does not settle these wider requirements.
4. Startup can print a warning without proving whether a prompt was delivered. The Q&A Manager needed manual brief delivery after inspection. The recovery paths have hermetic coverage; startup reliability remains open.
5. Low priority: the navigator and test allowlists (now widened), a half-dead crew after a rebuild, and resuming a crew after `close`.

## Gotchas learned

- `herdr pane split` does not inherit `--env` from `tab create`. Every pane needs its own `--env` values.
- Claude's workspace trust dialog defaults to "No, exit". The launcher sends Down and then Enter.
- A big bracketed paste can lose its final Enter, or land during SessionStart hook output. `submit` handles both cases.
- An agent's `tools:` list must include `Skill`, or it cannot load skills.
- The bare `caveman` skill in `~/.agents` is broken for `ultra` and `off`. It points to a missing `ultracave` skill. Use `caveman:caveman`.
- 93 entries in `~/.claude/skills` are broken links. 90 of them point into `~/.gemini/skills`.
- `herdr agent list` shows `name` only for named agents. `herdr agent get` returns the state at `.result.agent.agent_status`.
- A user PreToolUse hook blocks some test-runner strings in Bash commands.
- Claude Code's auto-mode classifier once blocked an agent prompt as "Instruction Poisoning". The prompt told the agent to ignore hook reminders. It was rephrased and the user approved the change.

## Next steps

1. Debug the driver shell issue (open issue 1) with a live run.
2. Run live test 3, covering the review and test teams. A review now needs a task that already has `crew/T#-pair`, so run `pair` first.
3. Complete the linked Q&A follow-up after a source change, then verify the context-threshold handoff/resume and remaining rank/skill/AXI cases when live acceptance is explicitly resumed. Do not restart workers for a documentation-only update.
