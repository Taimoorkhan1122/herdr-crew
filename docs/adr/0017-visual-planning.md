# 0017. Versioned visual plans before implementation

- Status: Accepted
- Date: 2026-10-14

## Context

Users need a short visual explanation and precise implementation tasks before authorizing substantial work. Lead and Manager have no file-writing tools. Existing team/persona discovery supports a small planning job without a launcher change.

## Decision

Add a single member@planner job in a plan team with its own retained worktree. The job writes Markdown with Mermaid source and a local HTML/SVG review projection. Use a shared contract/template for readable diagrams, source evidence and exact task cards. Keep the Lead/Manager's current permissions and existing development and investigation paths.

Manager completion means the draft is ready, not implementation authorized. Lead obtains a real explicit user decision tied to canonical commit/hash and scope, recorded in tsk. Testing/simulation input and ordinary review annotations are not authorization. Approval stays outside canonical Markdown. Material revisions reopen the same planning task and require new approval; preserve prior versions/feedback. HTML is local and excluded from commits regardless of target ignore rules.

## Consequences

No new rank, model, launcher subcommand, board state or renderer service is needed. Planning-only writes are prompt/review policy, not a new filesystem sandbox. Target repositories need a committed base for worktrees. Retained planning branches and tsk evidence support recovery without merging the plan merely to read it. Rendering/approval behavior and restart continuity still require separate live acceptance; existing maintenance findings remain outside this feature.
