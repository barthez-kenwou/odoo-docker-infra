# 1. Record architecture decisions

## Status
Accepted

## Context
This lab makes a lot of non-obvious infrastructure choices (why Compose and
not Kubernetes as the primary target, why SOPS and not Vault, why session
pooling and not transaction pooling in PgBouncer...). Six months from now,
"why did I do it this way" is a real question, for me or for anyone else
reading this repo.

## Decision
Use lightweight Architecture Decision Records (ADRs), one Markdown file per
significant decision, following the format popularized by Michael Nygard.
Numbered sequentially, never renumbered or deleted — a superseded decision
gets a new ADR that says so and links back.

## Consequences
- Every non-obvious infrastructure choice in this repo should have a
  corresponding ADR, or a comment pointing to one.
- ADRs are immutable once accepted; if a decision changes, write a new ADR
  and mark the old one "Superseded by ADR-00xx".
