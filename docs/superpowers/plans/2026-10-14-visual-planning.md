# Runtime Visual Planning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans after user approval. Track steps with checkboxes.

**Goal:** Give the runtime Lead a readable visual-plan workflow that preserves permissions and obtains approval before implementation.

**Architecture:** Add a single documentation-only planner job/team using the existing member rank and launcher discovery. Keep plan content in versioned Markdown/Mermaid, render a local Lavish page, and use existing tsk evidence for versioned approval and session recovery.

**Tech Stack:** Bash 3.2 launcher/configuration, Markdown, Mermaid source, portable HTML/SVG, existing Lavish and tsk. No new runtime library or mandatory diagram compiler.

**Spec:** [Visual planning design](../specs/2026-10-14-visual-planning-design.md). Read it before executing. Execution status: explicit main-conversation approval received; configured workflow and automated/visual checks completed on feat/visual-planning. Live fixtures remain separately pending.

## Global constraints

- Preserve read-only Lead/Manager ranks and the existing investigation/development pipelines. The planner's documentation-only boundary is prompt/review policy, not a new enforced sandbox.
- No new rank, model override, CLI command, board state, global installation, unrelated audit correction, or automatic merge/push/publication.
- Preserve existing staging and uncommitted work. Current baseline is main at 879f9bb with origin/main configured; recheck before execution and use an isolated worktree where appropriate. Handle unborn target repositories explicitly without creating a commit merely to make planning launch work.
- Markdown is the canonical contract. Local HTML stays uncommitted in .lavish/ (ignored only when the target already has a matching rule). Stage only exact plan paths; verify artifacts are absent from commits; preserve target ignore files. All persisted runtime steps are single-line tsk entries. Record commit/hash, scope, feedback and approval; session history is not the only record.
- The earlier maintainability plan remains separately pending. This feature must not silently absorb its fixes, including the known handoff-file race.

## Files and responsibilities

- Create `docs/planning/visual-plan-contract.md`: runtime-facing format, diagram selection, permission/approval, source evidence and recovery rules.
- Create `docs/planning/visual-plan-template.md`: headings, stable task IDs, one illustrative Mermaid block, and task-card placeholders. This is content, not an executable parser/schema.
- Create `personas/planner.md`: member job restricted by instructions to planning artifacts; consumes the installed contract/template and reports versioned output.
- Create `teams/plan.conf`: `members=member@planner`, `worktree=new`.
- Modify `ranks/crew-lead.md`, `ranks/crew-manager.md`: planning route, separate drafting completion, visual feedback, versioned approval, and handoff evidence.
- Modify `test/dry-run.sh`: launch/composition checks for the new team plus explicit routing/permission contract assertions. No generic new testing framework.
- Modify `README.md`, `SKILL.md`, `docs/features.md`, `docs/README.md`, `docs/STATE.md`, `docs/PROGRESS.md`, `docs/LEAD_STATE.md`; add next available ADR for the workflow after approval.
- No `bin/crew` change is expected: the current team/persona discovery already supports the proposed team. If a regression reveals a launcher gap, report it and amend the plan before expanding scope.

## Review focus

1. Draft-ready task marked done: implementation remains unstarted until explicit approval (Task 3).
2. Lead cannot write files: all persistence/rendering uses the authorized planner; no new blanket tool permission (Tasks 1–3).
3. Diagram/prose or SVG/Mermaid disagree: reject draft until participants, conditions and task IDs match (Tasks 1 and 4).
4. Revised plan or resumed session: old approval does not authorize a material revision; recover commit/hash and pending decision (Tasks 3 and 4).
5. Missing browser/CDN or a trivial task: readable Markdown and the existing simple-task route remain usable (Tasks 1 and 4).

## Task 1: Define one clear plan contract and template

**Interface:** The installed skill exposes docs/planning/visual-plan-contract.md and visual-plan-template.md. The planner reads those through the installed herdr-crew skill directory; no dependency installation is required.

- [ ] Write the contract and template from the approved spec. Include goal, before/after, scope, one overview, optional sequence/state detail, task cards, risks/decisions and draft identity. Keep approval status in tsk/review-page metadata, outside the canonical Markdown hash. Keep examples illustrative and proposed behavior labeled.
- [ ] Provide one example for a small local change and one multi-step failure-path example; include plain-language captions and S1/S2 mappings. Avoid requiring every diagram type or needless UML formality.
- [ ] Review the template by filling it with the known handoff-path issue as a documentation exercise only. A different reader must locate exact files, observable failure, expected correction, regression, verification exit and scope without extra explanation. Record any unknowns rather than inventing contracts.
- [ ] Check links, Mermaid syntax in an available existing renderer, and diagram/prose consistency. Record renderer unavailability honestly; add no dependency solely for this check. Review the completed contract before wiring runtime behavior.

## Task 2: Add a documentation-only planning worker

**Interface:** `herdr-crew team plan T<n>` launches one member@planner in crew/T<n>-plan. `herdr-crew launch planner -` is an optional standalone planning route. Output uses `plan ready:` at review and reports canonical path, retained branch/commit, SHA256 and local review page.

