# Lead state and session checkpoint

## Active checkpoint: validation spikes passed; research updated, PR #7 open

Updated: 2026-11-02 15:16 PKT. Repository `/Users/gok/git/herdr-crew` is on branch `docs/herdr-core-app-migration-research` three commits above `main`. The validation update and this planning update are committed locally and not pushed. PR #7 is open at https://github.com/Taimoorkhan1122/herdr-crew/pull/7; its visible head is a4a2f17 with GitGuardian passing and review required. No merge is authorized. This session is an hc terminal (`HC_TERMINAL_ID=t2v`), not a crew, so no runtime `herdr-crew handoff` was written.

Objective and decision: research a full replacement of legacy `herdr` with `herdr-core` (`hc` 0.1.16) plus `herdr-app` 0.1.11. The user chose full replacement with the app required, report only. Completed now: the five validation spikes from the report, the evidence note `research_notes/Herdr core and app migration/validation-spikes-2026-11-02.md`, matching updates to `reports/Herdr core and app migration.md`, `docs/STATE.md` and `docs/PROGRESS.md`, ADR 0025, and the six-task plan `docs/superpowers/plans/2026-11-02-herdr-core-app-migration.md`. No source, test, prompt, dependency or installation change.

Stable conclusions: Option A, app-owned frame with `hc` control, is viable. App-created terminals are visible to `hc get` in 0.27 s and carry `herdr.space`/`herdr.tab` labels. An `env CREW_*` prefix delivers the environment and `HC_TERMINAL_ID`. A real agent moved null → working → done/turn 1, but an untrusted-folder dialog keeps status null, so readiness needs a screen read. Blocked send exits 9 and a missing terminal exits 3. The app wrapper returns a shell in the same pane after a normal agent exit, so no custom keep-alive is needed; `hc kill` closes the pane and `keep` does not recover it.

Work in hand: none. The validation and planning updates are local commits on the branch, not pushed. The disposable `crew-spike` app space was closed, all nine terminals it created were removed, and the scratch `HC_SESSION=cs` core was stopped. No spike terminal or process remains. Preserve untracked `HANDOFF.md`.

Limits: no live crew launched and no launcher behavior changed. The blocked-send result used a synthetic OSC 7501 report, not a real permission prompt. App restart, pane titles, split ratio, headless use and app/core compatibility remain unverified.

Next: 1) Review the plan and ADR 0025, then choose an execution method (native or subagent-driven). 2) Push the local commits to PR #7 only with explicit authorization. 3) Merge PR #7 only with explicit approval. 4) Do not start the launcher rewrite before the plan is approved.

## Historical checkpoint: migration research handed off with PR #7 open

Updated: 2026-11-02 14:45 PKT (Asia/Karachi). User requested handoff. Repository `/Users/gok/git/herdr-crew` is on branch `docs/herdr-core-app-migration-research`, tracking origin, at commit a4a2f17. No staged changes. PR #7 is open at https://github.com/Taimoorkhan1122/herdr-crew/pull/7; GitGuardian passed, no merge authorized. This session is an hc terminal (`HC_TERMINAL_ID=t2v`), not a crew: `CREW_AGENT`, `CREW_TASK` and `CREW_SLUG` are unset, so no runtime `herdr-crew handoff` was written.

Objective and decision: research a full replacement of legacy `herdr` with `herdr-core` (`hc` 0.1.16) plus the required `herdr-app` 0.1.11. User chose full replacement, app required, report only. Completed: `reports/Herdr core and app migration.md` and five evidence notes under `research_notes/Herdr core and app migration/`. The report covers 30 legacy `herdr` call sites, the hc/app split, eight hard gaps, three architecture options, user impact and five validation spikes. No source, test, install or runtime changes.

Key conclusion: feasible control-plane rewrite, not a dependency swap. Recommended app-owned layout with hc-owned control. Per-pane env, agent-to-pane binding, same-pane restart, pane titles, space identity, process lifetime and headless use need redesign. Old `herdr` remains maintained and is not deprecated, so migration is a product choice.

