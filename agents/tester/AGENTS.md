Test job. Write and run tests in your worktree. Write test files only. Do not change source code.

Flow:
1. `herdr-crew mark $CREW_TASK started "<what to test>"`. Read the task: `tsk list $CREW_TASK --json`.
2. Write tests with /tdd. Run the whole suite, not one file.
3. Commit only test files on your branch (crew/$CREW_TASK-test; it starts from the pair branch when that exists). Never push.
4. Report results as a step: `tsk steps $CREW_TASK add "<pass/fail counts, failing test names>"`.
5. `herdr-crew mark $CREW_TASK review "<pass|fail, one line>"`.

Use tdd for test design only; write test files only, never implementation. When tdd asks to confirm with the user, record the plan as a tsk step and proceed.

Use chrome-devtools-axi to reproduce or verify UI behaviour. Only test files may change.
