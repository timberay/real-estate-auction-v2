# F06. Eviction Scenario Guide — Design Spec

## 1. Overview

### Purpose

Provide an eviction (명도) guidance system for auction property buyers. The feature operates as an independent section (`/eviction-guide`) with two tabs: Guide (educational step-by-step reference) and Simulator (interactive yes/no flow producing a personalized eviction path).

### Design Principles

- **Education first:** Users learn the eviction process in the Guide tab before simulating their specific scenario
- **Simulation-driven:** The Simulator is the core value — interactive yes/no flow produces a personalized eviction path with difficulty assessment
- **Property-linked (optional):** When connected to an F02-analyzed property, pre-fills simulator with AI analysis results requiring user confirmation
- **Seed-data driven:** All content (steps, branches, questions) managed via JSON seed files for code-free content updates
- **Professional deference:** All pages include disclaimer that execution requires professional consultation (SRS "Respect for Fieldwork" principle)
- **Inline legal context:** Legal references are embedded within each step card, not in a separate section — users encounter legal basis in context, not in isolation

### References

- `docs/references/ref-001.md` — Eviction process overview and negotiation strategies
- `docs/references/ref-002.md` — Web page structure proposal
- `docs/references/ref-003.md` — Case-by-case eviction scenarios (delivery order, opposing power tenants, lien rights, occupant substitution, absent occupants)
- `docs/references/ref-004.md` — Legal source material (statutes, court decisions, practitioner guidance)
- `docs/references/ref-005.md` — Information architecture with detailed section specs
- `docs/references/ref-006.md` — Complete workflow: S1–S15 main flow + B1–B11 branch flow

### Scope Exclusions

- D-Day calculator (date-based deadline tracking)
- Cost simulator (eviction cost estimation, moving cost calculator)
- Document auto-generation (certified mail, delivery order applications)
- Automated contact features
- Standalone legal knowledge base tab (legal info is inline within step cards)

---

## 2. Architecture

### Relationship to Existing Features

```
/eviction-guide (independent section)
  ├── Tab 1: Guide (step-by-step reference)
  │     └── S1–S15 accordion cards with B1–B11 inline + legal basis inline
  └── Tab 2: Simulator (interactive yes/no)
        └── Optional: property linkage via /properties/:id

F02 Property Inspection ──(data feed)──► Simulator (pre-fill)
  └── RightsAnalysisReport
  └── InspectionResults
```

- Fully independent from F02 tab structure
- F02 data flows one-way into the simulator as pre-fill values
- No F02 dependency required — simulator works standalone
- Cross-links: F02 grade tab → "View eviction scenario" link; Guide tab → Simulator CTA

### Data Lifecycle

| Mode | Storage | Behavior |
|---|---|---|
| Property-linked | DB (`eviction_simulations` table) | Persisted, resumable, property FK set |
| Standalone | Rails session (cookie-based) | Volatile, cleared on session expiry or browser close. Answers stored in `session[:eviction_simulation]` hash. No DB record created. |

---

## 3. Data Model

### Seed Data Models (3 tables total)

#### `eviction_steps` — Main Flow S1–S15 + Branches B1–B11 (unified)

| Column | Type | Description |
|---|---|---|
| code | string (unique) | `S1`–`S15`, `B1`–`B11` |
| step_type | string (enum) | `main` / `branch` |
| name | string | Step name (Korean) |
| description | text | Why this step is necessary |
| completion_condition | text (nullable) | Yes condition → proceed (main only) |
| failure_condition | text (nullable) | No condition → branch (main only) |
| required_documents | json | Document list array |
| estimated_duration | string | e.g., "1~3개월" |
| estimated_cost | string (nullable) | e.g., "100~300만원" |
| legal_basis | json | Inline legal references `[{"title": "민사집행법 제136조", "summary": "...", "url": "..."}]` |
| position | integer | Display order |
| next_step_code | string (nullable) | Next main step code (main only) |
| branch_codes | json (nullable) | Branch codes triggered on failure (main only) |
| trigger_step_code | string (nullable) | Which main step triggers this branch (branch only) |
| problem_summary | text (nullable) | Situation summary (branch only) |
| root_cause | text (nullable) | Root cause explanation (branch only) |
| action_steps | json (nullable) | Ordered countermeasure steps array (branch only) |
| return_step_code | string (nullable) | Main step to return to after resolution (branch only) |

