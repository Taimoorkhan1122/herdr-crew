# Lead state and session checkpoint

## Active checkpoint: herdr-crew command-line UX update

Updated: 2026-10-27 (PKT, Asia/Karachi).

- Objective/authorization: the user installed the `cli-developer` skill and asked for a complete UX update of the herdr-crew CLI. The user chose "just build it" when offered the brainstorming questions, so the scope is the CLI surface itself under this repository's existing contracts. No merge, push, publication, installation or live agent run was requested or performed.
- Repository: branch `feat/cli-upates` (pre-existing name, including its typo) at 182a65a, in the main checkout. Work is uncommitted and unstaged. Changed files: `bin/crew`, `lib/ux.sh` (new), `lib/agent-config.sh`, `test/dry-run.sh`, `test/agent-config.sh`, `README.md`, `SKILL.md`, `AGENTS.md`, `docs/features.md`, `docs/STATE.md`, `docs/PROGRESS.md`, this checkpoint. No file was staged and no commit exists for this work.
- Decisions: the CLI stays Bash and stays Bash 3.2 compatible; no rewrite in another language and no new dependency. Every command name, argument, exit code and launch/restart contract is unchanged, so the change is additive plus one output fix. The terminal layer went into a new `lib/ux.sh`, sourced before the tsk, herdr and jq checks, so `help` and `--version` work on a machine with none of them. Colour is TTY-only and honours `NO_COLOR`; it decorates the words and never replaces them, so every existing assertion still matches. Global options must precede the command, so an instruction can never be read as an option. `status` no longer prints the raw task JSON; `status --json` keeps that form for scripts. Shell completion was included because the `cli-developer` skill treats it as required polish; it prints a script and never installs one.
- Completed: `help [<command>]`, `<command> --help` for all eleven commands, `--version`/`-V`, global `--dry-run`, `completion <bash|zsh>`, `crew:`/`->`/`warning:` line prefixes, a progress line per agent start, Ctrl+C handling for `watch` (exit 130), readable `status` rows plus `status --json`, error messages that list valid values or the next command, and a real error for `close` outside a workspace instead of a Bash parameter error.
- Evidence: 41 new assertions in `test/dry-run.sh` section 27 went RED (exit 1) before implementation; the same section then passed. Final direct exits: `test/dry-run.sh` 222 checks exit 0, `test/worktrees.sh` four checks exit 0, `test/agent-config.sh` 68 checks exit 0, and each of the seven scripts in the AGENTS.md verification block passed `/bin/bash -n`. `completion bash` passes `bash -n`; `completion zsh` passes `zsh -n`. `test/agent-config.sh` also had a pre-existing bug, not caused by this change: it never reset `rc` before its final check, so that check failed on unmodified HEAD at 182a65a (67 PASS, exit 1) and passes now with one added `rc=0`.
- Work in hand: nothing is delegated and no agent, pane, task or worktree is running. The work is uncommitted on `feat/cli-upates`. Also still open from the previous checkpoint: the authorized publication of `feat/opencode-model-picker` in `.superpowers/worktrees/opencode-model-picker` (push, PR, remote-hash verification). Its feature ledger is `.superpowers/sdd/opencode-model-picker/progress.md`. Main's separate uncommitted edits and the PATH-installed skill copy are untouched.
- Limits: no live terminal colour, no Ctrl+C during a real `watch`, no completion script loaded into an interactive shell, and no agent launch, Herdr session or tsk task. No live acceptance of any kind ran.
- Next: 1) `git status --short --branch` and `git diff` to review the scoped change. 2) Decide with the user whether this lands as a commit on `feat/cli-upates` or is isolated on its own branch, since the branch also carries the earlier `cli-developer` reference commit. 3) After a decision, run the verification block in AGENTS.md and record the direct exit codes here. 4) Return to the parked `feat/opencode-model-picker` publication. Merge, push, publication and cleanup all remain unauthorized.

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
