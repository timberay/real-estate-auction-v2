# Real Estate Auction Service — Software Requirements Specification (SRS) v2.0

## 1. Document Overview

### Purpose

This document is the consolidated Software Requirements Specification (SRS) v2.0 for a web service designed for real estate auction beginners in Korea. It supersedes all prior SRS and feature restructure documents and reflects the full review conducted on 2026-04-11.

### Supersedes

- `2026-04-05-srs-design.md` — SRS v1.0 (original 11 features)
- `2026-04-07-feature-restructure-design.md` — Feature restructure (11 → 7 features)
- `2026-04-11-pdf-analysis-redesign.md` — PDF-based analysis redesign (retained, incorporated here)

### Scope

- Functional requirements for 6 features (F01–F06)
- Priority classification (P0/P1/P2) and deployment order
- Feature dependencies
- Inspection item tab reclassification (89 items across 5 tabs + grade summary)
- Decisions on removed features and rationale

### Version History

| Version | Date | Description |
|---|---|---|
| v1.0 | 2026-04-05 | Initial SRS with 11 features (F01–F11) |
| v1.1 | 2026-04-07 | Feature restructure: 11 → 7 features, 6+1 tab structure |
| v1.2 | 2026-04-11 | PDF-based analysis redesign |
| **v2.0** | **2026-04-11** | **Full SRS review: 7 → 6 features, tab reclassification, scope refinement** |

### Deployment Strategy

Each feature is treated as an independent deliverable. A feature must be fully completed before the next feature's schedule is planned. This enables focused quality and incremental value delivery.

### Glossary

| Term (Korean) | English | Definition |
|---|---|---|
| 말소기준권리 | Extinguishment Base Right | The earliest-priority right (mortgage, provisional seizure, or seizure) on a property's registry. Rights established after this date are extinguished upon successful auction. |
| 대항력 | Opposing Power | A tenant's legal right to assert their lease against a new owner. Determined by whether the tenant's move-in registration date precedes the extinguishment base right date. |
| 배당 | Dividend/Distribution | Court-ordered distribution of auction proceeds to creditors and tenants in priority order. |
| 매각물건명세서 | Sale Property Description | Court-issued document describing the auctioned property, including special conditions, tenant information, and encumbrances. |
| 등기부등본 | Registry Transcript | Official document showing all rights, mortgages, seizures, and ownership history of a property. |
| 인수 금액 | Assumed Amount | The amount a winning bidder must bear (typically outstanding tenant deposits with opposing power that are not extinguished). |
| 명도 | Eviction/Vacating | The process of having occupants vacate the property after winning the auction. |
| HUG | Housing & Urban Guarantee Corp | Government housing guarantee corporation. Properties where HUG has waived opposing power are considered "safe opportunity" items. |
| 경락잔금대출 | Auction Balance Loan | A loan to pay the remaining balance after winning an auction (typically 70–80% of the winning bid). |
| DSR | Debt Service Ratio | Total annual debt repayments divided by annual income. Used to determine loan eligibility. |
| LTV | Loan-to-Value | Loan amount as a percentage of the property's appraised value. |
| 감정평가액 | Appraisal Value | Court-appointed appraiser's valuation of the property, used as the starting price basis. |
| 최저매각가격 | Minimum Sale Price | The minimum bid amount for an auction round. The court provides this value directly. |
| 유치권 | Lien (Retention Right) | Right to retain possession of property until payment for improvements/repairs is made. High risk for beginners. |
| 법정지상권 | Statutory Superficies | Legal right to use land when building and land owners differ. Complex and risky for beginners. |
| 소액임차인 | Small-Sum Tenant | Tenants with deposits below a regional threshold who receive priority repayment regardless of other creditors. |
| 확정일자 | Confirmed Date | Official date stamp on a lease contract, establishing the tenant's priority in dividend distribution. |

---

## 2. Design Principles

Three principles derived from expert feedback that govern all feature design decisions.

