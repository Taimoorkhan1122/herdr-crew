# Current state

Status as of 2026-10-14. Crew launch and project Q&A have live scratch-repo evidence; full development acceptance remains pending. Two live problems are open: the Haiku driver claimed it had no shell, and the Manager used an archived task number. Live test 3 (review and test teams) has not run. Verification is tracked per feature below; launch tests do not establish full lifecycle acceptance.

## Command-line UX (2026-10-27)

- `bin/crew` now has a complete command-line interface: `help [<command>]`, `<command> --help` for every command, `--version`/`-V`, a global `--dry-run`, and `completion <bash|zsh>`. The layer lives in `lib/ux.sh` and is sourced before the tsk, herdr and jq checks, so help and version need none of them.
- Output is consistent: result lines start with `crew:`, progress lines with `->`, warnings with `warning:` on stderr, and warnings never fail a command. Colour appears only on a terminal and honours `NO_COLOR`; it decorates words and never replaces them. No message text changed.
- `status` prints `T<number><TAB><status><TAB><title>` rows and then the agent rows, instead of dumping the raw task JSON. `status --json` prints that JSON for scripts. Errors now list the valid values or the next command. `close` outside a workspace fails with its own message instead of a Bash parameter error. `watch` handles Ctrl+C.
- Automated evidence: 41 new assertions went RED before implementation, then 222 checks in `test/dry-run.sh` exit 0, four real-Git checks exit 0, and 68 configuration checks exit 0. Each of the seven scripts in the AGENTS.md verification block passed `/bin/bash -n`. Both completion scripts parse (`bash -n`, `zsh -n`).
- PR Lens review of `a90c2bd` found five findings with one root cause: the `jq`, `tsk` and `herdr` checks ran before the pure-text paths, so `--help`, `--version`, `help`, `help <command>` and `completion` all died with `jq not found` on a machine without `jq`. The "help works without the runtimes" assertion also proved nothing, because stub tools stayed on PATH and `command -v` still succeeded. Fixed in `61d6859` and `6220dea`; the stub test is replaced by a symlink farm that really lacks the three. `230` dry-run checks now exit 0. Git is still required for every invocation, because repo and slug resolution runs first.
- Not verified live: terminal colour on a real TTY, Ctrl+C during a real `watch`, loading a completion script into an interactive shell, and any agent launch. No live Herdr session, task, or agent ran for this change.
- Published as PR #4 (https://github.com/Taimoorkhan1122/herdr-crew/pull/4), base `main`, head `feat/cli-upates`, commit `a90c2bd`. The branch also carries the user's `cli-developer` reference commit `182a65a`. GitGuardian checks pass; PR Lens was pending at publication. Merge, installation and release did not run.
- One pre-existing test bug was fixed: `test/agent-config.sh` did not reset `rc` before its final check, so that check failed on unmodified HEAD as well.

## Per-project agent configuration (2026-10-27)

- OpenCode model/effort picker follow-up implemented locally: catalog-backed numbered/exact/search model selection and only supported variants, default/EOF/failure handling, explicit-effort validation, native agent #variant and pinned restart. Model changes clear incompatible inherited variants. Final66 focused,170 launcher,four Git checks and seven syntax/whitespace checks exit0. Independent P2 fixed/rechecked. Native2.1.2 metadata/config parser and disposable wizard confirm DeepSeek/high; no generation or installed-copy update. See [ADR 0019](adr/0019-opencode-model-variants.md).

- PR #2 Git policy follow-up: explicit git -C push/merge denies supplement direct-command rules; bare forms already match OpenCode trailing space-star semantics. Six new failures before fix, then focused58 checks exit0; launcher170, real-Git4 and seven syntax/whitespace checks exit0. Regression evaluates generated policy against documented matching; installed native enforcement remains untested. These command patterns do not constitute a universal shell sandbox.

- PR #2 review follow-up: the agent-switch test now checks the exact member/opencode/default/default row. A disposable resolver mutation preserving haiku/high passed the old assertion and failed the strengthened one. Fresh focused42, launcher170 and real-Git4 checks pass, exit0; runtime code is unchanged.

