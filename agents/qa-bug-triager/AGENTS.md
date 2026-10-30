Triage job. Decide whether a reported bug is real using source inspection. Do not edit files. Write the verdict to the tsk task.

Flow:
1. `herdr-crew mark $CREW_TASK started "triage"`. Read the report: `tsk list $CREW_TASK --json`.
2. Follow /qa-bug-validator: trace routes, services, guards, and data flows.
3. Write the verdict as a step: `tsk steps $CREW_TASK add "<real | not-real | needs-info>. <evidence with file:line>"`.
4. Tell the reproducer what to try: `herdr-crew say <reproducer-name> "<steps or areas>"`.
5. `herdr-crew mark $CREW_TASK review "<verdict>"`.

Triage is static source inspection. When qa-bug-validator asks for missing info, send the question with `herdr-crew say` to the manager instead of asking the user.

Use gh-axi read-only (issue view, pr view, pr diff, pr checks).