| Principle | Description | Implementation Guideline |
|---|---|---|
| Repetition & Mastery | Users should not just analyze one property and stop. The service must naturally guide them to "analyze the next property," creating a repeating cycle. | Every analysis completion must show a "Next property" CTA. Track cumulative analysis count. |
| Overconfidence Prevention | AI analysis results must always be shown alongside original documents. Users who trust AI blindly without checking source documents will make costly mistakes. | Place original document viewer next to AI reports. Show disclaimer on every AI-generated analysis. |
| Respect for Fieldwork | Online features must never give the impression that they "replace" on-site inspection or professional consultation. All online analysis is "pre-screening." Execution (loan decisions, eviction, legal actions) belongs to offline professionals. | Display fixed notice: "This is for pre-screening only." Never use language suggesting field visits or professional consultations are unnecessary. PDF report export includes "professional consultation guide." |

---

## 3. User Pain Points

| # | Pain Point | Current Workaround | Cost/Time Burden |
|---|---|---|---|
| P1 | Rights analysis is difficult and frightening | Paid consulting or self-study | Very High |
| P2 | Negative returns due to missed taxes/costs | Tax advisor consultation, manual calculation | Very High |
| P3 | Unknown bidding range within own budget | Manual calculation (requires formula knowledge) | Medium |
| P4 | Bidding without accurate market price knowledge | Multiple proptech apps + real estate agent visits | High |
| P5 | Cannot confirm loan eligibility before bidding | Collecting business cards at court, calling each one | High |
| P6 | Eviction process is psychologically frightening | Community advice, experienced investor coaching | Medium |

---

## 4. Feature Specifications

### F01. Onboarding Budget Setup Flow

| Item | Detail |
|---|---|
| Priority | P0 (MVP) |
| Pain Points | P3 |
| Deploy Order | 1st |

#### Description

Upon first visit, the user answers a 3-step questionnaire to determine "what properties I can afford." The result automatically sets the property search filter. There is no separate calculator menu — it is embedded in the service entry flow.

#### Requirements

**(A) Onboarding Question Flow (3 Steps):**

- Step 1: Enter available cash for investment
- Step 2: Reserve fund setup — enter amounts per item or select "Use defaults"
  - Default values loaded from seed data JSON (user-researched market rates)
  - Items: repair costs, acquisition tax, judicial scrivener fee, moving costs, unpaid maintenance fees
- Step 3: Select loan policy and set loan ratio (%) — slider or presets: 60% / 70% / 80% / 90%

**(B) Calculation:**

- Formula: (Available Cash - Total Reserve Funds) / (1 - Loan Ratio) = Maximum Biddable Amount
- Output: Maximum biddable amount + itemized cost breakdown summary

**(C) Integration & Persistence:**

- Calculation result auto-sets F02 property search filter
- Settings editable anytime from My Page
- Upon onboarding completion, navigate to property list screen

**(D) Property Type:**

- Property type (apartment, villa, officetel, etc.) is NOT selected during onboarding
- Users discover property types naturally while browsing search results
- Region filter is provided in F02 search screen (criteria search already supports region parameters)

**(E) Authentication:**

- Development phase: single seed user, no login required
- Deployment: SNS/OAuth authentication (Google, Naver, Kakao) — no email/password
- Implementation via OmniAuth gem at deployment time

#### Acceptance Criteria

- [ ] 3-step question flow completes and produces a maximum biddable amount
- [ ] "Use defaults" applies seed-data-based values for each reserve item
- [ ] Calculation result is persisted and retrievable/editable from My Page
- [ ] Onboarding completion redirects to the property list screen
- [ ] Changing budget settings on My Page updates the search filter accordingly

#### Dependencies

- Upstream: None (service entry point)
- Downstream: F02 (search filter)

---

### F02. Property Inspection (물건분석)

| Item | Detail |
|---|---|
| Priority | P0 (MVP) |
| Pain Points | P1, P3, P4, P5 |
| Deploy Order | 2nd |

#### Description

The core analysis feature. Users upload PDF documents from the court auction site, and the LLM analyzes them to auto-judge inspection items. Combined with manual input for items requiring field visits or external data, the system produces a comprehensive safety grade. The tab structure is organized by **information source type**, not abstract risk categories.

#### Tab Structure (5 Tabs + Grade Summary)

