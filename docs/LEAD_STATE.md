# Lead state and session checkpoint

## Active checkpoint: CLI UX work merged into main — nothing in flight

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