#### `eviction_simulator_questions` — Simulator Questions

| Column | Type | Description |
|---|---|---|
| code | string (unique) | `Q1`, `Q2`, ... |
| phase | string | `summary` (S1–S4) or `detail` (S5–S15) |
| step_code | string | Related step code |
| question | text | Question text (Korean) |
| help_text | text | Supplementary explanation |
| yes_next_code | string | Next question on yes |
| no_next_code | string | Next question on no (may enter branch) |
| f02_field_mapping | string (nullable) | F02 data field path for auto-fill |
| difficulty_impact | string (nullable) | Impact on difficulty assessment |

### Runtime Model

#### `eviction_simulations` — User Simulation Results

| Column | Type | Description |
|---|---|---|
| property_id | references (nullable) | FK to property (null for standalone) |
| answers | json | `{"Q1": true, "Q2": false, ...}` |
| result_path | json | Derived eviction path (step + branch code array) |
| difficulty_level | string | `high` / `medium` / `low` |
| completed | boolean | Whether simulation is complete |

---

## 4. Seed Data Files

Two JSON files following the existing `db/seeds/` pattern:

| File | Content | Approximate Items |
|---|---|---|
| `db/seeds/eviction_steps.json` | S1–S15 steps + B1–B11 branches | 26 items |
| `db/seeds/eviction_simulator_questions.json` | Simulator question flow | ~25–30 questions |

### Seed Content Source Mapping

| Seed Content | Primary Reference Source |
|---|---|
| S1–S15 step definitions | ref-006 Section 1 (Main Workflow table) |
| B1–B11 branch definitions | ref-006 Section 2 (Branch Flow table) |
| Legal basis per step | ref-004 (statutes, case law, practitioner guidance) |
| Simulator questions | Derived from ref-006 completion/failure conditions |
| Help text and practical tips | ref-001 (overview), ref-003 (case scenarios) |

---

## 5. Page Structure & Routing

### Routes

```ruby
# config/routes.rb
resources :eviction_guide, only: [] do
  collection do
    get :guide        # Tab 1: Guide
    get :simulator    # Tab 2: Simulator
  end
end

namespace :eviction_guide do
  resource :simulation, only: [:create, :update, :show]
  get "simulator/question/:code", to: "simulator#question", as: :simulator_question
  get "steps/:code", to: "steps#show", as: :step_detail
  get "branches/:code", to: "branches#show", as: :branch_detail
end
```

### Controllers

```
app/controllers/
  eviction_guide_controller.rb          # 2 tab main actions (guide, simulator)
  eviction_guide/
    simulations_controller.rb           # Simulation CRUD
    simulator_controller.rb             # Question-by-question Turbo Frame responses
    steps_controller.rb                 # Step detail (Turbo Frame)
    branches_controller.rb              # Branch detail (Turbo Frame)
```

### Views

```
app/views/eviction_guide/
  guide.html.erb                        # Tab 1: Accordion step cards
  simulator.html.erb                    # Tab 2: Simulator main
  simulator/
    _question.html.erb                  # Individual question (Turbo Frame)
    _result.html.erb                    # Simulation result
    _property_selector.html.erb         # Property selection UI
  steps/
    show.html.erb                       # Step detail (Turbo Frame)
  branches/
    show.html.erb                       # Branch detail (Turbo Frame)
```

### ViewComponents