```
Property Inspection Screen
├── [권리분석]    27 items — From court documents (매각물건명세서, 등기부등본, 현황조사서)
├── [물건분석]    13 items — From building ledger, property listing data
├── [현장확인]    13 items — Requires physical site visit
├── [수익분석]    29 items — Market price, tax, finance, profitability
├── [입찰&낙찰]    7 items — Bidding process and decision
└── [최종등급]    Aggregated results + rights analysis report + bid decision
```

**Total: 89 inspection items + 1 grade summary tab = 6 tabs**

**Navigation:** Free-form tab navigation (not sequential stepper). Users can visit any tab in any order.

#### Analysis Methods

**(A) PDF Upload + LLM Analysis (Primary — ~30-35 items):**

- Users upload PDF documents (매각물건명세서, 현황조사서, 감정평가서, 등기부등본)
- LLM analyzes PDF content directly (multimodal)
- Primarily covers: 권리분석 tab (27 items) + 물건분석 tab (partial)
- Supported LLM providers: Anthropic Claude, Gemini (native PDF support)
- Unsupported providers return clear error message

**(B) Ministry of Land Real Transaction Price API (~4 items):**

- Integrated in MVP for 수익분석 tab automation
- Auto-judgment items: market-001 (transaction volume), market-003 (comparable filtering), market-004 (recent transactions), resale-004 (appraisal vs. market price)
- market-002 (KB price comparison) remains manual — partial automation could mislead
- Infrastructure reused by F04 (Integrated Market Price) in P1

**(C) Manual Input (Remaining ~50 items):**

- 현장확인 tab: all 13 items (physical site visit required)
- 수익분석 tab: most items (external data sources, user-specific conditions)
- 입찰&낙찰 tab: all 7 items (user actions/judgments)

#### 최종등급 Tab

Aggregates all inspection results into a final bid decision.

**Overall Grade Rating Logic:**
- **위험 (Danger):** Any item has `has_risk=true` AND `resolvable=false`
- **주의 (Caution):** Any item has `has_risk=true` (but all resolvable)
- **안전 (Safe):** No items have `has_risk=true`
- **미완료:** Any item has `has_risk=null` (unanswered) → warning banner

**Sections:**
1. Overall grade display
2. Tab-by-tab summary table (안전/위험/미입력 counts)
3. Risk items detail (grouped by resolvable status)
4. Rights analysis report (inline — extinguishment base right, opposing power, assumed amount, dividend simulation, HUG opportunity detection)

**Overconfidence Prevention (Mandatory):**
- Source document viewer toggle
- Disclaimer: "AI 생성 참고 자료입니다. 원본 서류를 직접 확인하세요"
- `source_doc_reviewed` tracking per user

#### Acceptance Criteria

- [ ] PDF upload and LLM analysis produces auto-judgments for rights/property items
- [ ] Ministry of Land API auto-populates market-001, market-003, market-004, resale-004
- [ ] Manual input works for all remaining items
- [ ] Tab navigation is free-form (any order)
- [ ] 최종등급 correctly aggregates all 89 items into safety grade
- [ ] Rights analysis report renders inline in 최종등급 tab
- [ ] Dividend simulation works with user-input expected bid amount
- [ ] HUG opportunity properties are auto-detected
- [ ] Source document viewer and disclaimer are present
- [ ] Each tab shows completion badge (checked/total)

#### Dependencies

- Upstream: F01 (budget filter values)
- Downstream: F04 (market price data), F05 (PDF report export), F06 (eviction scenario)

---

### F03. Net Profit Calculator with Tax & Cost Breakdown

| Item | Detail |
|---|---|
| Priority | P1 (Early Expansion) |
| Pain Points | P2 |
| Deploy Order | 3rd |

#### Description

Based on the user's ownership status and property information, calculate "the amount actually deposited in your bank account" after deducting all taxes and costs. Reverse-calculation mode determines the maximum bid from a target profit.

**Moved from MVP to P1** — Tax calculation complexity is high (acquisition tax 1-12%, capital gains tax varies by holding period/ownership type, rates change with government policy). Incorrect calculations could be worse than no calculations. Users can use external tax calculators in the interim.

