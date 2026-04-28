# Development Workflow

## Pipeline Phases

New feature work flows through six phases: four design phases (1–4) that separate product, architecture, technical design, and task breakdown, followed by execution (5) and ship (6). Do NOT skip phases. A `UserPromptSubmit` hook reminds you when a feature request is detected.

### Design phases (1–4)

> **Output directories**: Phase 1 and 2 are gstack skills; their outputs live under `~/.gstack/projects/<slug>/designs/` (per-developer, not committed). Phase 3 and 4 are superpowers skills; their outputs live in-repo under `docs/superpowers/` and ARE committed.

#### Phase 1 — Product Decision
- **Skill**: `/office-hours` (gstack)
- **Answers**: WHAT + WHY + WHO
- **Output**: `~/.gstack/projects/<slug>/designs/<feature>.md`
- **Forbidden**: tech stack, architecture, code

#### Phase 2 — System Architecture
- **Skill**: `/plan-eng-review` (gstack)
- **Answers**: data flow, failure modes, module boundaries
- **Output**: `~/.gstack/projects/<slug>/designs/<feature>-eng-review.md`
- **Forbidden**: file-level plan, task IDs, code snippets

#### Phase 3 — Technical Design
- **Skill**: `/superpowers:brainstorming`
- **Answers**: Rails patterns, concurrency, caching, test strategy
- **Input**: Phase 1 + Phase 2 docs (do not re-debate)
- **Output**: `docs/superpowers/specs/<YYYY-MM-DD>-<feature>-design.md`
- **Forbidden**: product re-debate, system boundary re-debate

#### Phase 4 — Task Breakdown
- **Skill**: `/superpowers:writing-plans`
- **Input**: Phase 3 doc (primary), Phase 1/2 (reference)
- **Output**: `docs/superpowers/plans/<YYYY-MM-DD>-<feature>.md`

### Execution phases (5–6)

#### Phase 5 — Execute
- **Skills**: `/superpowers:executing-plans` (drives the plan) + `/superpowers:test-driven-development` (per task)
- **Input**: Phase 4 plan
- **Forbidden**: implementing tasks not in the plan; if scope changes, return to Phase 4 and update the plan first

#### Phase 6 — Review → Ship → Deploy → Document
Run in this order; each gates the next:

1. `/review` — pre-landing diff review against base branch
2. `/ship` — run tests, bump version, create PR
3. `/land-and-deploy` — merge, deploy, verify production health
4. `/document-release` — sync README / CLAUDE.md / standards with what shipped

### Phase continuation rules
- If the user explicitly continues an in-progress phase (e.g., "Phase 3 계속", "플랜 수정", 이미 열려있는 design doc 편집), proceed without re-checking earlier phases.
- If the user explicitly overrides ("간단한 버그 수정이니 phase 건너뛰어"), confirm the task truly doesn't need the pipeline, then proceed.
- For bug fixes, refactors, and small tweaks, the pipeline does not apply. Use your judgment.
