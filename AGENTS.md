# Agent Instructions

## Required reading

Before changing behavior, read in order:

1. `docs/PROJECT_CANON.md`
2. `docs/STATUS.md`
3. Accepted records in `docs/adr/`
4. The relevant detailed system documents
5. The nearest nested `AGENTS.md`

Authority order is project canon, accepted ADRs, detailed system documents, roadmap, then historical prompts/task notes. Correct lower-authority contradictions.

## Non-negotiable rules

- Canon before implementation. Update the relevant canon/system document whenever accepted behavior changes; add or supersede an ADR for architectural changes.
- Never silently remove an accepted feature. Later sequencing is not deletion.
- Use neutral domain terms and original content. No third-party monster-franchise names, identifiers, assets, sounds, links, or imitation content.
- Keep domain logic independent of Minimal, Small, and Expanded presentation modes.
- Keep pets, forms, sprites, animations, evolution, moves, items, dungeons, habitats, jobs, starter pools, gates, and localization data-driven.
- Load bundled official content through the same versioned registry and validator as external packs.
- Use stable namespaced IDs and localization keys; never visible names as identifiers.
- Preserve versioned content APIs, saves, migrations, missing-content recovery, and deterministic time from the start.
- Initial mods are JSON and safe media only. No executable mod payloads.
- Assume an AI-first art workflow. Never require the product owner to draw, rig, clean sprites, or operate an art editor.
- Never claim a test, import, screenshot, export, platform behavior, release, or deployment without direct evidence.
- Keep the core local-first and privacy-first. Do not add accounts, tracking, advertising, cloud services, SDKs, or network dependencies without an accepted decision.
- The product owner has final product authority. Record disagreements as proposals or ADR alternatives; do not silently substitute preferences.
- At milestone boundaries update `docs/STATUS.md`, relevant system docs, `docs/ROADMAP.md`, and `CHANGELOG.md`.

## Repository workflow

- Pull before starting when a remote branch exists; inspect branch, remotes, history, and dirty state first.
- Preserve unrelated work. No force pushes or history rewrites.
- Use Conventional Commits. Keep commits scoped and explain validation evidence.
- Run applicable validators, tests, `git diff --check`, link/path checks, and artifact checks before commit.
- Do not commit secrets, caches, `.godot/`, exports, generated temporary previews, or downloaded binaries.
