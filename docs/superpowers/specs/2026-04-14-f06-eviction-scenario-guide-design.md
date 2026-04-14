# F06. Eviction Scenario Guide — Design Spec

## 1. Overview

### Purpose

Provide a comprehensive eviction (명도) guidance system for auction property buyers. The feature operates as an independent section (`/eviction-guide`) with three tabs: Process Flowchart, Simulator, and Legal Knowledge Base.

### Design Principles

- **Education first:** Users learn the full eviction process before simulating their specific scenario
- **Simulation-driven:** Interactive yes/no flow produces a personalized eviction path with difficulty assessment
- **Property-linked (optional):** When connected to an F02-analyzed property, pre-fills simulator with AI analysis results requiring user confirmation
- **Seed-data driven:** All content (steps, branches, questions, legal references) managed via JSON seed files for code-free content updates
- **Professional deference:** All pages include disclaimer that execution requires professional consultation

### References

- `docs/references/ref-001.md` — Eviction process overview and negotiation strategies
- `docs/references/ref-002.md` — Web page structure proposal (5 pages)
- `docs/references/ref-003.md` — Case-by-case eviction scenarios (delivery order, opposing power tenants, lien rights, occupant substitution, absent occupants)
- `docs/references/ref-004.md` — Legal source material (statutes, court decisions, practitioner guidance)
- `docs/references/ref-005.md` — Information architecture: 3-page structure with detailed section specs
- `docs/references/ref-006.md` — Complete workflow: S1–S15 main flow + B1–B11 branch flow + service design suggestions

### Scope Exclusions

- D-Day calculator (date-based deadline tracking)
- Cost simulator (eviction cost estimation, moving cost calculator)
- Document auto-generation (certified mail, delivery order applications)
- Automated contact features

---

## 2. Architecture

### Relationship to Existing Features

```
/eviction-guide (independent section)
  ├── Tab 1: Process Flowchart
  ├── Tab 2: Simulator
  │     └── Optional: property linkage via /properties/:id
  └── Tab 3: Legal Knowledge Base

F02 Property Inspection ──(data feed)──► Simulator (pre-fill)
  └── RightsAnalysisReport
  └── InspectionResults
```

- Fully independent from F02 tab structure
- F02 data flows one-way into the simulator as pre-fill values
- No F02 dependency required — simulator works standalone
- Cross-links from F02 grade tab: "View eviction scenario" link

### Data Lifecycle

| Mode | Storage | Behavior |
|---|---|---|
| Property-linked | DB (`eviction_simulations` table) | Persisted, resumable, property FK set |
| Standalone | Rails session (cookie-based) | Volatile, cleared on session expiry or browser close, property FK null. Answers stored in `session[:eviction_simulation]` hash. No DB record created. |

---

## 3. Data Model

### Seed Data Models (loaded from JSON)

#### `eviction_steps` — Main Flow S1–S15

| Column | Type | Description |
|---|---|---|
| code | string (unique) | `S1`–`S15` |
| name | string | Step name (Korean) |
| description | text | Why this step is necessary |
| completion_condition | text | Yes condition → proceed |
| failure_condition | text | No condition → branch |
| required_documents | json | Document list array |
| estimated_duration | string | e.g., "1~3개월" |
| estimated_cost | string (nullable) | e.g., "100~300만원" |
| legal_references | json | Related legal reference codes array |
| position | integer | Display order |
| next_step_code | string | Next main step code |
| branch_codes | json | Branch codes triggered on failure |

#### `eviction_branches` — Branch Flow B1–B11

| Column | Type | Description |
|---|---|---|
| code | string (unique) | `B1`–`B11` |
| name | string | Branch name |
| trigger_step_code | string | FK to the main step that triggers this branch |
| problem_summary | text | One-line situation summary |
| root_cause | text | Root cause explanation |
| action_steps | json | Ordered array of countermeasure steps |
| legal_references | json | Related legal reference codes array |
| return_step_code | string | Main step to return to after resolution |
| estimated_additional_duration | string | Additional time estimate |