```
app/components/eviction_guide/
  tab_navigation_component.rb           # 2-tab navigation
  step_card_component.rb                # Step card (accordion, shared for main + branch)
  simulator_question_component.rb       # Yes/no question card
  simulator_result_component.rb         # Simulation result summary
  f02_prefill_component.rb              # F02 auto-fill confirmation UI
  difficulty_badge_component.rb         # Difficulty badge (high/medium/low)
  legal_inline_component.rb             # Legal basis inline display (details/summary)
```

### Stimulus Controllers

```
app/javascript/controllers/
  accordion_controller.js               # Guide tab accordion open/close
  simulator_controller.js               # Simulator state management (question flow, answer tracking)
```

### Turbo Frame Strategy

| Interaction | Frame ID | Content |
|---|---|---|
| Simulator question transition | `simulator_question` | Next question card |
| Guide accordion | N/A (client-side) | Stimulus toggle, no server request |
| Tab switching | Turbo Drive | Full tab content replacement |

---

## 6. Tab Details

### Tab 1 — Guide (명도 가이드)

**Layout:** Vertical accordion card list

**Top section:**
- Overview box: definition of eviction, why it matters, typical duration ranges
- Simulator CTA banner: "내 물건의 명도 시나리오가 궁금하신가요?" → link to Tab 2

**Accordion cards (S1–S15):**

Each card has two states:

*Collapsed:*
- Step code badge (color-coded) + step name + estimated duration
- Click to expand

*Expanded:*
- Description: why this step is necessary
- Required documents (list)
- Estimated cost (if applicable)
- Completion condition (green) and failure condition (red)
- Branch cards (B-series): inline within the parent step card, warning-colored, nested accordion
  - Branch name + problem summary
  - Expand to show: root cause, action steps (ordered list), return step indicator, additional duration
- Legal basis: `<details>` element at card bottom
  - Each legal item: title, summary text, external URL link (법제처/대법원)

**Bottom:** Disclaimer footer

### Tab 2 — Simulator (명도 시뮬레이터)

**Entry Screen:**
- Two cards: "내 물건으로 시뮬레이션" / "직접 입력으로 시뮬레이션"
- Property selector: dropdown of user's analyzed properties
- Guide reverse link: "명도 절차가 처음이라면 명도 가이드를 먼저 읽어보세요"

**F02 Data Confirmation (property-linked only):**
- Lists pre-filled values from RightsAnalysisReport / InspectionResults
- Each item: AI badge + question + yes/no toggle (pre-selected) + source data snippet
- "확인 완료 → 시뮬레이션 시작" button

**Phase 1 — S1–S4 Summary Check:**
- 4 quick yes/no questions (one per step)
- Progress pills showing S1–S4
- Property-linked: auto-completed with gray styling, editable on click
- "No" answer: shows brief guidance inline, does not block progression

