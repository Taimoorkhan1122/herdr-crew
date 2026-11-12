# OpenCode 2 support in herdr-crew

herdr-crew can run a role on OpenCode 2 instead of Claude Code. Supported agents are `claude` and `opencode` (version 2). Other agent kinds, including Codex and Gemini, need permission/lifecycle adapters before they can be selected. Unsupported selections fail explicitly.

## Select OpenCode for a rank or job

```bash
herdr-crew configure driver opencode --model provider/model --effort high
herdr-crew configure code-reviewer claude --model inherit --effort high
herdr-crew configure --show
```

Replace `provider/model` with a model available in your authenticated OpenCode installation. `--effort` selects a catalog variant of the explicit `--model`; supported names vary by model, so an unsupported choice fails without saving. Keep the variant in `effort` rather than embedding `#variant` in the model field. The adapter writes the native `#variant` only on the crew agent selection, because OpenCode's root model default drops variants.

The wizard and explicit OpenCode efforts query `opencode api --standalone model.list` in the primary checkout. This uses a private metadata server, creates no agent session and submits no model prompt. Catalog errors cancel setup without writing pending changes.

## Launch and preflight

Launch preflight checks the selected executables and the OpenCode major version before creating tasks, worktrees or panes. OpenCode runs with `--standalone` and receives a per-pane native role policy.

Existing OpenCode sessions without saved native-policy metadata must be relaunched rather than restarted.

## Permissions

- Read-only ranks retain their command allowlists.
- Members have edit and shell access, with explicit Git push and merge denies.
- Subagents are disabled to prevent a broader helper policy bypassing the rank.
- Member access outside the working directory may ask for approval.
- Managed runtime configuration and trusted plugins remain part of the runtime's trust boundary.

## Skills and context

OpenCode uses portable skills and bounded shell waits. Automatic crew context warnings and asynchronous Monitor wakeups are unavailable. It reports these limits and hands off before compaction.

Claude plugin skills are not automatically portable. The current `install-skills` installer still targets Claude; install portable skills for OpenCode through its normal skill installation paths. The generated brief identifies the verified crew installation path.

## Known gaps

Runtime policy enforcement and full cross-agent orchestration still need live acceptance; automated fixtures are not that evidence.

For Claude-specific behavior, see [Claude Code support](./claude-support.md). For configuration and inheritance rules, see [Configuring herdr-crew](./configuration.md#configure-runtime-assignments).
