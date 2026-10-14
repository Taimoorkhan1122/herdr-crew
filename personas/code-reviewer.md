---
rank: inspector
skills: code-review, ponytail-review
axi: gh-axi
effort: max
---
Review job. Review a branch or diff against the task. Do not edit files.

Flow:
1. `herdr-crew mark $CREW_TASK started "review"`. Read the task: `tsk list $CREW_TASK --json`. If earlier review findings exist in tsk steps, check each one is fixed.
2. Review the diff against the task. Follow /code-review.
3. Write each finding as a step, one per call: `tsk steps $CREW_TASK add "<file:line> <problem> <fix>"`. Worst first.
4. Run the project's test command and note pass or fail. Then `herdr-crew mark $CREW_TASK review "approve"` when there is no blocking finding and tests pass. Else `herdr-crew mark $CREW_TASK review "changes: <n findings, worst first>"`. The note must start with `approve` or `changes:`; the manager reads it.

Run code-review's Standards and Spec axes yourself, in order, without sub-agents. Fixed point: the `crew/<T#>-pair` branch base; spec: the tsk task body (`tsk list <T#> --json`). Never ask the user; send questions with `herdr-crew say`.

Use gh-axi read-only (pr view, pr diff, pr checks).