#### `eviction_simulator_questions` — Simulator Questions

| Column | Type | Description |
|---|---|---|
| code | string (unique) | `Q1`, `Q2`, ... |
| phase | string | `summary` (S1–S4) or `detail` (S5–S15) |
| step_code | string | Related main step code |
| question | text | Question text (Korean) |
| help_text | text | Supplementary explanation |
| yes_next_code | string | Next question on yes |
| no_next_code | string | Next question on no (may enter branch) |
| f02_field_mapping | string (nullable) | F02 data field path for auto-fill |
| difficulty_impact | string (nullable) | Impact on difficulty assessment |

#### `legal_references` — Legal Knowledge Base

| Column | Type | Description |
|---|---|---|
| code | string (unique) | `law-001`, `case-001`, `term-001`, `form-001` |
| category | string (enum) | `statute`, `case_law`, `glossary`, `form_template` |
| title | string | Title |
| content | text | Body (markdown supported) |
| metadata | json | Category-specific data (article number, case number, external URL, etc.) |
| related_codes | json | Bidirectional cross-reference codes |
| position | integer | Sort order within category |

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

Three JSON files following the existing `db/seeds/` pattern:

| File | Content | Approximate Items |
|---|---|---|
| `db/seeds/eviction_steps.json` | S1–S15 steps + B1–B11 branches | 26 items |
| `db/seeds/eviction_simulator_questions.json` | Simulator question flow | ~25–30 questions |
| `db/seeds/legal_references.json` | Statutes, case law, glossary, form templates | ~25–30 items initially |

### Initial Legal References Content

**Statutes (5):**
- 민사집행법 제136조 (인도명령)
- 민사집행법 제91조 (말소주의/유치권 인수)
- 민사집행법 제24조, 제30조 (집행권원)
- 민법 제320조 (유치권)
- 주택임대차보호법 제3조 (대항력), 제3조의2 (우선변제권)

**Case Law (3):**
- 대법원 2016다248431 (무상거주확인서/신의칙)
- 대법원 2010마1059 (유치권 경매 소멸주의)
- 대법원 2019다247385 (유치권 부존재 확인 이익)

**Glossary (15):**
- 말소기준권리, 대항력, 우선변제권, 배당요구/배당요구종기, 인도명령, 명도소송, 점유이전금지가처분, 유치권, 명도확인서, 집행권원, 계고, 소액임차인 최우선변제, 경락잔금, 강제집행, 부종성

**Form Templates (3):**
- 인도명령 신청서
- 점유이전금지가처분 신청서
- 내용증명 (임차인용)

---

## 5. Page Structure & Routing

### Routes

```ruby
# config/routes.rb
resources :eviction_guide, only: [] do
  collection do
    get :process_flow    # Tab 1: Process Flowchart
    get :simulator       # Tab 2: Simulator
    get :legal           # Tab 3: Legal Knowledge
  end
end

namespace :eviction_guide do
  resource :simulation, only: [:create, :update, :show]
  get "simulator/question/:code", to: "simulator#question", as: :simulator_question
  get "steps/:code", to: "steps#show", as: :step_detail
  get "branches/:code", to: "branches#show", as: :branch_detail
  get "legal/:code", to: "legal#show", as: :legal_detail
end
```

### Controllers

```
app/controllers/
  eviction_guide_controller.rb          # 3 tab main actions
  eviction_guide/
    simulations_controller.rb           # Simulation CRUD
    simulator_controller.rb             # Question-by-question Turbo Frame responses
    steps_controller.rb                 # Step detail cards (Turbo Frame)
    branches_controller.rb              # Branch detail cards (Turbo Frame)
    legal_controller.rb                 # Legal detail cards (Turbo Frame)
```

### Views

