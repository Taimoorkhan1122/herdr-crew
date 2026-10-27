# 0019. Catalog-backed OpenCode model and effort selection

- Status: Accepted
- Date: 2026-10-27
- Supersedes: the OpenCode effort/model-variant limitation in ADR 0018

## Context

The configure wizard asked for effort even though the first adapter rejected non-default OpenCode efforts. The user requested interactive model choices and only the efforts supported by each model. OpenCode variants are model-specific; a shared hardcoded effort list cannot describe them.

## Decision

Read the primary project's enabled model catalog with `opencode api --standalone model.list`. Offer numbered choices, exact IDs and case-insensitive search; blank or zero uses runtime defaults. Offer only the selected model's catalog variant IDs. Models without variants skip effort selection. Cache metadata for the configure invocation and preserve atomic writes and EOF cancellation. An explicit non-default OpenCode effort also validates against this catalog before saving.

Reuse `.herdr-crew.json`'s model and effort fields. Require an explicit model for a non-default variant. Put `provider/model#variant` only in `agents.crew.model`; keep the root model at `provider/model`. Existing saved selections and the pane environment preserve the variant across restart. Claude effort behavior and native permissions remain unchanged.

## Evidence and consequences

Installed OpenCode 2.1.2 returned a location-scoped catalog including model variants. A private metadata/configuration probe parsed a crew agent's `#high` selection into its native variant field. These probes create no agent session and submit no generation request. See [OpenCode model variants](https://opencode.ai/v2/docs/models/#variants) and [API reference](https://opencode.ai/v2/docs/api).

Configuration with model discovery now requires a working OpenCode metadata API and may start a temporary private server. `configure --show`, Claude configuration and OpenCode assignments using only model defaults remain offline. Catalog availability is not proof of successful credentials, billing, generation or end-to-end lifecycle behavior. Managed policy and runtime/plugin trust boundaries remain those of ADR 0018.