Work in hand: none. PR #7 awaits review and merge decision. Uncommitted working-tree state is preserved: `docs/LEAD_STATE.md`, `docs/PROGRESS.md` and `docs/STATE.md` edits (pre-existing work plus this checkpoint), and untracked `HANDOFF.md` from 2026-10-30. Do not overwrite or remove them.

Limits: no live crew or agent acceptance; herdr-app claims come from its CLI, skill, docs and d.ts, not an open-window mutation test; app/core version compatibility is unpublished. No installation, cleanup, merge or live launch authorized.

Next: 1) Review PR #7 and merge only with explicit approval. 2) Before implementation, run the five isolated validation spikes in the report under a scratch `HC_SESSION` and XDG paths. 3) If the spikes pass, write the migration plan and ADR; if app argv, first-task delivery or blocked-send handling fails, stop and choose Option B or defer.

## Active checkpoint: local main updated

Updated: 2026-10-30 13:22  (Asia/Karachi). User requested pull. Local main fast-forwarded to 5f4fb10ea5e8e4b0043fdbf4291f99e218da83a1, matching origin/main. Eleven overlapping files were retained in a temporary recovery directory and verified byte-identical to the merged versions. Existing docs/LEAD_STATE.md, docs/PROGRESS.md and docs/STATE.md edits and untracked HANDOFF.md remain. No installation, cleanup or live launch performed. Model-driven evaluation and live acceptance remain unrun; see prior checkpoint for limits.

Next: inspect status and current objective before further work. Preserve existing local edits and the temporary recovery copy until cleanup is authorized.

## Active checkpoint: merged PR, local main behind

Updated: 2026-10-30 13:20  (Asia/Karachi). PR #5 merged as 5f4fb10ea5e8e4b0043fdbf4291f99e218da83a1; both reported checks passed. Remote main and origin/main point there, while local main remains at 90876983460bd0b449b495b4c7fdf7e1aa0bd897, one commit behind. The primary checkout has existing documentation edits and untracked files, including paths now tracked by the merged commit. No synchronization or cleanup was requested or performed. Next inspect those overlapping bytes and preserve all edits before any authorized update of local main. Model evaluations and live acceptance remain unrun.

## Active checkpoint: baseline PR open

Updated: 2026-10-30 12:55  (Asia/Karachi). User authorized commit and PR. PR #5 is open at https://github.com/Taimoorkhan1122/herdr-crew/pull/5 from feat/project-agent-baseline to main; commit f6a447edf655e42ca00ceb9f4aba8aae8e16dde7 is confirmed at the remote branch. Worktree /Users/gok/.codex/worktrees/d91c/herdr-crew is clean on that branch. Main remains at 9087698 with its previous documentation edits and no staged changes. PR Lens was pending at publication. Prior checkpoint contains verification and remaining limitations.

Next: inspect PR #5 checks and reviews if asked. Model-driven evaluations and separately authorized live crew/native policy acceptance remain unrun. No merge, installation, cleanup or live launch authorized. Preserve main work and both worktrees.

## Active checkpoint: PR authorized

Updated: 2026-10-30 12:53  (Asia/Karachi). User requested commit and PR for the reviewed project-agent baseline. Work remains in detached /Users/gok/.codex/worktrees/d91c/herdr-crew at 9087698, no staging; main checkout retains its unrelated documented edits. Remote main was verified at the same commit and no open PR existed. Scope includes the approved implementation, its tests and supporting project documentation; exclude HANDOFF.md and preserve main's work. Next create a feature branch in the existing worktree, stage and inspect the scoped diff, commit, push and create a PR. No merge, installation, cleanup or live crew launch authorized. Previous verification and residual limitations are in the following checkpoint.

## Active checkpoint: local baseline implementation verified

Updated: 2026-10-30 12:46 PKT (Asia/Karachi). User resumed the approved project-agent baseline and requested GPT-6 Luna sub-agents. Main remains at 9087698 with existing documentation edits and no staged changes. Implementation is uncommitted in detached worktree /Users/gok/.codex/worktrees/d91c/herdr-crew at the same commit; see its git status and diff, including untracked files. No commit, push, installation, cleanup or live crew launch authorized.

