# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Non-Negotiable Rules

- **Korean** for explanations and conversation; **English** for code, markdown, YAML, commit messages
- **TDD**: Red-Green-Refactor for every task. Write a failing test first.
- **Tidy First**: NEVER mix structural changes (refactoring) and behavioral changes (new logic) in a single commit
- **Small Commits**: Commit every time a test passes or a refactoring is done

## Standards Reference

Detailed standards are in `docs/standards/`. **Read the relevant document(s) before starting work.**

| Document | Description |
|----------|-------------|
| [RULES.md](docs/standards/RULES.md) | DRY, Tidy First, documentation rules, AI instruction writing guidelines |
| [STACK.md](docs/standards/STACK.md) | Project overview, tech stack, patterns, Hotwire, deployment, i18n, Rails 8 specifics |
| [TOOLS.md](docs/standards/TOOLS.md) | Dev commands, environment config, API tools |
| [QUALITY.md](docs/standards/QUALITY.md) | Testing, security, accessibility, performance, code review |

## Pre-commit Failure Recovery

When a pre-commit hook (rubocop, test, etc.) fails, fix it yourself and retry — do not stop and ask the user.

- **Rubocop violation**: Run `bin/rubocop -a` to auto-fix, then re-stage and re-commit
- **Test failure**: Diagnose the failing test, fix the code, verify with `bin/rails test`, then re-commit
- **Multiple issues**: Fix rubocop first, then tests, then re-commit

## Pipeline Phases (4-Layer Design Separation)

For new feature work, follow the 4-phase design separation. Do NOT skip phases. A `UserPromptSubmit` hook will remind you when a feature request is detected.

### Phase 1 — Product Decision
- **Skill**: `/office-hours` (gstack)
- **Answers**: WHAT + WHY + WHO
- **Output**: `~/.gstack/projects/<slug>/designs/<feature>.md`
- **Forbidden**: tech stack, architecture, code

### Phase 2 — System Architecture
- **Skill**: `/plan-eng-review` (gstack)
- **Answers**: data flow, failure modes, module boundaries
- **Output**: `~/.gstack/projects/<slug>/designs/<feature>-eng-review.md`
- **Forbidden**: file-level plan, task IDs, code snippets

### Phase 3 — Technical Design
- **Skill**: `/superpowers:brainstorming`
- **Answers**: Rails patterns, concurrency, caching, test strategy
- **Input**: Phase 1 + Phase 2 docs (do not re-debate)
- **Output**: `docs/superpowers/specs/<date>-<feature>-tech-design.md`
- **Forbidden**: product re-debate, system boundary re-debate

### Phase 4 — Task Breakdown
- **Skill**: `/superpowers:writing-plans`
- **Input**: Phase 3 doc (primary), Phase 1/2 (reference)
- **Output**: `docs/superpowers/plans/<date>-<feature>-plan.md`

### Phase 5 — Execute
- **Skill**: `/superpowers:executing-plans` + `test-driven-development`

### Phase 6 — Review / Ship / Deploy
- **Skills**: `/review`, `/ship`, `/land-and-deploy`, `/document-release`

### Phase continuation rules
- If the user explicitly continues an in-progress phase (e.g., "Phase 3 계속", "플랜 수정", 이미 열려있는 design doc 편집), proceed without re-checking earlier phases.
- If the user explicitly overrides ("간단한 버그 수정이니 phase 건너뛰어"), confirm the task truly doesn't need the pipeline, then proceed.
- For bug fixes, refactors, and small tweaks, the pipeline does not apply. Use your judgment.

## Task → Required Reading

Before starting work, read the documents mapped to your task type:

| Task Type | Must Read |
|-----------|-----------|
| Feature implementation | RULES, STACK |
| UI / Frontend / Styling | STACK (UI/Frontend Rules, Hotwire), QUALITY (Accessibility) |
| Bug fix / Debugging | QUALITY |
| Testing | QUALITY (Testing Strategy) |
| API integration | STACK (Adapter Pattern), TOOLS |
| Authentication / OAuth | STACK (Authentication), QUALITY (Security) |
| Database / Migration | STACK (Database & Infrastructure), TOOLS (Database commands) |
| Deployment / DevOps | STACK (Deployment), TOOLS (Deployment commands) |
| Code review / PR | QUALITY (Code Review Checklist) |