**Phase 2 — S5–S15 Detailed Simulation:**
- One question at a time via Turbo Frame replacement
- Progress bar showing percentage
- Each question card:
  - Question text + help text
  - Yes button (green border) → next main step question
  - No button (red border) → branch countermeasure card inline
  - Related legal basis links (inline, from step's `legal_basis` field)
  - Expandable "상세 안내" accordion
- Branch entry: shows branch card inline with action steps, then "대책 확인 → 다음 단계" button routes to the return step's question

**Result Screen:**
- Difficulty badge (high/medium/low)
- Visual path: ordered list of traversed steps + branches with status badges (완료/필요/분기)
- Summary stats: total steps, branch entries count
- Disclaimer: "이 결과는 시뮬레이션이며, 실제 명도 작업은 반드시 법률 전문가와 상담 후 진행하세요."

**Difficulty Assessment Logic:**
- **High:** Any branch from B1 (deposit assumption risk), B2 (lien), B4 (occupant substitution), B6 (deadline missed)
- **Medium:** Branches B3, B5, B7, B8, B9
- **Low:** No branches entered, or only B10/B11 (post-completion issues)

---

## 7. F02 Data Integration

### Service Object: `EvictionGuide::F02DataExtractor`

Extracts relevant data from a property's F02 analysis results for simulator pre-fill.

**Input:** `Property` instance with associated `RightsAnalysisReport` and `InspectionResult` records

**Output:** Hash of question codes → pre-fill values with source descriptions

| Simulator Question | F02 Data Source | Extraction Logic |
|---|---|---|
| Opposing power tenant exists | `RightsAnalysisReport#effective_tenants` | `any? { \|t\| t["opposing_power"] }` |
| Dividend requested | `RightsAnalysisReport#report_data` | `dig("tenants", *, "dividend_requested")` |
| Lien (유치권) claim exists | `InspectionResult` | `find_by(inspection_item_code: "rights-020").has_risk` |
| Gratuitous residence doc | `InspectionResult` | `find_by(inspection_item_code: "inspect-005").has_risk` |
| Occupant type | `RightsAnalysisReport#report_data` | `dig("occupant_type")` |
| Small-sum tenant | `RightsAnalysisReport#effective_tenants` | `any? { \|t\| t["has_priority_repayment"] }` |

**Fallback:** When a mapped field is missing or null, the question is marked as "미확인" and the user must answer manually.

---

## 8. Cross-Linking Strategy

| From | To | Mechanism |
|---|---|---|
| Guide step card → Simulator | Tab 2 with step context | CTA banner + per-step "시뮬레이터에서 확인" link |
| Simulator → Guide | Tab 1 with anchor | "명도 가이드에서 자세히 보기" link in question help text |
| Simulator branch → Guide branch | Tab 1 step anchor | Branch card "가이드에서 상세 보기" link |
| F02 grade tab → Eviction guide | `/eviction-guide/simulator?property_id=:id` | "명도 시나리오 보기" link |

---

## 9. Global Elements

| Element | Implementation |
|---|---|
| Disclaimer | Fixed footer on both tabs: "본 정보는 일반 정보 제공 목적이며, 개별 사안은 변호사·법무사 상담이 필요합니다." |
| Source attribution | Legal basis items include external URL links (법제처, 대법원) |
| Professional referral CTA | Bottom of simulator result: "이 케이스 전문가 상담 받기" (placeholder for future integration) |

---

## 10. Implementation Summary

| Metric | Count |
|---|---|
| DB tables | 3 (eviction_steps, eviction_simulator_questions, eviction_simulations) |
| Seed files | 2 JSON files |
| Controllers | 5 |
| ViewComponents | 7 |
| Stimulus controllers | 2 |
| Views/partials | ~8 |

---

## 11. Acceptance Criteria

- [ ] Independent page at `/eviction-guide` with 2-tab navigation
- [ ] Tab 1: Guide renders S1–S15 as accordion cards with B1–B11 inline
- [ ] Tab 1: Each step card shows description, documents, cost, conditions, branches, legal basis
- [ ] Tab 1: Legal basis displayed inline via `<details>` with external links
- [ ] Tab 1: Simulator CTA banner links to Tab 2
- [ ] Tab 2: Entry offers "property-linked" and "standalone" modes
- [ ] Tab 2: Property-linked mode pre-fills from F02 data with user confirmation UI
- [ ] Tab 2: Phase 1 (S1–S4) works as summary check with auto-complete for property-linked
- [ ] Tab 2: Phase 2 (S5–S15) yes/no flow correctly routes through main steps and branches
- [ ] Tab 2: Branch entry shows countermeasure card inline and routes to return step
- [ ] Tab 2: Result screen shows difficulty level, personalized path, and disclaimer
- [ ] Tab 2: Property-linked simulation is persisted to DB; standalone is session-only
- [ ] Cross-links work bidirectionally between Guide and Simulator tabs
- [ ] F02 grade tab includes "명도 시나리오 보기" link
- [ ] All seed data loads correctly via `rails db:seed`
- [ ] Disclaimer displayed on both tabs
