# Project-agent skill evaluation

Status: **not run**. These cases specify a comparison, not evidence of candidate behavior. No timing, token count or score has been measured.

## Candidate implementation status (2026-10-30)

The implementation worktree contains the project-owned baseline, validated agent definitions, project setup/upgrade commands, and Claude/OpenCode definition composition. Shell fixtures cover definition validation, init/upgrade preservation and hash checks, and fake native launch output. Project-specific definition selection through the complete launcher/team flow remains an integration gap. These are source and fixture observations only; no provider-backed skill comparison, routing evaluation, live runtime session, or native policy enforcement evaluation has been run.

The evaluation's hook case has a known capability gap in this snapshot: the launcher still registers the existing bundled Claude context guard, while project hook snapshot registration remains in progress. `hooks/context-limit.sh` and `hooks/task-complete.sh` exist in the package, but their existence and standalone fixture results do not prove that a running session invokes them. OpenCode automatic context-hook behavior is not established. Task completion remains explicit through task status/handoff evidence and review; stopping an agent does not establish completion. Update this section and record evidence only after the implementation and hook integration are stable.

The candidate is not yet accepted as complete: final integrated suites, independent whole-change review, model-driven evaluation, live acceptance, and runtime-native enforcement evidence remain outstanding. Do not treat the three rows below or automated fixture passes as evaluation scores.

## Repeatable procedure

1. Snapshot the pre-change skill package from the exact Git base and the candidate package from the implementation under review into separate read-only directories. Record their commit or source tree identities and SHA-256 hashes. Include the actual scripts, libraries and skill files each version needs; do not use a live installed skill as a shared mutable baseline.
2. For each case and each version, create a new temporary workspace, agent home and environment. Materialize `fixture.directories` and `fixture.files`, run `git init` only for each `fixture.git_init` directory, and execute its `prepare` instruction with the version being evaluated. If preparation cannot be accomplished, record that run as blocked with the command and output. Do not hand-create expected output in place of a failed setup. Keep a separate baseline snapshot for the upgrade case.
3. Create executable fail-closed `herdr` and `tsk` stubs on a private PATH. Each stub logs its arguments to that run's log and exits nonzero. Verify `command -v` resolves to the stubs and that the log works before each run. Prevent real crew/runtime launches and global changes using the evaluation harness's isolation controls, not only a prompt. The isolated evaluation agent itself is the only provider-backed model execution; no provider-backed crew agents, real Herdr/tsk integrations, dependency installation or live acceptance are authorized.
4. Give the case prompt to a fresh isolated agent context for each version, with that version's skill explicitly loaded. Preserve the complete transcript, command outputs, stub logs, initial and final file trees, hashes, and any captured native adapter configuration. Do not reuse conversations or fixture directories across cases or variants. Record the agent/provider/model, skill identity, start/end times and token counts only if supplied by the harness; otherwise mark them unavailable.
5. Inspect outputs before defining mechanical assertions. For each expected outcome in `evals/evals.json`, record pass, fail, blocked or unverified with a concrete file path, command exit, byte comparison or transcript excerpt. Use human inspection for quality and capability claims. In particular, instruction prose is not native permission evidence, and a stub-only run does not prove a real integration. Keep failed and unexpected actions in the report. Compare candidate and previous results case by case; do not assume the old version passes.
6. Run a separate routing evaluation with fresh contexts and no forced skill load, if the harness can observe skill selection. Report it separately from the explicitly loaded output-quality runs. Do not infer trigger accuracy from forced skill invocations.

## Report template

| Case | Version | Status | Evidence and observed actions | Duration / tokens | Gaps |
| --- | --- | --- | --- | --- | --- |
| fresh-project-isolation | previous / candidate | not run | none | unavailable / unavailable | all |
| custom-inspector-policy | previous / candidate | not run | none | unavailable / unavailable | native policy |
| legacy-upgrade-and-hooks | previous / candidate | not run | none | unavailable / unavailable | hook capability |

Record fixture creation and cleanup, version hashes, commands with direct exit codes, output and artifact paths, and any unavailable measurements alongside each actual run. Results stay in an ignored local evaluation workspace; do not include private material in committed evidence.
