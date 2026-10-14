# 0016. Project questions use quick helpers or a read-only investigation team

- Status: Accepted
- Date: 2026-10-14

## Context

The user wants informed answers about existing features and project flows. Questions can arrive individually, in batches, or as follow-ups. The Lead already delegates quick lookups to Explore. Deeper questions previously had no dedicated job, and the Manager's completion instructions assumed a development branch and code review.

## Decision

Keep the Lead as the user interface. Quick lookups use a read-only Explore sub-agent with the native Haiku 5.5 model ID `claude-haiku-5-5` and medium effort. Unsupported or overridden settings are reported, rather than silently substituted.

Add an `investigator` persona under the existing inspector rank. Add an `investigate` team with `worktree=none`. It reads current source and configuration, preserves question order, and records one numbered answer per question in tsk. Answers include the direct conclusion, flow explanation, file/line evidence, inspected source version, and verification gaps.

The investigator marks `review` with `answers ready:`. The Manager checks answer coverage and evidence gaps, requests corrections when needed, then marks `done` with `answered:` and closes the investigation tab. The Lead reports answers rather than a merge branch. Investigation does not enter the development review loop or authorize fixes. A standalone launch without a Manager stops at `review` for manual acceptance.

Active follow-ups append numbered question steps. Fresh investigations after completion use linked tasks and refreshed source evidence. Rank permissions stay unchanged; the persona narrows their use to read-only observations and tsk answer records.

## Consequences

The feature reuses the existing launcher, states, messaging, and board. It adds no dependencies, global model changes, or persistent project index. Source inspection does not prove deployed behavior. The Manager checks completeness, rather than independently verifying every claim. A shared current repo can change during an investigation; source-version recording and refreshed reads make this visible.

Haiku 5.5 requires Claude Code 2.1.293 or later. Per-invocation effort requires 2.1.292 or later. Forced model or effort environment settings can override invocation settings. These limits require live verification in addition to launch tests.
