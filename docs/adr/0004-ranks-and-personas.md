# 0004. Ranks set permissions, and personas set the job or the domain

- Status: Accepted
- Date: 2026-10-13

## Context

The first build had eight job roles. Each role mixed two things: what the agent may do, and what work it does. Adding a new kind of work meant a new role with its own permissions. The user suggested an airline-crew model, where rank decides authority and a separate role decides the job.

## Decision

There are four ranks in `ranks/`: `lead`, `manager`, `member`, and `inspector`. A rank sets the tools and permissions, and it sets the model and effort. Personas live in `personas/`. A job persona has a `rank:` line, such as `driver` (member) or `navigator` (inspector). It fills one team slot. A domain persona has no `rank:` line, such as `nestjs-expert` or `security-paranoid`. It can be added to any job. If no domain persona is given, `pragmatic-senior` is used. A spec has the form `rank@persona+persona`, or a bare job persona, which takes its rank from the persona. `parse_spec` checks every name before anything starts, and it rejects a job persona with the wrong rank.

## Consequences

- New work needs only a persona file and a team entry, not a new permission set.
- Permissions are defined in one place per rank, so they are easy to audit.
- A job persona can belong to only one rank, so a combined spec must match its rank.
- The Lead and Manager have no job persona, so `lead` is the only spec with no job.
