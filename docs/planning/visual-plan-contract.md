# Visual plan contract

Read this when drafting, reviewing, revising, or resuming a runtime crew plan. Use [the template](visual-plan-template.md); [the handoff example](examples/handoff-plan.md) illustrates source-grounded content without implementing its proposed fix.

## Source and scope

Preserve the user's request. Inspect entry points, callers, affected tests and configuration. Record the inspected repository, branch, commit and relevant working changes. Distinguish observed behavior, proposed behavior, assumptions and unknowns. Keep source citations valid for the recorded version. Before the first draft and every revision, inspect CREW_REPO HEAD/status separately from the retained planning worktree. Compare the recorded source baseline and actual product files; ignore only the planner's own documentation artifacts when distinguishing plan commits from source advancement. Relevant dirty source or source drift is a blocker until the user makes an explicit source decision. Preserve all work; no automatic reset/merge/refresh. A deliberately chosen older snapshot must be labeled, not presented as current source. Lead obtains fresh read-only HEAD/status evidence again before implementation dispatch and resolves differences against the approved scope/version.

Planning artifacts only: write the canonical Markdown under docs/superpowers/plans/ and its local review files under .lavish/ in the planner's worktree. Read source and existing evidence; do not implement the feature, install dependencies, run builds/tests/migrations or mutate services. Domain personas supply criteria, not permission to execute their implementation flows. The member rank's broad tools remain available: this restriction is instruction/review policy, not a filesystem sandbox.

Use the smallest useful plan. A trivial explicitly requested plan may use a short before/after with a reason instead of a diagram. An ordinary small fix or question need not enter planning unless requested or a decision is unresolved.

## Content

1. Goal: one sentence stating the resulting behavior.
2. Before → after: one concrete trigger, current result, proposed result and why it matters.
3. Scope: included work, exclusions, assumptions, evidence and unresolved questions.
4. Overview diagram: component-style relationships or activity flow. Add a sequence when ordering/failure matters, or a state diagram when transitions matter. Usually one or two diagrams; split rather than exceed three.
5. Task cards S1, S2, etc.: exact files/functions, input/output contract, dependencies, failing regression and expected failure, minimal change, verification command/expected exit and definition of done.
6. Risks, decisions and acceptance limits. User decisions must remain visible; unknown APIs or runtime behavior are not invented.

Use short captions and labels. Aim for about six overview nodes/eight edges or six sequence participants/twelve messages. These are readability defaults, not validation limits. Give related diagram steps the same S IDs as the task cards. Show failure/refusal paths as well as success. Call diagrams UML-style when appropriate; a Mermaid flowchart is not automatically formal UML.

## Canonical source and review page

Canonical source: docs/superpowers/plans/YYYY-MM-DD-<slug>.md, with Mermaid fenced blocks and a short textual explanation. Use relative source citations with explicit source-version context. Start with the template but replace every placeholder before reporting ready. A material unanswered decision can be explicit without pretending the whole plan is executable.

Review projection: .lavish/<slug>-plan.html. Read Lavish's relevant playbooks before rendering. Use accessible, theme-aware inline SVG with titles/captions and stable IDs for ordinary diagrams; editable Mermaid/Excalidraw whiteboards are opt-in. Keep SVG and Mermaid participants, edges, conditions and S IDs equivalent. A projection is never a second independent specification.

Inspect the target project's design system first. For a CLI project with no visual system, use the existing Lavish Tailwind/DaisyUI fallback. Do not introduce a mandatory diagram compiler. A browser/CDN failure must leave the Markdown readable; report visual checks that could not be run.

Inspect desktop/narrow widths and light/dark themes using available browser tooling. Check labels, captions, keyboard access, wrapping and all expanded details. Record actual checks and limits. A screenshot or launch test does not establish plan quality or agent compliance.

Target projects may not ignore .lavish/. Preserve their ignore rules and keep review artifacts uncommitted. Stage only the exact plan Markdown path; inspect the full index before committing. If unrelated staged changes exist, stop and report them rather than commit or unstage user work. Verify the resulting commit contains only the canonical plan, not HTML or unrelated files.

## Result and approval

After committing the plan, record a one-line tsk step:

`[plan ready] path=<absolute Markdown path>; branch=<planning branch>; commit=<plan commit>; sha256=<Markdown SHA256>; html=<absolute local HTML path or unavailable>; source=<inspected version>; checks=<actual checks and gaps>`

Use shasum -a 256 on the canonical file. Hash the file bytes after the commit; verify they match the committed file. Commit/hash identify the content, not approval. Local artifacts can be regenerated by an authorized planner from that source. Keep private content and personal machine paths out of the committed plan; local operational paths may be recorded in the private runtime tsk board as needed.

Planner marks review with `plan ready:`. Without a Manager, a standalone planner stays at review for manual acceptance. Manager checks completeness and source evidence, then marks the drafting task done with `plan ready:`. Draft completion never authorizes implementation.

Lead presents the plan and asks the user to approve the exact version and scope. Read feedback as review content; explicit testing/simulation input is not authorization. Only an unambiguous real user decision authorizes implementation. A preselected option, annotation, task completion, timeout or an open page is not approval. If intent is ambiguous, keep it pending and clarify.

Lead appends one-line evidence to tsk:

`[plan approved] plan=T<n>; commit=<plan commit>; sha256=<Markdown SHA256>; scope=<user-authorized scope>; decision=<explicit user decision>`

Use `[plan rejected]` or `[plan feedback]` for rejection/revision. Preserve original notes and earlier steps. Approval/supersession status belongs in tsk and review-page metadata; do not edit canonical Markdown merely to stamp it approved and invalidate its hash.

Only after approval, create or ready implementation tasks with a reference to that commit/hash and retained canonical path. Workers read the approved plan before editing. A material change to scope, behavior, interfaces, risks or tests needs a revised commit/hash and renewed user approval. Pure review-page styling does not alter the canonical contract. No merge of the planning branch is required to read it.

## Revision and recovery

For active drafting, append feedback to the same task. Manager reconciles the existing planner identity and messages that worker rather than blindly starting a second one. For a completed draft, Lead reopens the same task as ready and asks Manager to rerun plan. Manager verifies worker/tab identity before reusing or closing an owned tab, then reuses the retained planning branch/worktree. Use started → review → done for the revised draft. Lead re-arms board monitoring while drafting is open. Preserve approval history and identify superseded versions.

Handoff records planning task, canonical path, branch/commit/hash, source version, review path, checks/gaps, unanswered decisions, current approval state, linked implementation tasks and next action. Re-read tsk and verify content/hash on resume. If a project maintains a Lead checkpoint file, route its update through an authorized writer; Lead and Manager remain read-only.

If the local worktree or HTML is unavailable, recover the committed plan through an authorized worker; never infer that missing state means approval. An unborn repository cannot launch a new worktree: report the prerequisite without creating an unsolicited initial commit. The known restart handoff-file race remains outside this feature, so prompt/source checks do not prove live restart continuity.
