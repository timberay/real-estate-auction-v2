# Core Principles

Foundational philosophy and non-negotiable rules for all AI agents and developers working on this project.

## Standards

- **DRY**: Eliminate meaningful duplication. Prefer three similar lines over a premature abstraction.
- **Explicit Dependencies**: Make all dependencies clear and avoid hidden side effects.

## "Tidy First" Rule

Separate **Structural Changes** (refactoring) from **Behavioral Changes** (new logic).

- Tidy First applies **before starting a new TDD cycle** — if the code is hard to change, tidy it first and commit, then begin Red-Green-Refactor.
- The **Refactor step inside TDD** (after Green) is part of the current cycle — commit it together with or immediately after Green. It does not require a separate Tidy First commit.
- **Rails Example**: Before adding a new feature to a complex `Controller#update`, refactor long private methods into a dedicated `Service Object` or `Domain Model`. Commit the tidying separately, then begin the TDD cycle for the new feature.

## Documentation Rules

### File Structure

- **Root**: Only `README.md`, `CLAUDE.md` — no other MD files
- **`docs/standards/`**: AI agent and development standards (this directory)
- **`docs/superpowers/`**: Project documentation managed by superpowers plugin
  - `specs/` — Design specs from brainstorming sessions
  - `plans/` — Implementation plans for feature work
  - `archive/` — Superseded specs/plans kept for historical reference; do not edit
- **`docs/operations/`**: Runbooks for production-affecting procedures (OAuth setup, branch protection, CSP enforcement, backup, etc.). Each runbook is one playbook for one operator action.
- **`docs/decisions/`**: Decision records (ADR-style). Filename: `<YYYY-MM-DD>-<short-id>-<title>.md`. Captures the *why* behind a decision; do not rewrite history — append a follow-up record instead.
- **`docs/audits/`**: One-off audit reports (UX, security, accessibility). Dated and immutable once filed.
- **`docs/references/`**: Persistent reference material (e.g., parsed external docs, regulation excerpts) — keep only what is actually consulted
- **`docs/screenshots/`**: Manual and README screenshots — checked in, treated as content, not test artifacts
- **`db/seeds/`**: Seed data JSON files. The seed loader (`db/seeds.rb`) is the source of truth for which files are loaded.

### Writing Principles

1. **Single Source of Truth** — Never duplicate information across files. If it exists in one place, reference it, don't copy it.
2. **Reference direction** — Specs reference other specs as peers. Plans reference specs, never the reverse. No "update X when Y changes" obligations.
3. **Record decisions, not process** — Intermediate analysis (agent reports, working copies) should not be committed. Only final decisions belong in docs.
4. **Dead docs are worse than no docs** — Review and update or remove documentation that is outdated. Once code is implemented, the code is the SSOT, not the plan.
5. **Plans as handoff artifacts** — For multi-session work, use implementation plans (`docs/superpowers/plans/`) as the durable handoff artifact between sessions.

### Writing AI Agent Instructions

- Write imperatives: "Use Korean for explanations" not "Korean should be used"
- Be explicit about exceptions: "Use English for code, markdown files, YAML, and commit messages"
- Reference files by path: "See `docs/standards/STACK.md`" not "see the architecture doc"
- Use concrete examples over abstract descriptions
- Don't repeat the same instruction in multiple files (Single Source of Truth)
- Don't use vague qualifiers: "try to", "if possible", "generally"
- Don't embed ephemeral information (dates, sprint numbers, ticket IDs) in persistent instructions

### Before Creating a New MD File

- Can this be added to an existing doc? → Add it there
- Will this be referenced after implementation? → If no, don't create it
- Does this require syncing with another doc? → If yes, redesign the structure