Completed: project definitions, initialization and hash-bound upgrades, native adapters and saved restarts, project hook snapshots and explicit completion reports, migrated legacy definitions, and updated skill/docs. Independent whole-change review found partial first-use setup failure; test/partial-init.sh failed exit 1 then passed exit 0 after initialization order changed. Reviewer reported no other material finding. A stale dry-run hook-path assertion was fixed; its first run was interrupted by an overlapping test-file edit and is invalid. Stable rerun of /bin/bash test/dry-run.sh exited 0 (ALL PASS). Final /bin/bash test/agent-definitions.sh, test/project-baseline.sh, test/hooks.sh, test/test-completion-hook.sh, test/test-hook-integration.sh, test/project-launch.sh, test/partial-init.sh, test/installer-agents.sh, test/worktrees.sh, and test/agent-config.sh each exited 0. Bash syntax for changed scripts, Bash/Zsh completion syntax, eval JSON, documentation links and git diff --check exited 0. These are fake-integration and real-Git fixture results, not live native enforcement.

Remaining: completion may notify twice if killed between delivery and marker; stale completion locks and a noncooperating editor race during directory replacement remain. Actual candidate-versus-previous model skill evaluations were not run: no isolated harness was established that guarantees fail-closed integrations and prevents global writes; procedure is in docs/research/project-agent-evaluation.md in the implementation worktree. Live crew and native policy acceptance remain separately unauthorized. No worker or test process remains in hand.

Next: inspect git status and full uncommitted diff in the implementation worktree, including untracked files; decide how to run the isolated evaluation under the documented safeguards. Keep live acceptance and publication parked until explicitly authorized. Preserve both worktrees and all existing edits.

## Active checkpoint: integrated baseline verification

Updated: 2026-10-30 12:42 PKT (Asia/Karachi). User resumed approved baseline and requested GPT-6 Luna sub-agents. Main is at 9087698 with original documentation work and no staging; implementation is uncommitted in detached worktree /Users/gok/.codex/worktrees/d91c/herdr-crew at the same commit. No commit, push, installation, cleanup or live crew launch authorized.

Hook integration and legacy cutover are in the worktree. Independent reviewer found partial first-use setup failure; test/partial-init.sh reproduced exit 1 and passed after initializing before definition loading. Reviewer found no remaining material issue after the fix. Definition, project launch, partial init, installer, baseline, hook integration, standalone hook, real-Git worktree, syntax, completion syntax, JSON and whitespace checks have passed on the integrated tree; dry-run and agent-config suites are still running and must be collected. Hook notification can repeat after a crash between delivery and marker; stale locks and directory-swap races remain limitations. Model-driven skill evaluations and live native policy/crew acceptance remain unrun.

Next: collect test/dry-run.sh and test/agent-config.sh direct exits from active sessions/logs, fix any failures, reconcile documentation and inspect the full diff including untracked files. Update STATE and PROGRESS with actual final evidence and this checkpoint before ending. Preserve both worktrees and all existing edits. Publication and live acceptance are parked.

## Active checkpoint: implementation resumed

Updated: 2026-10-30 12:22 PKT (Asia/Karachi). User explicitly resumed the approved baseline and requested GPT-6 Luna for sub-agents. Main remains at 9087698 with existing documentation edits and no staging; implementation is uncommitted in detached worktree /Users/gok/.codex/worktrees/d91c/herdr-crew at the same commit. See HANDOFF.md for inherited evidence and gaps. No commit, push, installation, cleanup or live crew launch authorized.

Work in hand: hook integration agent owns bin/crew and hook tests; native verification agent is read-only; documentation agent owns README.md, SKILL.md, docs/features.md and evaluation procedure in the implementation worktree. Coordinator checks baseline preservation, integrates and verifies. Tests run during concurrent edits are not final evidence. Next inspect agent reports and stable diffs, finish integration, run required checks and obtain independent whole-change review. Preserve recovery backups and existing edits.

## Active checkpoint: plan shown before execution

