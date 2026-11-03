# 0025. Replace legacy Herdr with herdr-core and herdr-app

- Status: Accepted (user-selected runtime; implementation pending)
- Date: 2026-11-02

## Context

The user chose a full replacement of the legacy `herdr` multiplexer with `herdr-core` (`hc` 0.1.16) and `herdr-app` 0.1.11. The research report records 30 direct `herdr` calls, the vendor split between process control and layout, and five validation spikes that passed on 2026-11-02. The legacy TUI remains maintained, so this is a product choice, not a forced migration.

`hc` owns terminals, status, send, wait, read and cleanup. `herdr-app` owns spaces, tabs, panes and layout. The app-created terminal is a core terminal, so the two layers meet at a `t*` ID. The app runs every argv through a login-shell wrapper that returns to a prompt when the program exits.

## Decision

Adopt Option A from [the migration report](../../reports/Herdr%20core%20and%20app%20migration.md): the app owns the visible frame and `hc` controls the crew.

- `launch` and `team` create a space, tab and panes with `herdr-app do space.new`, `tab.new` and `pane.split`. Each pane receives its full program as `--argv`, with the crew environment as an explicit `env CREW_*=... <program>` prefix.
- Save `space`, `tab` and `terminal` IDs in each agent's `~/.herdr/crew/<slug>/<agent>.meta`. `hc` operations use the terminal ID, never a pane ID or agent name.
- Send the first brief with `hc send` after readiness. Readiness means a reported status of `idle`, `working` or `done`, or a screen read that resolves a trust dialog. `tab.new --task` is not used because its reply has no delivery result.
- Keep the app's wrapper shell. A normal agent exit returns to a shell in the same pane, and `restart` sends the saved agent command and brief to that shell. An explicit `hc kill` ends the pane; restart after a kill creates a new pane and says so.
- Use `hc ls --json` for `status` and `watch`. Use `hc send` for `say`; a blocked recipient is not bypassed. Exit 9 means a person is needed, exit 3 means the terminal is gone.
- Add `herdr-crew read <agent>` and `herdr-crew wait <agent>` so the Manager can inspect saved terminals without knowing `t*` IDs.
- Replace pane title metadata with a tab rename that keeps the `T# TEAM` prefix used by `close`. A shared tab shows the latest agent event, not per-pane titles.
- Keep `~/.herdr/crew` and `~/.herdr/worktrees` paths and the existing tsk and Git flows.
- Require `hc`, `herdr-app` and a reachable window for `launch`, `team`, `say`, `mark`, `status`, `close`, `watch` and `restart`. Text-only paths and `init`/`upgrade`/`configure` keep their current dependency boundaries.

## Consequences

The launcher, fixtures, prompts, Manager permissions and documentation change together. A compatibility shim named `herdr` is explicitly rejected: it would keep tests green while production is broken.

Users lose headless launch on servers, containers and CI, because the app needs a desktop session. `tsk setup herdr` and the `prefix+t` integration no longer apply; the board becomes a plain `tsk` terminal. Pane-level progress titles become tab-level titles. Restart in place works after a normal exit but not after `kill`. Split ratios use the app default because `pane.split` has no ratio argument.

The new runtime has no published app/core compatibility matrix. The launcher must report both versions on failure and test against the installed pair. Remote machines, `hc events`, and a crew mod remain later improvements.

Implementation is gated by the plan and is not authorized by this record. Evidence: [validation note](../../research_notes/Herdr%20core%20and%20app%20migration/validation-spikes-2026-11-02.md).
