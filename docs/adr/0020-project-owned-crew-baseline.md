# 0020. Bootstrap project-owned crew configuration

- Status: Superseded in part by 0021 (specification-only agents; project ownership remains accepted)
- Date: 2026-10-29

## Context

The installed package currently owns rank and persona definitions, while target projects can override runtime assignments through `.herdr-crew.json`. The user wants a simpler, plug-and-play skill that supports project-specific agents, including extending existing agents and creating new ones.

## Decision

The herdr-crew skill installs a baseline into the target project's `.herdr-crew/` directory. That project owns subsequent configuration and agent customization. The baseline includes agent definitions organized under `agents/`, with an individual `Persona.md` and `memory.md` as requested by the user. Users can extend existing agents or create new agents within their project.

This records the ownership boundary only. The extension mechanism, memory contents and instance isolation, update behavior, runtime scope, hook contracts, and migration from current configuration remain open. This decision does not approve an implementation plan or replace the current built behavior described by ADR 0018.

## Consequences

Projects can evolve their crew without changing the installed skill's bundled definitions. Installation and later updates must account for project-owned changes; their precise preservation and upgrade rules still need agreement. Runtime callers currently tied to bundled paths must be addressed in the eventual design.
