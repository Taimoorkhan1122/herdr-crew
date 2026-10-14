# 0010. Each persona declares its skills, and install-skills installs missing ones only after asking

- Status: Accepted
- Date: 2026-10-13

## Context

A persona depends on skills such as `tdd` or `code-review`. If a skill is missing, the persona runs without its method, and nothing says so. Skills come from several places: GitHub repos through `npx skills`, Claude plugins, and some with no known source. Installing them silently would change the user's machine without consent.

## Decision

Each persona lists its skills in a `skills:` line in its frontmatter. The launcher warns when a user skill is not installed, and it does not check plugin skills (those with a colon in the name). `skills.sources` records where each skill comes from, in one of three forms: `<skill> <owner/repo>`, `<skill> plugin <plugin@marketplace>`, or `<skill> UNKNOWN`. `bin/install-skills` reads the required list from the personas and from `skills.sources`. It checks each item and reports a status such as `ok`, `MISSING`, `BLOCKED`, `installed`, or `skipped`. With `--check` it changes nothing and exits 1 when anything is missing. With no flags it shows the command for each missing item and asks `[y/N]`. The default is No, and with no terminal the answer is No. `-y` accepts every prompt. Skills are chosen per persona, and each list is checked by hand. Inspectors get no skill that edits code, so `security-audit-hardening` was removed.

## Consequences

- Nothing is installed without the user's answer, unless the user passes `-y`.
- Five skills have source `UNKNOWN`. `install-skills` cannot fetch them, so the user must install them by hand.
- A skill added to a persona must also be added to `skills.sources`, or install-skills cannot fetch it.
- Persona skills are audited by hand. No check enforces rank safety.
