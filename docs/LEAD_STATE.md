# Lead state and session checkpoint

## Active checkpoint: project agent configuration

Updated: 2026-10-27 11:53 PKT (Asia/Karachi).

- Objective/approval: user approved per-project role-to-agent configuration and configure entry point. Local implementation, verification and independent review are complete. User subsequently authorized committing, pushing and opening a PR against main. Publication is being prepared; merge, installation, live crew acceptance and cleanup remain unauthorized.
- Repository: feat/project-agent-config in the isolated .superpowers/worktrees/agent-config worktree, based on main commit 865135a290445890220eb192366bba624d5b2c9b. Publication snapshot: base commit shown above; inspect git log/status for the implementation commit. Only this feature worktree's named files are included in the commit. Preserve main's pre-existing checkpoint/progress and visual-planning spec/plan edits.
- Changed files: bin/crew, new lib/agent-config.sh and test/agent-config.sh; existing test fixtures; README.md, SKILL.md, personas/planner.md, docs/features.md, docs/STATE.md, docs/PROGRESS.md, this checkpoint; new ADR 0018 and 2026-10-27 project-agent-config spec/plan. The ignored plan ledger is .superpowers/sdd/2026-10-27-project-agent-config/progress.md.
- Behavior: editable .herdr-crew.json in the primary project checkout; human wizard plus role/agent/model/effort arguments and --show; rank defaults/job overrides; no global default file. Claude/OpenCode 2 adapters enforce declared native rank restrictions and preflight all slots. Restart retains saved selection and original pane policy environment. Other agents, OpenCode effort/variants, automatic OpenCode crew context warnings and asynchronous Monitor are unsupported and explicit.
- Evidence: test/agent-config.sh 42 checks exit 0; test/dry-run.sh 170 checks exit 0; test/worktrees.sh four checks exit 0. Each of seven scripts separately passed /bin/bash -n, exit 0. Whitespace and affected doc links pass. Independent final source review found three P2 issues, each fixed with regression evidence (four failures RED 1 to GREEN 0); recheck found no remaining P1/P2 blocker. Earlier feature RED/GREEN evidence is in STATE/PROGRESS/ledger.
- Work in hand: coordinating agent owns completed local changes; nothing running in Herdr and no live test fixture resources. Runtime selection/authentication, live native policy enforcement and full handoff/orchestration acceptance remain unverified. Existing handoff-path race and separate maintainability findings remain parked. Normal crew workers carry CREW_REPO; ambiguous manually entered linked checkouts with separate metadata fail with an explicit primary-project pointer requirement.
- Failed approaches: Skillkit catalog lacked using-superpowers (filesystem skill used); native worktree creation needed automatic sandbox escalation; initial test instrumentation needed argument separators/inherited environment capture. Git worktree inventory alone was insufficient for separate metadata; final discovery verifies an actual working directory and refuses ambiguity.
- Publication scope: normal push of feat/project-agent-config, then a non-draft PR against main using gh-axi. A completion receipt belongs in the main checkout's coordinating checkpoint and ignored feature ledger; revalidate remote equality and PR identity before claiming success. No merge or removal.
- Ordered next actions: (1) run `git status --short --branch` and `git log -1` in this feature worktree; (2) check `gh-axi pr list --state all --head feat/project-agent-config` and the main coordinating checkpoint for publication receipt; (3) preserve the worktree for PR feedback and await explicit merge/installation/live-acceptance instructions. Do not restart historical workers or implement separate maintenance findings.

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