```
app/views/eviction_guide/
  process_flow.html.erb                 # Tab 1: Flowchart
  simulator.html.erb                    # Tab 2: Simulator main
  legal.html.erb                        # Tab 3: Legal knowledge list
  simulator/
    _question.html.erb                  # Individual question (Turbo Frame)
    _result.html.erb                    # Simulation result
    _property_selector.html.erb         # Property selection UI
  steps/
    show.html.erb                       # Step detail card (Turbo Frame)
  branches/
    show.html.erb                       # Branch detail card (Turbo Frame)
  legal/
    show.html.erb                       # Legal item detail (Turbo Frame)
```

### ViewComponents

```
app/components/eviction_guide/
  tab_navigation_component.rb           # 3-tab navigation (reusable)
  flowchart_component.rb                # S1–S15 + B1–B11 flowchart
  flowchart_node_component.rb           # Individual node (main vs branch styling)
  step_card_component.rb                # Step detail card
  branch_card_component.rb              # Branch countermeasure card
  simulator_question_component.rb       # Yes/no question card
  simulator_result_component.rb         # Simulation result summary
  f02_prefill_component.rb              # F02 auto-fill confirmation UI
  legal_card_component.rb               # Legal knowledge card (statute/case/term/form)
  legal_filter_component.rb             # Category filter pills
  difficulty_badge_component.rb         # Difficulty badge (high/medium/low)
```

### Stimulus Controllers

```
app/javascript/controllers/
  flowchart_controller.js               # Flowchart interaction (node click, path highlight)
  simulator_controller.js               # Simulator state (question flow, answer tracking)
  legal_filter_controller.js            # Legal knowledge category filtering
```

### Turbo Frame Strategy

| Interaction | Frame ID | Content |
|---|---|---|
| Flowchart node click | `step_detail` | Step or branch detail card |
| Simulator question transition | `simulator_question` | Next question card |
| Legal card click | `legal_detail` | Legal item full detail |
| Tab switching | Turbo Drive | Full tab content replacement |

---

## 6. Tab Details

### Tab 1 — Process Flowchart (명도 프로세스)

**Layout:** Split view — left: interactive flowchart, right: detail panel (Turbo Frame)

**Flowchart:**
- Vertical flow layout using CSS + Stimulus
- Main steps (S1–S15): primary color nodes
- Branch points (B1–B11): warning color nodes, positioned beside their trigger step
- Connecting lines with arrows
- Node click → loads detail card in right panel
- Active node highlighted, related branches highlighted on hover

**Detail Panel (StepCardComponent / BranchCardComponent):**

Step card fields:
- Step name and code
- Description (why necessary)
- Required documents (checklist format)
- Estimated duration and cost
- Completion condition (green)
- Failure condition with branch link (red)
- Legal reference deep links → Tab 3

Branch card fields:
- Branch name, trigger step
- Problem summary and root cause
- Action steps (ordered list)
- Legal references
- Return step indicator
- Additional duration estimate

### Tab 2 — Simulator (명도 시뮬레이터)

**Entry Screen:**
- Two cards: "내 물건으로 시뮬레이션" / "직접 입력으로 시뮬레이션"
- Property selector: dropdown of user's analyzed properties (F02 complete)

**F02 Data Confirmation (property-linked only):**
- Lists pre-filled values from RightsAnalysisReport/InspectionResults
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
  - Related legal reference links
  - Expandable "상세 안내" accordion
- Branch entry: shows BranchCardComponent inline with action steps, then "대책 확인 → 다음 단계" button routes to the return step

**Result Screen:**
- Difficulty badge (high/medium/low)
- Visual path: ordered list of traversed steps + branches with status badges (완료/필요/분기)
- Summary stats: total steps, branch entries count
- Disclaimer: "이 결과는 시뮬레이션이며, 실제 명도 작업은 반드시 법률 전문가와 상담 후 진행하세요."

**Difficulty Assessment Logic:**
- **High:** Any branch from B1 (deposit assumption risk), B2 (lien), B4 (occupant substitution), B6 (deadline missed)
- **Medium:** Branches B3, B5, B7, B8, B9
- **Low:** No branches entered, or only B10/B11 (post-completion issues)

