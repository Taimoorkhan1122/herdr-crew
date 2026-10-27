# 0018. Project agent assignments and native launch adapters

- Status: Superseded in part by 0019 (OpenCode model and effort selection)
- Date: 2026-10-27

## Context

The user approved easy per-project agent selection by role. Rank files mixed permissions with Claude model defaults, while a partial OpenCode branch passed unverified startup arguments without native rank permissions. Herdr supports many agent kinds, but kind selection alone does not preserve crew role boundaries.

## Decision

`herdr-crew configure` writes validated JSON to `.herdr-crew.json` in the primary project checkout. Each linked worker worktree uses that file. Four rank defaults plus job overrides cover mixed teams without modifying bundled roles. The CLI supports a human wizard, noninteractive assignments and effective-setting inspection. Writes are atomic and symlink destinations are refused. User-wide defaults are deferred.

A small sourced Bash helper isolates configuration and OpenCode policy construction while the launcher retains lifecycle orchestration. Existing bundled defaults and the legacy rank OpenCode selector remain fallbacks. This extends ADR 0005 without changing its historical body. Switching runtime clears incompatible inherited model/effort values. Saved per-agent metadata pins resolved selection for restart; the original pane retains its session environment.

Initial adapters are Claude and OpenCode 2. Claude keeps native rank/settings behavior. OpenCode uses per-pane inline configuration and `--standalone`; native ordered rules deny unknown tools and preserve rank command permissions. Members receive edit/shell access with push/merge denies, and external-directory requests need approval. Subagents stay denied because built-in helper permissions are not inherited from the caller. Runtime guidance replaces Claude-only tool, plugin, hook and Monitor steps. No global agent configuration is written.

Implementation was checked against [OpenCode 2 permission rules](https://opencode.ai/v2/docs/permissions/), [agent schema](https://opencode.ai/v2/docs/agents/) and [private CLI servers](https://opencode.ai/v2/docs/cli/), plus installed 2.1.2 loader inspection for `OPENCODE_CONFIG_CONTENT` precedence. Inline config follows project/global configuration; managed settings retain authority. This is a native tool policy, not an OS sandbox. Trusted runtime plugins remain trusted host code.

## Consequences

Projects can share or retain local assignments, and new launches preflight all selected slots before creating resources. Configure does not start agents or require a running server. Authentication and provider/model availability remain the user's normal runtime setup.

OpenCode 1, Codex, Gemini and other kinds fail explicitly until verified native adapters exist. Separate OpenCode effort and model variants are unsupported. Portable skills require runtime-appropriate installation; the existing dependency installer remains Claude-specific. OpenCode has no crew context hook or asynchronous Monitor replacement, so prompt guidance reports reduced monitoring guarantees. Full live orchestration, permission enforcement and handoff acceptance remain unverified. Restart preserves the provider/model selection; it does not migrate sessions. The existing handoff-path race is outside this change.
