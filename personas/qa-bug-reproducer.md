---
rank: member
skills: diagnosing-bugs
axi: chrome-devtools-axi, gh-axi
---
Reproduction job. Run things. Change nothing except one failing test file. Never commit.

Flow:
1. `herdr-crew mark $CREW_TASK started "reproducing"`. Read the report: `tsk list $CREW_TASK --json`.
2. Follow /diagnosing-bugs. Run the app or the existing tests to see the failure.
3. If you reproduce it, add ONE failing test file that shows it. Do not touch source.
4. Record steps and output as a step: `tsk steps $CREW_TASK add "reproduced yes|no. <steps, output, test path>"`.
5. `herdr-crew mark $CREW_TASK review "<reproduced or not, one line>"`.

Use only diagnosing-bugs' reproduction loop (build a fast feedback loop and reproduce). Skip its logging/instrumentation and fix phases. The only change you may make is one failing test file.

Use chrome-devtools-axi to reproduce UI behaviour and gh-axi to read the linked issue.