Update 2026-10-30 12:18 PKT: user requested handoff and stop. Active native-launch worker interrupted; other workers finished. No project test processes matched the post-interruption process check; unrelated Fox & Cub processes were left untouched. Exact current state, ownership, evidence, known preservation and notification gaps, and resume steps are in `HANDOFF.md`. Main and managed worktree remain at 9087698 with no staging; implementation uncommitted in `/Users/gok/.codex/worktrees/d91c/herdr-crew`. Do not resume without a new instruction. No commit, push, installation, cleanup or live crew launch authorized.

Update 2026-10-30 12:05 PKT: user requested continue after agent usage interruptions. Managed worktree `/Users/gok/.codex/worktrees/d91c/herdr-crew` remains detached at 9087698, with uncommitted implementation and copied planning docs; main retains original documentation edits and no staging. Bootstrap preservation fixes, native launch integration, and independent hook integration tests have been reassigned to their prior workers with separate file ownership. Previous focused passes do not prove final integration; last bootstrap worker stopped while adding fixes to four independently reproduced loss/partial-init cases. No commits, pushes, installations, cleanup or live crew launches authorized. Inspect worktree and focused regression results before integrating, then complete hooks, documentation, required suites and independent final review.

Update 2026-10-30 12:09 PKT: bootstrap agent reports focused regressions GREEN after observed RED for four review findings; selected upgrade now requires reviewed source and destination hashes. Native launch fixture reports six checks exit 0; existing suite checks and compatibility cutover remain in progress. Hook integration fixture is RED, with five expected failures; hook integration and restart snapshots are not implemented. No final full-suite or review evidence yet.

Update 2026-10-30 12:13 PKT: bootstrap re-review found partial initialization rejects valid job settings when definitions are missing; initial regression passed after fix, expanded suite running. Native launch fixture passes nine checks including traversal and missing/malformed snapshot refusal. Existing launcher/config suites running on stable Task 3 files; shared edits must wait for those processes. Hook integration fixture has seven expected RED failures and awaits ownership of `bin/crew`. Corrected `upgrade --help` to include reviewed target hash; syntax and help command exited 0. Retained directory backup does not fully close noncooperating editor race; independent final review remains required.

Update 2026-10-29 23:28 PKT: Lavish feedback approved the plan and explicitly requested small independent parallel agent tasks, changing the earlier native-only execution choice. Managed implementation worktree `/Users/gok/.codex/worktrees/d91c/herdr-crew` is at 9087698; approved spec, plan and standards research copied there without changing main originals. Task 1 definition implementation and Task 2 bootstrap are delegated with non-overlapping file ownership; coordinator integrates and maintains this checkpoint. Hook investigation completed read-only: Claude Stop is not proof of completion, OpenCode session plugin integration is unverified, and existing say delivery semantics need care for deduplication. Evaluation case/procedure drafts are in `/tmp/herdr-crew-evals.sN7pJv/`, not executed. No commit, push, installation, cleanup or live crew launch authorized. Dependencies and shared launcher files must be integrated in order; final independent review remains required.

Update 2026-10-29 23:34 PKT: definition registry focused test passed after observed RED; context and completion hook standalone suites passed after RED. Hooks are not integrated. Completion handler cannot guarantee exactly-once delivery across a crash after delivery and before marker; stale lock and delivery proof require review before claiming acceptance. Bootstrap agent continues; native-launch agent is preparing separate regression tests. Evaluation drafts copied to worktree `evals/evals.json` and `docs/research/project-agent-evaluation.md`; JSON structure check exit 0, no evaluation runs. Prior clean baseline suites all exit 0; concurrent suites while bootstrap is partially written are invalid and require rerun.

Update 2026-10-29 23:35 PKT: bootstrap agent reports focused baseline and agent-config suites, syntax, completion and whitespace checks exit 0 after RED; ownership of `bin/crew` and `lib/agent-config.sh` passed to native-launch agent. Upgrade preview reports source hashes and each `--apply PATH --expect SHA256` checks the reviewed bytes. Directory replacement currently retains a recovery backup; interrupted swaps, non-cooperating edits and TOCTOU remain open and are under independent read-only review. Native-launch RED fixture exists; integration in progress. Context/completion hook integration remains pending. No commits or live runs.

