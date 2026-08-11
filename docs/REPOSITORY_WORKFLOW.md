# Repository Workflow

Inspect branch, remote, history, and dirty state; pull before changes when a remote branch exists. Preserve unknown work. Use focused branches when adapting a non-empty repository; never force-push or rewrite history without explicit authorization.

Conventional Commits are required: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `build:`, `ci:`, or `chore:`. Commits state one coherent intent. Update canon, ADRs, detailed docs, status, roadmap, and changelog together when their truth changes.

Before review: run applicable validator/tests, Godot headless import, `git diff --check`, link/path checks, IP terminology scan, artifact/binary scan, and inspect the staged diff. Report exact commands and results.

## First intended CI workflow

Deferred until the foundation commit. The first workflow should use pinned Python, install `tools/content_validation/requirements.txt`, run the content validator, verify Markdown links/local paths, run `git diff --check` against the PR diff, and headlessly import the pinned Godot project using a verified runner acquisition method. It must cache safely, pin actions by immutable revisions, and fail on missing checks; do not add a knowingly broken workflow.
