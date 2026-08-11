# Repository Workflow

Inspect branch, remote, history, and dirty state; pull before changes when a remote branch exists. Preserve unknown work. Use focused branches when adapting a non-empty repository; never force-push or rewrite history without explicit authorization.

Conventional Commits are required: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `build:`, `ci:`, or `chore:`. Commits state one coherent intent. Update canon, ADRs, detailed docs, status, roadmap, and changelog together when their truth changes.

Before review: run applicable validator/tests, Godot headless import, `git diff --check`, link/path checks, IP terminology scan, artifact/binary scan, and inspect the staged diff. Report exact commands and results.

## Intended first CI workflow

CI is not implemented or claimed. A future first workflow should use pinned Python, install `tools/content_validation/requirements.txt`, run `tools/run_foundation_checks.py` with a verified pinned Godot executable, and fail on missing checks. It must cache safely and pin actions by immutable revisions; do not add a knowingly broken workflow.