#### Requirements

**(A) User Profile Input:**
- Ownership type: Individual (no property / 1 / multi), Real estate trader, Corporation
- Planned holding period: under 1 year / 1–2 years / 2+ years

**(B) Auto-Deduction Items:**
- Acquisition tax, capital gains tax, property tax, comprehensive real estate tax
- Judicial scrivener fee, brokerage commission, eviction moving costs, repair costs, unpaid maintenance fees

**(C) Tax Rate Comparison:**
- Side-by-side: Individual short-term rate vs. Real estate trader rate

**(D) Reverse-Calculation Mode:**
- Input target net profit → reverse-calculate maximum bid price

**(E) Output:**
- Itemized cost breakdown table + final net profit (highlighted)
- Disclaimer: "This calculation is an estimate. Consult a tax advisor for exact tax amounts."

#### Acceptance Criteria

- [ ] All 5 ownership types produce correct tax rate calculations
- [ ] Reverse mode: inputting target profit produces correct maximum bid price
- [ ] Itemized breakdown shows every deduction line item
- [ ] Tax disclaimer is displayed on every calculation result

#### Dependencies

- Upstream: F01 (budget data), F02 (property data), F04 (market price as expected sale price)
- Downstream: None

---

### F04. Integrated Market Price Dashboard

| Item | Detail |
|---|---|
| Priority | P1 (Early Expansion) |
| Pain Points | P4 |
| Deploy Order | 4th |

#### Description

Show actual transaction prices, listing prices, and distressed-sale prices for comparable properties on a single screen. Builds on the Ministry of Land API infrastructure established in MVP (F02). Includes a gap-rate warning system.

#### Requirements

**(A) Data Sources:**
- Recent actual transaction prices (Ministry of Land API — already integrated in F02)
- Current listing prices (manual input — KB시세, 네이버부동산 APIs not publicly available)
- Distressed-sale prices (separately highlighted)

**(B) Gap-Rate Warning:**
- Auto-calculate gap between listing price and actual transaction price
- Gap rate > 10%: warning label

**(C) Comparison Criteria:**
- Same complex same size / nearby similar complex / area average
- Note: "Exact floor/view differences require on-site agent verification"

**(D) Trends:**
- 1–3 year actual transaction price trend graph
- Area supply volume and unsold inventory summary

**(E) Integration:**
- Market price data feeds F03 net profit calculator's "expected sale price"

#### Acceptance Criteria

- [ ] Actual transaction prices displayed with priority
- [ ] Gap rate calculated and warning shown for > 10%
- [ ] Price trend graph covers 1–3 year range
- [ ] Market price auto-feeds F03 expected sale price field

#### Dependencies

- Upstream: F02 (property data, Ministry of Land API infrastructure)
- Downstream: F03 (market price as expected sale price)

---

### F05. Analysis Report PDF Export

| Item | Detail |
|---|---|
| Priority | P1 (Early Expansion) |
| Pain Points | P1, P2, P5 |
| Deploy Order | 5th |

#### Description

Export the property analysis results as a structured PDF report for use in offline professional consultations. This replaces the previously planned "Pre-Auction Loan Matching" feature — loan decisions, tax planning, and legal matters are better handled through in-person professional consultation, and this service provides the preparation materials.

**Design rationale:** Automated loan matching was removed because (1) policy loan conditions change frequently — unsustainable for a solo developer, (2) bank-specific internal criteria vary and cannot be replicated via API, (3) incorrect eligibility results could lead to deposit forfeiture after winning, (4) aligns with "Respect for Fieldwork" design principle.

#### Requirements

**(A) Report Content:**
- Property summary (address, case number, appraisal/minimum bid price)
- Budget settings from F01
- All inspection results organized by tab
- 최종등급 summary with risk items highlighted
- Rights analysis results (if available)

**(B) Professional Consultation Guide (included in PDF):**
- Rights analysis questions → 법무사/변호사 (judicial scrivener/lawyer)
- Tax questions → 세무사 (tax accountant)
- Loan questions → 은행/대출 컨설턴트 (bank/loan consultant)
- Eviction questions → 법무사 (judicial scrivener)

