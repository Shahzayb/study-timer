---
name: memory-bank
description: Read and maintain this repo's Memory Bank (memory-bank/*.md), the compact, decision-grade record of goals, current architecture, progress, and plan history. Use at the start of any non-trivial task, when asked about project state, status, or the next step, when asked to update or prune memory, after a plan is saved, and after an implementation lands.
---

# Memory Bank

The bank lives in `memory-bank/` at the repo root. It is a working set, not a transcript. Its job
is to let a fresh session choose the correct next action quickly.

Boundaries:
- Plans are not part of the bank. They live in `plans/YYYY-MM-DD_short-name.md`. The bank links
  to them by filename.
- `CLAUDE.md` says when to do things. The bank holds project facts. A fact MUST NOT appear in
  both.

## Files, ownership, budgets

| File | Owns | Budget |
| --- | --- | --- |
| `projectbrief.md` | Goal, users, scope, non-goals | 250 words |
| `techContext.md` | Architecture, external contracts, constraints, environment, commands | 3,500 words |
| `progress.md` | Current state, next action, validation gaps, open decisions | 1,500 words |
| `history.md` | Chronological plan index | 300 words per row |

A budget is a limit. Check budgets with `wc -w memory-bank/*.md`. If a new fact would exceed a
budget, replace a stale fact or compress an entry first. MUST NOT add a fifth file to dodge a
limit.

## Reading

- Before a non-trivial task, read `progress.md`, then `projectbrief.md`, then `techContext.md`.
- Read `history.md` when the owner asks where things stand or when the task depends on an earlier
  plan. It is the only file that keeps growing.
- If `memory-bank/` does not exist, bootstrap it first.

## Admission test

Add a line only if all are true:

1. A future session cannot cheaply recover it from code, tests, Git, `CLAUDE.md`, or a linked plan.
2. It changes a future decision, implementation, or validation step.
3. It has one clear owning file and is stated as a fact, constraint, or unresolved decision.

Otherwise leave it out. Test counts, run narration, file inventories, function signatures,
implementation chronology, and generic summaries fail. Link the plan or code location when the
detail may matter later.

## Writing rules

- Each fact has one home. Do not restate a history row in `techContext.md`, a technical contract
  in `progress.md`, or a plan's reasoning anywhere in the bank.
- State an invariant with its consequence. Do not tell the story of finding it. Example: "The API
  returns at most 100 rows per call. Paginate every list request."
- Write verified facts directly. Propose inferences and judgment calls to the owner first.
- Record an unknown as `_Not yet established._`. MUST NOT promote an inference to a fact.
- `techContext.md` holds current contracts only. Delete superseded choices. Their plan and history
  row already record them. Label decided but unbuilt contracts.
- `progress.md` holds actionable, unresolved items only. When an item resolves, promote at most
  one durable constraint to `techContext.md`. Then delete the item.
- Use absolute dates (`YYYY-MM-DD`).
- MUST NOT record secrets, tokens, credentials, or personal data.
- Follow the writing rules in `CLAUDE.md`. The owner may edit these files. Re-read a file before
  editing it.

## History

- `history.md` is a table: `| Date | Plan | Outcome | Status | Enduring constraint |`.
- Status is one of `planned`, `implemented`, `abandoned`, `superseded`.
- The constraint column holds at most one non-obvious lasting rule, or `—`.
- Add a `planned` row when a plan file is saved. When the plan lands or is dropped, edit only that
  row's outcome and status.
- Compact a row that exceeds its budget. Keep its outcome unchanged.

## Update pass

Run an update pass when the owner asks, or after an implementation lands. Update only the files
whose owned facts changed:

1. `progress.md`: the next action and any validation gap.
2. `techContext.md`: a contract that passes the admission test.
3. `history.md`: the row for the plan that landed.

On an explicit update request, review all four files and remove duplication and stale state.
Report only the changed files, one line each: `file: reason`. MUST NOT invent a next task or
strategic direction. Propose it to the owner when it is a judgment call.

## Removal pass

End every update pass with a removal pass. Delete stale, duplicated, superseded, or non-actionable
entries that fail the admission test. Keep current decisions, constraints, and unresolved
validation gaps. Do not add a session summary.

## Bootstrap

Create the four files with these headings. Fill only facts that pass the admission test. Mark
gaps `_Not yet established._`.

- `projectbrief.md`: `# Project Brief`, `## Goal`, `## Users`, `## In scope`, `## Non-goals`
- `techContext.md`: `# Tech Context`, `## Architecture`, `## External contracts`,
  `## Constraints`, `## Environment`, `## Commands`
- `progress.md`: `# Progress`, `## Current state`, `## Next action`, `## Validation gaps`,
  `## Open decisions`
- `history.md`: `# History`, then the table header above
