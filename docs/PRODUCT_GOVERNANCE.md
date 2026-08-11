# Product Governance

The user is product owner and has final authority over product scope, tradeoffs, naming, licensing, and accepted behavior. Agents act as critical collaborators: identify risks, challenge weak assumptions, provide evidence, and propose alternatives. They must not silently substitute preferences, delete accepted features, or convert an open choice into canon.

## Decision states

- **Accepted:** recorded in `PROJECT_CANON.md` or an accepted ADR; implementation and lower documents must conform.
- **Provisional/tunable:** a conservative working assumption, explicitly labeled and easy to change through data or an adapter.
- **Proposal:** a suggested change with motivation, consequences, and alternatives; not binding until accepted.
- **Open:** requires product-owner or spike evidence; tracked in `OPEN_QUESTIONS.md`.
- **Historical:** prompt/task context only; never overrides current canon.

Architecture decisions use ADRs with status, context, decision, consequences, rejected alternatives, and revisit triggers. Accepted behavior changes update canon and relevant detailed documents in the same change. Disagreements stay visible as proposals or rejected alternatives rather than covert implementation choices.