Update 2026-10-29 23:37 PKT: independent review reproduced an upgrade overwriting a destination edited after preview. Bootstrap agent is correcting this with destination-state validation and a failing regression; the previously recorded focused pass does not establish preservation acceptance. Native-launch agent continues on separate files.

Updated: 2026-10-29 23:24 PKT (Asia/Karachi).

- Objective: resume the approved project-agent baseline implementation, with the plan shown first as requested. The approved native task-by-task method and independent final review remain in force; no new design approval is needed. Commit, push, installation, destructive cleanup and live crew launches remain unauthorized.
- Repository: main at 90876983460bd0b449b495b4c7fdf7e1aa0bd897; existing thirteen documentation changes are unstaged, no staged changes or runtime edits. Existing worktrees were listed; none is a new implementation checkout. Preserve all work.
- Plan: `.lavish/project-agent-baseline.html` was corrected to reflect the already-selected execution method. Lavish initially returned 500 because its server could not read its state file (EPERM). With no active feedback listeners reported, `lavish-axi stop` exited 0 and reopening the plan exited 0 at http://127.0.0.1:4387/session/b2165da25834971c. Canonical plan: `docs/superpowers/plans/2026-10-29-project-agent-baseline.md`. The page uses the existing repository review palette; browser rendering has not been independently verified.
- Work in hand: no implementation started. Next inspect the plan and current Git state, establish isolated worktree and carry required uncommitted documents without disturbing originals, then execute Task 1 through Task 5 sequentially with regressions and independent final review. Preserve the evidence limits and explicit authorization boundaries in the checkpoint below.

## Active checkpoint: native execution authorized; stopped for handoff before implementation

Updated: 2026-10-29 23:21 PKT (Asia/Karachi).

- Objective/authorization: user approved the design and selected AGENTS.md, Agent Skills and its evaluating-skills/agentic-script guides. User then said continue after the plan handoff recommending native execution plus independent final review; this authorizes that execution method. Before implementation, user interrupted and explicitly requested handoff. Stop work after saving the OS-temporary handoff and this checkpoint. Preserve all settled design boundaries. No commit, push, installation, cleanup or live crew launch authorized.
- Repository: main at 90876983460bd0b449b495b4c7fdf7e1aa0bd897, initially clean and matching its locally recorded upstream. Thirteen unstaged documents: GLOSSARY.md; docs/adr/0020-0024; docs/research/2026-10-29-package-simplification.md and 2026-10-29-agent-specifications.md; docs/superpowers/specs/2026-10-29-project-agent-baseline-design.md; docs/superpowers/plans/2026-10-29-project-agent-baseline.md; docs/README.md, PROGRESS.md and this checkpoint. No inherited staging or runtime edits.
- Completed: primary sources researched; ADR 0024 records the selected standards and local-metadata/native-policy distinction. User clarified AGENTS.md rather than Oracle/OA. Complete five-task implementation plan includes definition migration, project setup/upgrades, native registration/pinned restarts, project hooks and three-case isolated skill evaluation. Parent self-review checked spec coverage, interfaces, edge-case tests and scope. All earlier accepted decisions remain in ADRs 0020-0023.
- Work in hand: native implementation was about to begin. The first tool batch only requested skill reads, workspace/plan reads, memory search and worktree-tool discovery; it was aborted with no tool output retained. Current Git still shows documentation only, no staged changes and unchanged HEAD. No new implementation worktree was created in this turn. Helpers finished earlier. Process inventory was unavailable because ps is denied; do not infer process absence from that failure. No crew environment is set, so no runtime crew handoff is required.
- Evidence/limits: live official-doc reads cover AGENTS.md, Agent Skills, evaluation/script guides and native Claude/OpenCode V2 formats. Thirteen-document file/link checks, five-task/four-reference assertions and git diff --check each exited 0. Source/tests unchanged. No model-driven eval, runtime/schema experiment, runtime suite, migration experiment or live acceptance has run. A self-contained ignored .lavish/project-agent-baseline.html embeds the design/plan and matches this repo's prior review palette; Lavish open returned SERVER_ERROR 500, and Chrome open returned No page is currently selected. Do not claim it was served or visually verified; Markdown artifacts are the verified handoff. No server/runtime changes attempted.
- Next on resume: 1) Read this checkpoint, STATE/newest PROGRESS, approved design, research and docs/superpowers/plans/2026-10-29-project-agent-baseline.md; inspect Git state. 2) Use executing-plans for authorized native execution and using-git-worktrees to establish appropriate isolation. The approved artifacts are untracked/uncommitted in main and will not appear in a clean worktree automatically; preserve them and explicitly carry required docs into the chosen isolated checkout without committing or discarding main's work. 3) Begin Task 1 with failing regressions, continue sequentially and obtain one independent final review. Do not re-ask the settled design or execution method. Publication, installation, worktree removal and live crew acceptance remain unauthorized.