**(C) Format:**
- PDF format, downloadable
- Clean layout suitable for professional consultation

#### Acceptance Criteria

- [ ] PDF export includes all inspection results organized by tab
- [ ] Professional consultation guide page is included
- [ ] PDF is downloadable from property detail page
- [ ] PDF renders correctly with Korean text

#### Dependencies

- Upstream: F02 (inspection results data)
- Downstream: None

---

### F06. Eviction Scenario Guide

| Item | Detail |
|---|---|
| Priority | P2 (Growth) |
| Pain Points | P6 |
| Deploy Order | 6th |

#### Description

Predict eviction difficulty before winning and provide situation-specific process guidance. The focus is on **education and gap identification** — showing users which eviction scenario applies to their property and what steps remain to be confirmed. Execution is handled offline with professional guidance.

**Scope refinement:** Document auto-generation (내용증명, 인도명령 신청서) and automated contact features are removed. Legal documents require case-specific details that templates cannot safely capture, and automated outreach could harm sensitive negotiations.

#### Requirements

**(A) Eviction Process Guide:**
- Step-by-step explanation of the general eviction process
- Visual process flow diagram

**(B) Situation-Specific Scenario Matching:**
- Auto-classify difficulty (High/Medium/Low) based on analysis results
- Match property to specific scenario based on tenant/occupant status:

| Situation | Difficulty | Guidance |
|---|---|---|
| Tenant receives 100% dividend | Low | Tenant needs vacancy confirmation to receive money — cooperation expected |
| Small-sum tenant with priority repayment | Medium | Part resolved through dividend; negotiate moving costs for remainder |
| Deposit fully unrecoverable (no opposing power) | High | Moving cost negotiation → delivery order → court-enforced eviction |
| Debtor (owner) residing | Medium-High | Certified notice → delivery order → forced eviction |

**(C) Gap Identification:**
- Highlight inspection items not yet confirmed that affect eviction assessment
- Alert: "Complete these items first for accurate eviction difficulty assessment"

#### Acceptance Criteria

- [ ] Eviction process explained step-by-step
- [ ] Difficulty level auto-determined from analysis results
- [ ] Correct scenario guide shown based on tenant/occupant status
- [ ] Unconfirmed items that affect eviction are highlighted with alerts

#### Dependencies

- Upstream: F02 (inspection results, particularly rights analysis and tenant data)
- Downstream: None

---

## 5. Priority & Deployment Strategy

### Priority Summary

| Priority | Feature ID | Feature Name | Deploy Order | Rationale |
|---|---|---|---|---|
| P0 (MVP) | F01 | Onboarding Budget Setup | 1st | Service entry flow. Prerequisite for property search |
| P0 (MVP) | F02 | Property Inspection (5 tabs + grade) | 2nd | Core analysis feature. PDF + LLM + API + manual input |
| P1 (Expansion) | F03 | Net Profit Calculator | 3rd | Complex tax logic, accuracy hard to guarantee in MVP |
| P1 (Expansion) | F04 | Integrated Market Price Dashboard | 4th | Builds on MVP's Ministry of Land API infrastructure |
| P1 (Expansion) | F05 | Analysis Report PDF Export | 5th | Enables offline professional consultation |
| P2 (Growth) | F06 | Eviction Scenario Guide | 6th | Post-winning feature, educational focus |

### Removed Features (with rationale)

| Old ID | Feature Name | Removal Rationale |
|---|---|---|
| F05 (v1.0) | Process Checklist | Replaced by tab structure in F02 |
| F07 (v1.0) | Pre-Auction Loan Matching | Replaced by PDF Export (F05 v2.0). Loan decisions require professional consultation; automated matching carries deposit forfeiture risk |
| F08 (v1.0) | Virtual Bid Simulation | Removed in v1.1. Low priority relative to core analysis |
| F09 (v1.0) | Online Pre-Inspection | Removed in v1.1. Conflicts with "Respect for Fieldwork" principle |
| F11 (v1.0) | Expert Mentoring Marketplace | Program's purpose is analysis tool, not mediation platform. Users take PDF report to professionals independently |

