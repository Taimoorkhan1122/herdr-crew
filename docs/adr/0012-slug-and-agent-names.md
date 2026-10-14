# 0012. Each repo gets a slug from its name and path, and agents get predictable names

- Status: Accepted
- Date: 2026-10-13

## Context

Two repos can share a folder name, such as `client-portal-web` and `client-portal-api` with the same prefix. Worktrees, tabs, and agent names all need a short id for the repo. The id must stay the same across runs, and it must not collide for different repos. Agent names are limited in length, and the Lead and Manager must find each other by name.

## Decision

The slug is the first six characters of the lowercased repo folder name, with any character outside `a-z0-9-` replaced by `-`. It is followed by `-` and four hex characters from the SHA of the repo path. If the slug does not start with a letter, the launcher adds an `x` at the front. `CREW_SLUG` and `CREW_REPO` can override the slug and path. Agent names have the form `<slug>-lead`, `<slug>-manager`, and `<slug>-t<n>-<job>`, such as `my-app-3f9c-t7-driver`. Each name is cut to 32 characters.

## Consequences

- Two repos with the same folder name get different slugs, because their paths differ.
- Names longer than 32 characters are cut, which can shorten the job part. The task number comes before the job, so the `say` queue still finds it.
- The `say` queue reads the task number from the agent name, so the naming form is part of the contract.
- The hash uses `shasum`, which is on macOS. Other systems need it too.