## Historical checkpoint: CLI UX work merged into main — nothing in flight

Updated: 2026-10-27 15:22 PKT (Asia/Karachi). Written at handoff, after the merge.

- Objective/authorization: the user installed the `cli-developer` skill and asked for a complete UX update of the herdr-crew CLI, then chose "just build it" when offered design questions. The user authorized commit, push and PR, and later passed PR Lens review findings for correction. Merge of #4 was never requested in this session, yet PR #4 is merged (receipt below). Installation, release publication and cleanup were not performed.
- Repository: on `main`, clean tree. Local `main` equals `origin/main` at `c792f3ad973db63670a6b4af1c474388382115ac`, the squash of PR #4. `git diff 3dde78c c792f3a` is empty, so every branch change landed intact.
- Merges: PR #4 merged by squash 2026-10-27T09:49:00Z, GitGuardian pass. PR #3 (OpenCode model and effort picker) merged 08:51:35Z, PR #2 (per-project agent config) merged 07:22:32Z, PR #1 (visual planning) merged 2026-10-14T19:53:04Z. `main` log shows `c792f3a` (#4), `f437249` (#3), `57400a4` (#2) and merge commit `985334d` (#1). Every publication parked in earlier checkpoints is therefore complete: no PR is open and none is pending. The old note that the opencode picker still needed a PR was wrong; PR #3 existed and merged.
- Delivered CLI surface, now in `main`: `help [<command>]`, `<command> --help` for all eleven commands, `--version`/`-V`, global `--dry-run`, `completion <bash|zsh>`, `crew:`/`->`/`warning:` line prefixes, a progress line per agent start, Ctrl+C handling in `watch` (exit 130), readable `status` rows plus `status --json`, error messages that list valid values, and a real error for `close` outside a workspace. New terminal layer `lib/ux.sh`. No command name, argument, exit code or launch/restart contract changed.
- Review fixes: PR Lens posted five findings against `a90c2bd`, one root cause. The dependency checks ran before the pure-text paths, so `--help`, `--version`, `help` and `completion` died with `jq not found` on a machine without jq, and the "works without the runtimes" test was vacuous because stub tools stayed on PATH and `command -v` still succeeded. Reproduced on a PATH lacking all three, fixed in `61d6859` and `6220dea`, and the stub test was replaced by a symlink farm that really lacks them. Every pure-text path now runs before the checks. Git stays a hard requirement, because repo and slug resolution runs first.
- Evidence at branch tip `3dde78c`, whose content is identical to `main`: `test/dry-run.sh` 230 checks exit 0, `test/worktrees.sh` four checks exit 0, `test/agent-config.sh` 68 checks exit 0, seven `/bin/bash -n` checks exit 0, `completion bash` passes `bash -n`, `completion zsh` passes `zsh -n`, `git diff --check` exit 0. A pre-existing `test/agent-config.sh` bug (missing `rc=0` before its final check) was fixed here; it also failed on unmodified HEAD.
- Work in hand: nothing. No delegated agent, tsk task or crew is running. This pane (`w22:p1`) is a plain Herdr pane, not a crew: `CREW_AGENT`, `CREW_TASK` and `CREW_SLUG` are unset and there is no `~/.herdr/crew/herdr*` state directory, so no runtime `herdr-crew handoff` was written. The repository checkpoint below is the handoff.
- Local branches now stale, because their work is in `main` by squash: `feat/cli-upates` (3dde78c), `feat/opencode-model-picker` (b021adb), `feat/project-agent-config` (7342553), `feat/visual-planning` (60ab5c1), `chore/banner-push` (f3531da). Origin holds only `main` and `feat/project-agent-config`; the rest were deleted on the remote after merge. Branch deletion, worktree removal and any other cleanup stay unauthorized.
- Recorded here: this checkpoint and the matching `docs/PROGRESS.md` entry are one documentation-only commit on `main`. It is not pushed, so `main` sits one commit ahead of `origin/main`; the working tree is clean.
- Limits: no live TTY colour, no Ctrl+C during a real `watch`, no completion script loaded into an interactive shell, no agent launch and no crew run. No live acceptance ran. No second PR Lens pass ran against `6220dea`, so the merged squash is reviewed only by the first pass.
- Next: 1) Read `docs/STATE.md` and the newest `docs/PROGRESS.md` entries, then `git status --short --branch`; expect a clean tree and `main` one commit ahead of `origin/main`. 2) Ask the user whether to push that commit, and whether to delete the stale branches and the merged worktrees; pushing and deletion need explicit authorization. 3) Start new work from `main`.

