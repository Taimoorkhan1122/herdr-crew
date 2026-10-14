# Visual planning in the runtime Lead workflow

Status: approved explicitly in the main conversation and implemented on feat/visual-planning. Automated/visual verification passed; live acceptance remains pending. The user selected runtime Lead workflow.

## Intent

Make a plan understandable from its first screen and executable without guessing. The Lead presents a small visual overview, before/after behavior, and exact implementation tasks. Diagrams explain relationships and failure paths; file paths, contracts, and tests define the work.

## Current constraints

The Lead owns user communication and delegates through the Manager. The Lead and Manager lack file-writing tools. The launcher discovers team and persona files dynamically. Member workers can write and commit in their own worktrees. Current Manager completion assumes either development or investigation; planning needs a separate outcome. Existing Lavish use does not provide a plan-writing permission.

## Proposed first version

Add one job persona `planner` (rank member) and one `plan` team (one planner, worktree=new). Reuse the launcher, tsk board, agent naming, worktree retention, and Manager dispatch. Add no rank, model override, CLI command, or general planning framework.

The planner is instructed to write documentation only. This is an instruction boundary using the existing broad member permissions, not a filesystem sandbox. The Manager checks changed files before accepting the output. Narrow sandbox enforcement would be a separate project.

## When planning applies

Enter visual planning when the user explicitly asks for a plan or when unresolved architecture, multiple dependent changes, or substantial workflow changes need a decision. A small explicitly authorized fix can retain the existing development path. An existing approved plan is reused after verifying its source/version and scope.

Planning permission permits read-only source discovery and writing plan artifacts in the planner worktree; it does not authorize product edits, installs, builds, migrations, or implementation teams. Questions and investigations retain their existing completion paths.

## Plan format

Every plan contains, in order:

1. Goal and draft identity. Keep approval/supersession status in tsk and the review page, outside the canonical Markdown bytes.
2. Before → after: one concrete example and the reason to change it.
3. Scope: included work, exclusions, assumptions, and evidence gaps.
4. Overview: one component-style or activity diagram for a multi-step change. A trivial plan may use a compact before/after instead, with a stated reason.
5. Optional detail: a sequence for ordering/failure behavior or a state diagram for transitions. Normally one or two diagrams; at most three before splitting the plan.
6. Implementation tasks with stable IDs S1, S2, etc.: exact files/functions, input/output contract, dependencies, failing regression and expected result, minimal change, verification command/expected exit, and definition of done.
7. Risks, unresolved decisions, and the approval request.

Keep the overview to roughly six nodes and eight edges. Keep sequence diagrams to roughly six participants and twelve messages; split when labels become hard to read. These are readability defaults, not formal validation limits. Use short labels, direction arrows, a caption, and visible failure/refusal paths. Map affected diagram steps to task IDs. Use plain descriptions rather than claiming every flowchart is formal UML.

## Canonical source and visual review

Store Markdown at `docs/superpowers/plans/YYYY-MM-DD-<slug>.md` in the planning worktree. Use Mermaid fenced blocks as the editable diagram source. Keep source names grounded in inspected files; label proposed behavior and unknowns.

Create `.lavish/<slug>-plan.html` in the same worktree as the local review page. Keep it local and out of commits. Target repositories may not ignore .lavish/: stage only the exact Markdown plan path, inspect the staged diff, and prove HTML is absent from the commit. Preserve existing ignore rules; this feature does not silently edit target .gitignore files. For Lavish, render hand-authored inline SVG from the same diagram semantics; editable Excalidraw whiteboards remain opt-in. Every SVG has an accessible title/caption; the Markdown retains the source and a short textual explanation. The planner checks that SVG and Mermaid express the same participants, edges, conditions, and task IDs.

Inspect the target project's design system before styling its plan. For a CLI project without a design system, use the existing Lavish Tailwind/DaisyUI fallback. Browser/CDN failure never blocks reading the Markdown; presentation failures do not imply approval. This is not a new mandatory renderer dependency.

## Runtime flow and permissions

1. Lead creates a planning tsk task preserving the original request and marks it ready. The task notes label it planning-only.
2. Lead asks Manager to run `herdr-crew team plan T<n>`. The Manager gives the planner the source scope and the installed planning contract/template paths.
3. Planner inspects source, writes the two artifacts, checks diagrams/links, and commits only the Markdown plan on its planning branch. It reports the task, branch, plan commit, Markdown SHA256, and absolute local artifact paths through one-line tsk steps. Mark review with `plan ready:`.
4. Manager verifies coverage, source evidence, documentation-only diff, artifact readability, and reported source version. Missing evidence returns to the planner; a material unanswered user decision stays visible. This path does not start code-review, test, or pair teams. Once the draft is ready for user review, Manager marks the planning task done with `plan ready:`. That means drafting complete, not implementation authorized.
5. Lead reads the plan and opens the existing Lavish review surface. It summarizes the goal, change, risks, and decisions. Use a foreground poll for feedback. If Lavish is unavailable, present the Markdown and request the same explicit decision in chat.
6. Lead records user approval as a one-line tsk step identifying the task, plan commit, Markdown SHA256, and authorized scope. Annotation, opening the page, completed planning tasks, and elapsed time are not approval. Only an explicit user decision authorizes implementation. A declined plan causes no development dispatch.
7. After approval, Lead creates or readies implementation tasks that reference the approved plan version and then uses the existing development workflow. The worker reads the plan from the retained planning worktree; recovery can use its recorded branch/commit via an authorized worker. No plan-branch merge is needed merely to read the plan.
8. For a revision after draft completion, Lead records feedback, reopens the same planning task as ready through the existing board command, and asks Manager to run its plan team again. Manager reconciles any surviving worker before launch; reuse the existing identity-checked planning worktree and branch. Lead re-arms board monitoring. The planner follows started → review; Manager returns a reviewed draft to done and can close its tab while retaining worktree/artifacts. Preserve earlier approval/feedback steps. Material scope, behavior, interface, risk or test revisions get a new commit/hash and require approval before dispatch. Pure review-page styling does not change the canonical contract. Approval is authoritative in tsk: do not edit canonical Markdown just to stamp it approved.

## Session continuity

Runtime coordination stays in tsk; Markdown stays in its committed planning branch. Record paths, commit/hash, approval, unanswered questions, implementation task links, and next action in the existing handoff. If the target project uses LEAD_STATE.md, route checkpoint updates through an authorized writer; the runtime Lead remains read-only. Missing local HTML can be regenerated by a planner from the canonical source. Validate resource identity before reuse; never restart or recreate tasks solely because a session changed.

## Acceptance

- A developer can identify the objective, changed components, main flow, failure behavior, and next executable task without reconstructing them from prose.
- One explicit planning request yields a plan worker and review artifact, with no implementation team before versioned approval.
- Feedback/rejection/restart retains the current draft, task evidence, and pending decision. A materially changed version needs approval again.
- A simple fix and a source-only investigation keep their existing routes unless planning is requested.
- Automated launch checks prove configuration/routing contracts only. Independent content review and an authorized disposable live fixture establish actual planning and approval behavior separately.

## Non-goals and parked work

No redesign of all UML types, diagram for every trivial task, automatic code generation, executable plan parser, new board states, new runtime persistence service, blanket Lead write permission, automatic publication, or unrelated audit fixes. The five-finding maintainability plan remains separate and unapproved.

## Proposed choices for approval

The author proposes a dedicated documentation-only member instead of broadening Lead permissions; Markdown/Mermaid as canonical source plus SVG for Lavish; and explicit approval tied to a plan version. These are proposed design choices, not decisions already made by the user.