### Deployment Principle

1. Each feature is an independent deliverable — fully completed before the next begins
2. Cross-priority dependencies are designed as optional integrations — the feature works standalone at launch
3. Program focuses on **information provision and analysis** — execution (loans, legal actions, eviction) is left to offline professionals

---

## 6. Feature Dependency Map

```
F01 Onboarding Budget Setup
 |
 v
F02 Property Inspection (5 tabs + grade)
 |   - PDF upload + LLM analysis
 |   - Ministry of Land API (reused by F04)
 |   - Manual input for field/market items
 |
 ├──→ F04 Integrated Market Price Dashboard
 |     |
 |     v
 |    F03 Net Profit Calculator
 |
 ├──→ F05 Analysis Report PDF Export
 |
 └──→ F06 Eviction Scenario Guide
```

---

## 7. Inspection Item Tab Reclassification

### Reclassification Summary (v2.0)

The following items were reclassified from their v1.1 tab assignments to better match their actual information source:

| Item ID | Old Tab | New Tab | Reason |
|---|---|---|---|
| inspect-001 | 현장확인 | 물건분석 | Document review (감정평가서), not field visit |
| inspect-002 | 현장확인 | 물건분석 | Document cross-reference (감정평가서 vs 건축물대장) |
| inspect-003 | 현장확인 | 수익분석 | Online research (인터넷 등기소), not field visit |
| inspect-005 | 현장확인 | 권리분석 | Document-based (무상거주 확인서 from 등기부등본) |
| inspect-010 | 현장확인 | 수익분석 | Online/phone verification (월세 시세, 대출 한도) |
| inspect-011 | 현장확인 | 수익분석 | Calculation (순수익, 입찰가), not field work |
| eviction-001 | 권리분석 | 현장확인 | Requires physical site visit (화재·누수·크랙) |
| eviction-005 | 권리분석 | 현장확인 | Requires management office visit/call (미납 관리비) |
| manual-001 | 권리분석 | 현장확인 | Requires physical site visit (분묘기지권) |
| location-001 | 물건분석 | 현장확인 | Explicitly requires field inspection (향, 층수, 내부 상태) |
| property-008 | 물건분석 | 현장확인 | Requires field verification (창문 앞 조망) |
| inspect-014 | 물건분석 | 현장확인 | Requires field verification (건물 간격, 주차 공간) |
| location-003 | 물건분석 | 수익분석 | Online map check (핵심 인프라) |
| location-007 | 물건분석 | 수익분석 | Market analysis (빌라 수요) |
| location-008 | 물건분석 | 수익분석 | Market analysis (층수 수요) |
| exit-001 | 입찰&낙찰 | 현장확인 | Requires physical site visit (악취, 환기) |

### Final Tab Distribution

| Tab | Item Count | Primary Source | LLM Auto-Analysis |
|---|---|---|---|
| 권리분석 | 27 | Court documents (매각물건명세서, 등기부등본, 현황조사서) | Yes (PDF) |
| 물건분석 | 13 | Building ledger, property listing data | Partial (PDF) |
| 현장확인 | 13 | Physical site visit | No (all manual) |
| 수익분석 | 29 | Market data, tax policy, user conditions | Partial (4 items via API) |
| 입찰&낙찰 | 7 | User actions and judgments | No (all manual) |
| **Total** | **89** | | |

---

## 8. Monetization Model

| Feature | Pricing Model | Rationale |
|---|---|---|
| F01 Onboarding | Free | User acquisition |
| F02 Inspection (basic) | Free | User acquisition & trust building |
| F02 Inspection (detailed analysis) | Premium subscription | Core consulting-replacement feature |
| F02 HUG Opportunity Properties | Premium only | Differentiated profit opportunity |
| F03 Net Profit Calculator | Premium subscription | Expert bid-pricing replacement |
| F04 Integrated Market Price | Free basic / Premium detailed | Data value-add |
| F05 PDF Report Export | Free (included with analysis) | Drives offline consultation and trust |
| F06 Eviction Guide | Free | Educational value, user retention |
