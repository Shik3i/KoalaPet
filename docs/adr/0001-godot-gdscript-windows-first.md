# ADR 0001: Godot 4, GDScript, Windows-first

**Status:** Accepted — 2026-08-11

## Context

The product needs a lightweight local desktop runtime, strong 2D tooling, scriptable automation, and platform-window access. Windows 10/11 is the first target.

## Decision

Use pinned Godot 4.x with GDScript and isolate Windows desktop integration behind a platform adapter. The current verified development pin is `4.7.1.stable.official.a13da4feb`.

## Consequences

Domain code avoids Windows/UI coupling. Prompt 1 must validate overlay behavior on real Windows; documented APIs are not evidence. Python remains external tooling.

## Rejected alternatives

Custom engine/native UI: excessive foundation cost. Web wrapper: uncertain transparent desktop integration and process overhead. C#: unnecessary dependency for the current team/workflow.

## Revisit triggers

Failed Windows spike, engine support/security issue, or measured performance/tooling blocker.