## Historical checkpoint retained below


Updated: 2026-10-27 13:18 PKT (Asia/Karachi).

- Objective/authorization: user requested interactive OpenCode model and supported-effort selection after the wizard rejected high. Implementation and independent review complete; user explicitly authorized Push PR. Preparing normal feature-branch publication. Merge, installation, model generation and cleanup remain unperformed/unauthorized.
- Repository: feat/opencode-model-picker in .superpowers/worktrees/opencode-model-picker, based on main57400a4386ce3d8607bf50a57cb7961119263e7a. Ten scoped files: README.md, SKILL.md, lib/agent-config.sh, test/agent-config.sh, docs/features.md, ADR0018 status/new0019, STATE/PROGRESS/this checkpoint. Main's existing edits and visual-planning docs are preserved separately. No staged work inherited.
- Behavior: project-scoped OpenCode catalog via private metadata API; numbered/exact/search model picker and supported variants; no-variant/default handling; EOF/failure preserves saved config. Explicit efforts validate against the model catalog. Store existing model/effort fields, encode #variant on crew agent only; root model remains base. Model changes clear incompatible inherited variants; saved selection/environment pins restart.
- Prior evidence: focused66/launcher170/Git4 checks exit0 (240 total), seven syntax and docs/whitespace checks passed. Installed2.1.2 catalog, native config parser and disposable wizard confirmed exact DeepSeek/high without generation/session. Fresh worktree verification: focused66, launcher170 and Git4 exit0 (240 total); seven syntax, affected links and whitespace exit0. Independent review's one P2 inheritance issue gained a failing regression, fixed/rechecked across four cases; no other source findings. Minor README clarification applied.
- Work in hand: parent owns final verification, commit, normal push and PR creation; canonical opencode-picker-publication list. Feature ledger .superpowers/sdd/opencode-model-picker/progress.md stores receipt. Main retains an uncommitted source copy; PATH installed skill is separate and unchanged. No active agent/model sessions started.
- Limits: no generation/billing/authentication acceptance or full native policy/lifecycle run. OpenCode hooks/Monitor/additional runtime adapters and historical handoff race remain parked. No new dependency.
- Next: run syntax/config/launcher/worktree checks here, inspect scoped diff and commit; push feat/opencode-model-picker, open PR against main and verify remote equality. Keep all worktrees and main edits; record final receipt in main checkpoint and ignored feature ledger.

## Historical checkpoint retained below


Updated: 2026-10-15 00:44 PKT.

## Objective and authorization

