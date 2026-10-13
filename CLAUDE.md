# CLAUDE.md

## What this file is

This file is the workflow guide for this repo. It says **when** to do something. Technical facts
(stack, layout, commands, constraints) live in `memory-bank/`.

The owner drives the workflow. Nothing here runs automatically. Each section describes what is
expected once the owner asks for it. If a step seems warranted and the owner has not asked, say
so in one sentence and let the owner decide.

## 1. Before any task

`memory-bank/` is the only record of previous work. Nothing about the project loads
automatically.

- When a task touches something unfamiliar, read `memory-bank/` first.
- When the owner asks where things stand, read all of `memory-bank/`, including `history.md`.
- Check the memory bank before asking the owner a question. Do not answer from assumption.
- When a choice changes behavior the owner will notice, ask. Batch the questions and mark a
  recommended option.

## 2. Deciding whether a task needs a plan

| Needs a plan | Doesn't need a plan |
| --- | --- |
| Touches more than one file | Single-file fix |
| Adds a dependency | Rename |
| Sets a new pattern | Config tweak |

When a task needs a plan:

1. Write it to `plans/YYYY-MM-DD_short-name.md` right after the owner approves it and before
   writing any code. Plan mode cannot write files, so this is a separate step.
2. Add a `planned` row for it in `memory-bank/history.md`.

## 3. Implementing a plan

- Implementation MUST NOT start until the owner explicitly approves it.
- Follow the plan as written.
- If the work needs something the plan does not cover, stop and tell the owner. Do not re-plan
  mid-implementation.

## 4. After something lands

Once work finishes or a decision is made, `memory-bank/` is out of date. Update it with the
`memory-bank` skill.

- Write verified facts directly.
- Propose judgment calls to the owner first. Do not write them unilaterally.
- When an implementation finishes, set its row in `memory-bank/history.md` to `implemented`.

## Where things live

- `memory-bank/` holds current state, architecture, and technical context. It is the single
  source of truth for project facts. Do not duplicate them here or in a harness-level memory
  directory. A fact stored twice drifts.
- `plans/` holds one dated file per feature or task. Each file describes intent.
- Plans and the memory bank link by filename. Do not copy content between them.
- The `memory-bank` skill defines what belongs in each memory bank file.

## Hard rules

### Process

- Run `swift format --in-place --recursive Sources Tests make-icon.swift Package.swift` and
  `swift format lint --strict --recursive Sources Tests make-icon.swift Package.swift` before
  marking a task done.
- Commits and PRs MUST NOT contain `Co-Authored-By` lines or any other watermark.
- Commit each chunk of work as you go on any branch other than `main`.
- Use conventional commit messages. The subject is imperative. Add a body only for a fact the
  diff cannot show.

### Data and secrets

- The owner's Notion holds live personal data. Create, edit, or delete Notion rows only with
  explicit permission. This includes test commits made while verifying the app.
- MUST NOT ask for, print, log, or commit the Notion API key.

### Code style

- Default to the simplest construction. Prefer a plain function or plain file.
- Comments MUST earn their place and stay under 150 characters. A comment MAY point to a
  `plans/` file to explain why code is built a certain way.
- Search the project before creating a helper, utility, service layer, or view. Extend an
  existing one if it can absorb the logic.
- Prefer a clean conditional path or an extended parameter in an existing file over a new
  wrapper type.
- Ask before adding any package or dependency. Search the project for an existing solution first.

### Writing

- Use short sentences with a clear subject, verb, and object. Avoid cleft sentences, contrastive
  appositives, appended glosses, and trailing clauses.
- Use RFC 2119 keywords (MUST, SHOULD, MAY) for obligations.
- The owner may edit documents, especially markdown. Re-read a file before editing it.
- Markdown documents MUST NOT reference conversations or threads a reader would not know about.