### Tab 3 — Legal Knowledge (법률 지식)

**Layout:** Category filter + card grid + detail panel

**Filter:** Pill buttons — 전체 / 법조문 / 판례 / 용어사전 / 서식
- Stimulus controller toggles visibility by category
- No server round-trip (client-side filter)

**Card Grid:** 2-column responsive grid
- Each card: category badge, title, summary, related item count
- Form template cards: download indicator
- Click → loads detail in panel below

**Detail Panel (LegalCardComponent):**

Statute detail:
- Article number and law name
- Original text (blockquote with left border)
- Plain language explanation
- Applicable situations (links to steps/branches)
- External URL (법제처)

Case law detail:
- Case number
- Holding summary
- Core legal principle
- Practical implications
- Related statutes and steps

Glossary detail:
- One-line definition
- Detailed explanation
- Practical example
- Related terms (cross-links)

Form template detail:
- Description and usage guide
- Download link (future: ActiveStorage attachment)
- Related steps where this form is needed

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
| Lien (유치권) claim exists | `InspectionResult` | `find_by(inspection_item_code: "rights-019").has_risk` |
| Gratuitous residence doc | `InspectionResult` | `find_by(inspection_item_code: "rights-020").has_risk` |
| Occupant type | `RightsAnalysisReport#report_data` | `dig("occupant_type")` |
| Small-sum tenant | `RightsAnalysisReport#effective_tenants` | `any? { \|t\| t["has_priority_repayment"] }` |

**Fallback:** When a mapped field is missing or null, the question is marked as "미확인" and the user must answer manually.

---

## 8. Cross-Linking Strategy

All cross-references use code-based lookups:

```
Process Tab ──(legal_references)──► Legal Tab
Process Tab ──(branch_codes)──────► Branch detail (same tab)
Simulator   ──(step_code)─────────► Process Tab step
Simulator   ──(no_next_code)──────► Branch detail inline
Legal Tab   ──(related_codes)─────► Other legal items
Legal Tab   ──(metadata.applicable_situations)──► Process steps
```

Implementation: All links rendered as `<a>` tags with Turbo Frame targets or tab-switch + anchor navigation.

---

## 9. Global Elements

| Element | Implementation |
|---|---|
| Disclaimer | Fixed footer on all 3 tabs: "본 정보는 일반 정보 제공 목적이며, 개별 사안은 변호사·법무사 상담이 필요합니다." |
| Last updated date | Rendered from seed data `updated_at` field on each card |
| Source attribution | Legal references include external URL links (법제처, 대법원) |
| Professional referral CTA | Bottom of simulator result: "이 케이스 전문가 상담 받기" (placeholder for future partner integration) |

---

## 10. Acceptance Criteria

- [ ] Independent page at `/eviction-guide` with 3-tab navigation
- [ ] Tab 1: Interactive flowchart renders S1–S15 + B1–B11 with click-to-detail
- [ ] Tab 2: Simulator entry offers "property-linked" and "standalone" modes
- [ ] Tab 2: Property-linked mode pre-fills from F02 data with user confirmation UI
- [ ] Tab 2: Phase 1 (S1–S4) works as summary check with auto-complete for property-linked
- [ ] Tab 2: Phase 2 (S5–S15) yes/no flow correctly routes through main steps and branches
- [ ] Tab 2: Branch entry shows countermeasure card inline and routes to return step
- [ ] Tab 2: Result screen shows difficulty level, personalized path, and disclaimer
- [ ] Tab 2: Property-linked simulation is persisted to DB; standalone is session-only
- [ ] Tab 3: Category filter works client-side (법조문/판례/용어사전/서식)
- [ ] Tab 3: Card click loads detail in Turbo Frame panel
- [ ] Cross-links work bidirectionally between all 3 tabs
- [ ] All seed data loads correctly via `rails db:seed`
- [ ] Disclaimer displayed on all tabs
