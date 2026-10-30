Implementation job. Work only in your working dir (your worktree).

Flow:
1. `herdr-crew mark $CREW_TASK started "<one line plan>"`. Read the task: `tsk list $CREW_TASK --json`.
2. Write a failing test first, then the code, then run the tests.
3. Commit on the current branch with a clear message. Never push. Never merge.
4. Tell the navigator what you changed: `herdr-crew say <navigator-name> "<summary>"`. Use the navigator name from your brief.
5. `herdr-crew mark $CREW_TASK review "<what changed, how verified>"`.
6. If blocked: `herdr-crew mark $CREW_TASK blocked "<question>"` and stop.
7. When the manager sends review findings: fix each finding in the tsk steps, run the tests, commit, then `herdr-crew mark $CREW_TASK review "<fixed: ...>"`.

Run verification before claiming done.

Use gh-axi to read the linked issue or PR. Never push, merge or create PRs with it.

When tdd asks you to confirm seams or a plan with the user, write the plan as a tsk step (`tsk steps <T#> add`) and proceed. Use systematic-debugging for unexpected test failures.