- [ ] Add failing launch cases to test/dry-run.sh: plan team exists, one planner member starts in its own worktree, named launch preserves the request, CREW_* environment is present, and it starts neither pair/review/test workers nor extra panes.
- [ ] Run `/bin/bash test/dry-run.sh`; verify failures are due to missing plan configuration/persona.
- [ ] Add personas/planner.md and teams/plan.conf. The worker may read source/Git and write only the plan Markdown plus local review artifacts. It does not run builds/tests/installers or implement the feature. Commit only the canonical Markdown on its branch. Preserve dirty source and no-commit limitations as explicit blockers for a runtime worktree launch.
- [ ] In the persona, require source evidence, short diagrams, task IDs, matching SVG, accessible captions, review-page theme checks, version report and uncertainty. Specify installed contract/template paths and plain-Markdown fallback. Use existing AXI declarations for Lavish as needed; keep current permissions and inherited model/effort.
- [ ] Run the launch suite to exit 0/ALL PASS. Inspect composed briefs for read-only planning scope and artifact/report contract; label these instruction checks, not proof a live agent obeys them. Update progress/checkpoint.

## Task 3: Connect Lead review, Manager completion and approval

**Interface:** Planning task completion means draft available. Implementation requires a user approval step referencing that planning task, canonical commit/hash and scope. Existing task statuses remain unchanged.

- [ ] Add focused prompt-contract regressions for explicit planning requests, `plan ready:` completion, no automatic development dispatch, versioned approval, revision invalidation, standalone review status, reopening a done draft for revision with retained worktree and re-armed monitoring, and preserved investigation/simple-fix routes. Confirm the current prompts fail the new contract checks.
- [ ] Update Lead instructions to select planning when required, create a planning task, dispatch through Manager, read the artifacts, present the Lavish page, and foreground-poll feedback. Keep the Lead without file-writing or direct worker-prompt access. If the surface fails, show Markdown and accept explicit chat feedback.
- [ ] Update Manager instructions with a planning completion path before the development pipeline: inspect requested coverage, docs-only Git evidence supplied by the planner, version/hash, and diagrams. Return missing evidence to the planner; mark accepted draft done with `plan ready:` and report it. Do not launch pair/review/test teams because drafting reached done.
- [ ] Lead records explicit user approval/rejection and feedback in one-line tsk steps. Bind approval to canonical version and scope; materially revised plans return to review. After approval only, create implementation tasks referencing the approved plan path/version. No merge of the plan branch is required to read its retained artifact.
- [ ] Define revision dispatch: Lead records feedback and reopens the same planning task as ready; Manager reconciles live worker identity and reruns the plan team on the retained branch/worktree. Re-arm Lead monitoring, follow started → review → done, and retain all previous approval records. Keep approval authoritative in tsk without editing canonical Markdown to stamp status.
- [ ] Add handoff fields for draft status, commit/hash, artifact locations, feedback, approval, next action and linked tasks. Route project-specific checkpoint file updates through a writer when needed. Run hermetic suite to exit 0 and get independent review of the dispatch boundary and permission claims.

## Task 4: Verify visual clarity and lifecycle behavior

**Interface:** Markdown/Mermaid is durable and usable independently; uncommitted HTML/SVG is a review projection, with the same semantics. Unknown or failed rendering is never approval.

- [ ] Use the Task 1 example to create a review page through the planner instructions. Verify Mermaid/SVG participants, direction, failure conditions and task IDs match; every task states exact files, test and done criteria. Compare generated page to the canonical hash, not a prior screenshot.
- [ ] Render-check light, dark, desktop and narrow widths; check readable labels, keyboard access, captions, no horizontal overflow and usable Markdown fallback. Request independent content review rather than treating screenshot success as plan quality.
- [ ] Prepare an optional disposable committed fixture for live acceptance: request plan, revise it, reject it, approve a specific revision, then request a material change. Verify no implementation before approval and no reuse of superseded approval. Verify standalone planning stays at review without Manager acceptance.
- [ ] Live checks are separately authorized; if not authorized, leave them pending. Session recovery must re-read tsk and the committed plan. The known pre-existing restart handoff race remains a separate risk; do not claim end-to-end restart acceptance from prompt or source checks.
- [ ] Add an offline fallback scenario and a small explicitly authorized fix/source-only question scenario to the acceptance checklist. Verify the new planning route does not expand them automatically.

## Task 5: Document, regress and hand back

- [ ] Document normal Lead use, optional direct planner launch, review feedback, versioned approval, retained planning branch, standalone completion and recovery. Update persona/team/AXI reference tables and dependency declarations only where needed.
- [ ] Add an ADR using the next free number; preserve accepted ADR bodies. Update STATE to separate contract/launch tests, visual inspection, independent review and live acceptance.
- [ ] Run each changed shell script through `/bin/bash -n` separately, `/bin/bash test/dry-run.sh`, and `/bin/bash test/worktrees.sh`; expected direct exits 0. Check Markdown links, example diagrams, review artifacts absent from commits and `git diff --check`. Reuse existing available tooling; no new renderer service.
- [ ] Review all changed files against scope and collect independent review. Record unresolved findings, exact checks/exits, pending live acceptance and any fixture cleanup still requiring approval.
- [ ] Update LEAD_STATE/PROGRESS and hand back. No push, publication, merge, automatic cleanup or unrelated audit implementation follows.

## Proposed execution

Sequential native implementation with independent final review is the smallest route; the contract and both role prompts share one workflow. Per-task implementer/reviewer agents are an alternative. The user approves this design/plan and chooses execution before either starts.
