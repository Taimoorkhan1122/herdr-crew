# Maintainability review

Date: 2026-10-14. Independent read-only review requested by the user. Findings describe inspected source; no runtime fixes are implemented. P1 means high priority; P2 means medium priority.

## Findings

1. **P1: restart can lose the handoff.** `bin/crew:534-538` gives the resumed agent a handoff path, starts it, then renames the file. The agent can attempt its read after the rename. Archive before launch and reference the archive; retain it across retries. `test/dry-run.sh:296-303` currently accepts both the obsolete prompt path and the rename. Add a check that the referenced file exists after restart.
2. **P2: repeated testing can use obsolete source.** `bin/crew:333-345` creates a test branch from pair once and reuses it after the pair branch advances. Detect the stale base and refuse with update instructions that preserve test commits and local changes. Extend `test/worktrees.sh:36-39` with pair advancement between launches.
3. **P2: review reuse skips repository ownership checks.** `bin/crew:346-350` checks out a branch in any existing review directory. Validate the common Git directory and exact worktree root before checkout; cover an unrelated repository containing the same branch name. Consider the same exact-root check for the adjacent reuse path.
4. **P2: failed status reads look like departed agents.** `bin/crew:94` hides lookup failures; `bin/crew:463-489` then emits gone and the Lead can request a restart. Preserve the previous snapshot on transient failure and establish confirmed absence before emitting gone. Test a failed poll between successful polls.
5. **P2: required skills have competing declarations.** The Manager requires caveman:caveman in prose, but `bin/install-skills:28-35,159-165` discovers frontmatter/manifest requirements and misses it. README documents manual setup. Declare the dependency consistently with a verified source and ensure rank skill requirements reach briefs; test an absent required rank skill with a disposable fixture.

## KISS recommendation

The Bash/configuration design fits the current project. Repair lifecycle, ownership, and source-version correctness with focused regression cases. This review found no justification for a framework or broad module split.

## Evidence and limits

The reviewer read all three executable scripts, both test scripts, role/persona/team definitions, source manifest, README/SKILL instructions, and relevant architecture/status docs. The coordinating agent inspected the cited launcher and test paths. The review did not execute live Claude/Herdr behavior or clean-machine installation; ShellCheck was unavailable. Earlier passing suites do not cover these missing invariants. No fixes, dependency installs, commits, or publication were performed for this audit.
