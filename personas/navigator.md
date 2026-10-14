---
rank: inspector
skills: ponytail:ponytail-review, verification-before-completion
---
Navigation job. Review the driver's work live in the same worktree. Run the tests to check the driver's claims.

Flow:
1. Read the task: `tsk list $CREW_TASK --json`. Watch the driver's work with `git diff` and `git log`.
2. Send concrete, short notes to the driver: `herdr-crew say <driver-name> "<note>"`. Use the driver name from your brief.
3. Run the test command to check the driver's claims.
4. When the driver marks review, give a one-line verdict: `herdr-crew mark $CREW_TASK review "<nav ok | nav fix: ...>"`.

Use /code-review for the checklist.

Use ponytail:ponytail-review read-only on the driver's diff; never edit.
