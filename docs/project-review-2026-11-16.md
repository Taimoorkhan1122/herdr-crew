# Project review

Date: 2026-11-16. Read-only review requested by the user, asking for an honest rating, a usability judgment, and improvement priorities. The reviewer inspected the README, SKILL.md, STATE.md, the 2026-10-14 maintainability review, the untracked HANDOFF.md, file sizes and the head of `bin/crew`, and ran four test suites at `main` 5c6c337. No source, test or runtime change was made.

## Rating

- Overall: 6/10.
- Usability for the author: about 7/10.
- Usability for a new user: about 3/10.

## Strengths

- Safety posture is strong: no push, merge or worktree removal without approval, worktree ownership checks, and per-rank Git denies.
- Testing discipline is real. Changes are recorded with failing regressions before fixes, and the suites pass (evidence below).
- Documentation is honest about limits. STATE.md separates hermetic checks from live acceptance.
- The command-line interface is clean: `help`, `--dry-run`, completions, and consistent `crew:`, `->` and `warning:` prefixes.

## Weaknesses

1. **Core value is unproven on the current runtime.** No live crew has run since the `herdr-core` migration. The full lead, pair, review, done loop has never run live on `hc`. Two live problems remain open: the Haiku driver claimed it had no shell, and the Manager used an archived task number.
2. **Scope has grown faster than validation.** Three runtimes, visual planning, hash-checked project upgrades, the configure wizard and the Command Code adapter landed before one live acceptance run of the main loop.
3. **Process outweighs product.** `LEAD_STATE.md`, `PROGRESS.md` and `STATE.md` total about 106K, roughly the size of the launcher and libraries together. There are 27 ADRs for 18 commits.
4. **`SKILL.md` is long and dense.** Agents load it on every invocation. Its runtime paragraph is one very long block of adapter detail, which costs tokens and hides the launch instructions.
5. **The installed copy differs from the repository.** The live crew used `~/.agents/skills/herdr-crew`, which is not a Git checkout and was patched in place. Users run code that the repository suites did not test.
6. **Setup is heavy.** It needs the desktop app, `hc`, `tsk`, `jq`, `rg`, `shasum`, Git and each agent CLI. It cannot run headless or in CI. No single command checks readiness.
7. **Enforcement is pattern and instruction based, not a sandbox.** Shell redirection, aliases or wrappers can evade it. The docs state this, but users may assume stronger isolation.
8. **Earlier maintainability findings may be open.** The five findings in `maintainability-review-2026-10-14.md`, including the P1 restart handoff race, were recorded as unresolved. This review did not check whether the `hc` rewrite fixed any of them.
9. **Stale records.** The untracked `HANDOFF.md` (2026-10-30) describes work that has since been committed, and old work-state lists remain open.

## Recommended improvements, in priority order

1. Pause new features. Run one live end-to-end acceptance on a disposable fixture repository and fix what breaks.
2. Install from a symlink to the repository instead of patching an installed copy.
3. Reduce `SKILL.md` to the launch instructions, spec forms and error handling (about 30 lines). Move adapter detail to `docs/`.
4. Add a `herdr-crew doctor` preflight that checks the app, `hc`, `tsk`, each assigned CLI on PATH and the board in one pass.
5. Triage the five 2026-10-14 maintainability findings: close those the rewrite fixed and fix the rest with regressions.
6. Compact `PROGRESS.md` and `LEAD_STATE.md` by archiving older entries. Remove the stale `HANDOFF.md` once the user agrees.
7. Speed up `test/dry-run.sh`. HANDOFF.md notes that agent definitions are revalidated repeatedly; cache that work without weakening validation.

## Evidence and limits

Hermetic and real-Git suites at `main` 5c6c337, run on 2026-11-16:

- `test/dry-run.sh`: exit 0, ALL PASS, 119 s.
- `test/worktrees.sh`: exit 0, 10 s.
- `test/agent-config.sh`: exit 0, ALL PASS, 62 s.
- `test/project-launch.sh`: exit 0, ALL PASS, 10 s.

Not done: a full read of `bin/crew` and the agent prompts, `test/review-regressions.sh` and the hook suites, ShellCheck, and any live launch. Statements about live behavior come from STATE.md, not from this review. No fixes, installs, commits or publication were performed.