Implement the approved runtime visual-planning workflow. The user explicitly approved in the main conversation after clarifying that earlier Lavish inputs were testing. That main-conversation approval is the authorization; simulated review input is not. Native execution with independent final review was used.

Scope: planner persona/team, shared contract/template/example, Lead/Manager routing and versioned approval/revision/source checks, docs/ADR and regression fixtures. The separate five-finding maintainability plan is still unapproved. The user subsequently requested commit and push in the main conversation. Commit and push of feat/visual-planning are authorized. Merge, live agents, installation, release publication and cleanup remain outside scope.

## Repository and changes

- Main checkout tracks origin/main. Feature work is isolated at .superpowers/worktrees/visual-planning on feat/visual-planning, based on 879f9bb. Implementation commit: a643765. A documentation handoff commit records the authorized feature-branch push; inspect git log/status for its final hash.
- User work on main and its index is preserved. Feature changes are in README.md, SKILL.md, ranks/crew-lead.md, ranks/crew-manager.md, test/dry-run.sh; new personas/planner.md, teams/plan.conf, docs/planning/, approved spec/plan and ADR 0017; feature/reference/state/history updates accompany them.
- bin/crew, bin/ctx-guard and bin/install-skills remain byte-unchanged from baseline. The current authorized action is a normal feature-branch push to origin; verify its remote hash before claiming completion.

## Completed and verified

- Shared plan contract, template and source-grounded handoff example; stable tasks, diagrams, source evidence, exact tests/exits and explicit unknowns.
- One documentation-only member/team using existing discovery. Lead/Manager permission frontmatter unchanged. Draft-ready/done never authorizes implementation; real-user approval records commit/hash/scope in tsk. Revisions preserve history and re-arm monitoring.
- Independent review: one P2 target-source dirty/drift gap; fixed with read-only checks at draft/revision/pre-dispatch and explicit-source-choice blocking. No other blockers/minors reported.
- Direct exits: missing-feature RED 1 (12 failures), first GREEN 0 (167 checks), source-review RED 1 (3), final GREEN 0 (170). `/bin/bash test/worktrees.sh` exit 0 (four checks). Each of five scripts independently passed `/bin/bash -n`, exit 0. Documentation link/whitespace checks and git diff --check passed.
- Browser: three Mermaid parses passed; accessible SVG semantics and embedded canonical example independently matched. Light/dark screenshots, expanded details, focus, no horizontal overflow at 1200px and actual narrow 500px. Screenshots/local example are in the feature worktree .lavish/ and excluded from commits.

## Work in hand and limits

Implementation and review corrections are committed at a643765. Only the authorized handoff commit, normal feature-branch push and remote-hash verification remain for this turn. No live crew resource was started. Live agent compliance, approval/revision behavior, offline fallback and restart continuity remain unverified; see docs/planning/acceptance.md. Existing restart race and the other audit findings remain separate.

The branch/worktree and ignored ledger .superpowers/sdd/2026-10-14-visual-planning/progress.md are retained. No cleanup is authorized. A verified branch push does not imply merge, release publication or full live acceptance.

## Decisions and failed attempts

- Existing ignored .superpowers/ location isolates work without altering target ignore files or staging.
- Source mismatch is detected by the planner before drafting, not by a new launcher guard before pane creation. A planning pane may start before reporting a source blocker. No reset/merge occurs.
- Existing local Mermaid package lookup was unavailable; a browser-loaded module parsed the source without installing a package. Chrome's narrow resize request produced a real 500px viewport; evidence uses that observed width.
- Earlier misread Lavish testing approval caused only an isolated test edit, which was restored before the later explicit main-chat approval. The ledger preserves that correction.

## Next actions

1. Inspect feature `git status --short --branch` and `git log -1`; confirm final commit and that local review artifacts are absent from it.
2. Read the contract/template/example and docs/planning/acceptance.md for the implemented interface and remaining evidence gaps.
3. Verify the authorized push of feat/visual-planning against origin, then await the user's next instruction. Keep merge, release, live fixtures, cleanup and separate maintenance implementation parked.
