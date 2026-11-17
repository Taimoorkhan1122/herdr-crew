# 0028. A read-only doctor reports launch readiness in one pass

- Status: Accepted
- Date: 2026-11-17

## Context

The launcher checks its dependencies one at a time and stops at the first missing one: `jq`, then `tsk`, then `hc`, then `herdr-app`, then whether the app window answers. A user with three gaps meets them in three separate failed launches. The runtime CLIs for the configured roles are checked only when a team starts, so a misconfigured job can surface minutes into a session. Some gaps, such as the Manager's `caveman:caveman` plugin skill or a divergent installed skill copy, are not detected at all. The 2026-11-16 project review ranked a readiness preflight and a shorter skill entry point as its items 3 and 4.

## Decision

Add `herdr-crew doctor`. It is dispatched with the pure-text paths, before the launcher's dependency gates, so it works on a machine missing `jq`, `tsk`, `hc` or `herdr-app` and reports every gap in one pass. It needs only Git, like the other pure-text paths.

Each check yields a name, a status (`ok`, `missing` or `warning`), a short detail and a fix. A missing item is required for launch; a warning is not. The verdict line is last. Exit status is 0 when nothing is `missing` and 1 otherwise. `--json` prints one document with the checks and the verdict.

The doctor is read-only: it installs nothing, does not initialize the project baseline, opens no tabs and sends no terminal input. `--dry-run` prints the same output. Human output uses the existing UX layer (`crew:` result lines, `warning:` lines on stderr, colour rules). Later tickets reuse the per-runtime validation a team launch runs, executed in report-only subshells, and the skill installer's `--check` mode, so requirement and error text keep one source of truth.

## Consequences

One command answers "can this machine launch a crew, and what is missing". Existing launch and team dependency failures keep their messages and exit codes, so current callers and tests are unaffected; the cost is that the same fix text exists in both the gates and the doctor's own check list.

The doctor's `--json` form is emitted without `jq` (the doctor must run when `jq` is missing), so its strings are static launcher text and must stay free of quotes and backslashes. New checks go through `doctor_add`, which keeps that invariant visible at one place.

Behavior is covered by `test/doctor.sh` on the hermetic launcher seam: fake tools, a symlink-farm PATH that really lacks the runtimes, recorded calls, and read-only proof. No live acceptance is claimed.
