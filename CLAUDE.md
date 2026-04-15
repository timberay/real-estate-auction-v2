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

## Task → Required Reading

Before starting work, read the documents mapped to your task type:

| Task Type | Must Read |
|-----------|-----------|
| Feature implementation | RULES, STACK |
| UI / Frontend / Styling | STACK (UI/Frontend Rules, Hotwire), QUALITY (Accessibility) |
| Bug fix / Debugging | QUALITY |
| Testing | QUALITY (Testing Strategy) |
| API integration | STACK (Adapter Pattern), TOOLS |
| Database / Migration | STACK (Database & Infrastructure), TOOLS (Database commands) |
| Deployment / DevOps | STACK (Deployment), TOOLS (Deployment commands) |
| Code review / PR | QUALITY (Code Review Checklist) |