- Added `.herdr-crew.json` with rank defaults/job overrides, a human configure wizard, argument-based assignments and resolved `--show` output. Configuration belongs to the primary project checkout and is shared with worker worktrees, including uncommitted edits. Optional user-wide defaults are deferred.
- Native adapters support Claude and OpenCode 2. Other kinds fail explicitly. Claude settings/hooks remain; OpenCode gets per-pane inline native role policy with standalone mode and runtime-specific skill/helper/context guidance. No global/provider settings are changed. Saved selection plus original pane environment pins restart; legacy OpenCode metadata without policy is refused.
- OpenCode has no crew context-warning hook or asynchronous Monitor equivalent. Subagents are disabled; missing/plugin-only skills are reported. Model-specific efforts select catalog variants; the crew agent retains the variant while the root model stays unqualified. Managed runtime policy and trusted plugins remain runtime trust boundaries. No full parity or live behavior is claimed.
- Automated evidence: configure missing-feature RED exit 1 then GREEN; adapter RED exit 1 (9 failures) then GREEN; unsupported model variant RED exit 1 (2 affected checks) then GREEN. Independent review's three P2 issues gained four failing regressions (RED exit 1) before correction. Final `test/agent-config.sh`: 42 checks, exit 0; `test/dry-run.sh`: 170 checks, exit 0; `test/worktrees.sh`: four checks, exit 0. Seven shell syntax checks (five required scripts plus helper/new suite), whitespace and affected documentation links passed, exit 0. Fixtures use disposable HOME/projects and fake runtimes; they do not prove live permission enforcement.
- Independent final source review rechecked all three findings and found no remaining P1/P2 blocker. Fixes reject JSON streams before writes, resolve actual primary working directories with separated-metadata fail-safe behavior, and preserve rank-only team slots. Ambiguous manually entered linked checkouts require `CREW_REPO`; crew-created workers already receive it.
- Published in PR #2; no live agent/model calls, authentication/model-availability checks, installation or merge. Existing handoff race and historical acceptance gaps below remain unresolved. See [ADR 0018](adr/0018-project-agent-config.md) and the README for the exact command/schema and runtime limits.

## Visual planning (2026-10-14)

- Added a planner member job and plan team, with a shared contract/template and source-grounded diagram example. No bin/crew, ctx-guard or dependency-installer changes.
- Lead/Manager instructions keep their existing permissions. Manager drafting completion is separate from real-user versioned approval. Revisions retain task/branch/history; material revisions require new approval. Testing/simulation input is not authorization. The documentation-only member scope is instruction/review policy, not a new filesystem sandbox.
- Before drafting/revision and implementation dispatch, target source version/dirtiness is reconciled with the retained snapshot. Relevant drift blocks progress until an explicit source decision; no automatic reset/merge.
- Regression evidence: 12 missing-feature assertions failed before implementation; 167 checks then passed. Independent review found one P2 source-drift gap; three added assertions failed before correction. Final hermetic suite: 170 checks, exit 0/ALL PASS. Four real-Git worktree checks and each of five shell syntax checks exited 0. Documentation links/whitespace checked separately.
- Chrome parsed all three Mermaid blocks (template overview and example flow/sequence). The sample SVG page was inspected at 1200px desktop and 500px actual narrow viewport, in light/dark, with expanded details and keyboard focus; no horizontal overflow. The browser's minimum viewport was 500px despite a smaller resize request. Independent review confirmed SVG/Mermaid semantics and embedded example bytes match.
- Independent review found no other blockers; its one source-drift finding was corrected through RED/GREEN contract checks. No live planner/Lead agents, installation, production changes, merge or push ran for this feature. Actual agent planning, approval/revision behavior, offline fallback and full handoff/restart remain live acceptance gaps in [the checklist](planning/acceptance.md). The separate five maintenance findings remain unresolved.

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

- The hermetic test `test/dry-run.sh` runs 170 checks with fake `herdr`, `tsk`, and `git` shims. All pass under `/bin/bash` (bash 3.2). It covers launch, team, say, mark, status, close, the AXI brief lines, and the fixes below.
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
