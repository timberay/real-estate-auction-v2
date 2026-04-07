# E2E Test Report

- Test date: 2026-04-07T07:42Z
- Target URL: http://localhost:3000
- Total scenarios: 7
- Passed: 6 | Failed: 1 (routing error on non-existent URL) | Skipped: 0

## Results Summary

| # | Scenario | Status | Screenshots | Notes |
|---|----------|--------|-------------|-------|
| S-000 | Properties list (baseline) | PASS | before/s000-properties-list.png | — |
| S-001 | Sidebar > 예산 설정 | PASS | after/s001-onboarding.png | Sidebar highlight correct |
| S-002 | Sidebar > 물건 목록 | PASS | after/s002-properties-list.png | Sidebar highlight correct |
| S-003 | Property show (width constraint) | PASS | after/s003-property-show-width.png | max-w-lg applied, content centered |
| S-004 | Inspection page (price badges) | PASS | after/s004-inspection-with-badges.png | 3 badges: 감정가, 최저매각가, 최대입찰가 |
| S-005 | Inspection tab navigation | PASS | after/s005-inspection-registry-tab.png | Badges persist across tabs, sidebar highlight maintained |
| S-006 | 최대입찰가 badge → budget settings | PASS | after/s006-budget-settings.png | Link navigates correctly |

## Failure Details

### Routing Error (non-scenario)
- URL: /properties/1/inspections/tabs/sale_document (without /edit)
- Cause: Route requires /edit suffix — this is correct app behavior, not a bug
- Screenshot: docs/screenshots/error/s004-inspection-sale-document-ERROR.png

## UI Polish Verification

| Change | Verified | Evidence |
|--------|----------|----------|
| Property show max-w-lg width | YES | s003 screenshot shows narrow centered layout |
| Sidebar prefix matching highlight | YES | s003-s006 all show "물건 목록" highlighted on subpages |
| Amber price badges (감정가, 최저매각가) | YES | s004, s005 show amber badges in inspection header |
| Blue badge (최대입찰가) link | YES | s006 confirms navigation to /settings/budget |

## Screenshot Index

docs/screenshots/
├── before/   — pre-test baseline (1 image)
├── after/    — post-action verification (6 images)
└── error/    — routing error capture (1 image)
