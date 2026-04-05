# Real Estate Auction Service — Software Requirements Specification (SRS) v1.0

## 1. Document Overview

### Purpose

This document is the finalized Software Requirements Specification (SRS) for a web service designed for real estate auction beginners in Korea. It defines **what** to build — not how.

### Scope

- Functional requirements for 11 features (F01–F11)
- Priority classification (P0/P1/P2/P3) and sequential deployment order
- Feature dependencies and monetization model
- Technical design, data sources, and legal review are covered in separate documents

### Version History

| Version | Date | Description |
|---|---|---|
| v0.1 | 2026-04-05 | Initial feature extraction from domain research |
| v0.2 | 2026-04-05 | Expert feedback applied (design principles, priority changes, new features) |
| v1.0 | 2026-04-05 | Finalized SRS with acceptance criteria, dependency map, deployment strategy |

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
| 최저매각가격 | Minimum Sale Price | The minimum bid amount for an auction round (typically 80% of appraisal, reduced 20% each failed round). |
| 유치권 | Lien (Retention Right) | Right to retain possession of property until payment for improvements/repairs is made. High risk for beginners. |
| 법정지상권 | Statutory Superficies | Legal right to use land when building and land owners differ. Complex and risky for beginners. |
| 근린생활시설 | Neighborhood Living Facility | Commercial-zoned property often disguised as residential. Carries tax disadvantages and loan restrictions. |
| 소액임차인 | Small-Sum Tenant | Tenants with deposits below a regional threshold who receive priority repayment regardless of other creditors. |
| 확정일자 | Confirmed Date | Official date stamp on a lease contract, establishing the tenant's priority in dividend distribution. |

---

## 2. Design Principles

Three principles derived from expert feedback that govern all feature design decisions.

| Principle | Description | Implementation Guideline |
|---|---|---|
| Repetition & Mastery | Users should not just analyze one property and stop. The service must naturally guide them to "analyze the next property," creating a repeating cycle. Mechanical repetition builds skill faster than studying. | Every analysis completion must show a "Next property" CTA. Track cumulative analysis count. Provide weekly goals. |
| Overconfidence Prevention | AI analysis results must always be shown alongside original documents (e.g., Sale Property Description). Users who trust AI blindly without checking source documents will make costly mistakes. | Place original document viewer next to AI reports. Show disclaimer on every AI-generated analysis. Prompt confirmation when users skip source document review. |
| Respect for Fieldwork | Online features must never give the impression that they "replace" on-site inspection (임장). All online analysis is "pre-screening" — final decisions must be made on-site. | Display fixed notice: "This is for pre-screening only." Provide nearby real estate agent contacts. Never use language suggesting field visits are unnecessary. |

---

## 3. User Pain Points

| # | Pain Point | Current Workaround | Cost/Time Burden |
|---|---|---|---|
| P1 | Rights analysis is difficult and frightening | Paid consulting (tens of thousands to millions KRW per case) or self-study | Very High |
| P2 | Negative returns due to missed taxes/costs | Tax advisor consultation, manual calculation | Very High |
| P3 | Unknown bidding range within own budget | Manual calculation (requires formula knowledge) | Medium |
| P4 | Bidding without accurate market price knowledge | Multiple proptech apps + real estate agent visits | High |
| P5 | Cannot confirm loan eligibility before bidding | Collecting business cards at court, calling each one | High |
| P6 | Weekday on-site inspection impossible (office workers) | Using vacation days or giving up | Medium |
| P7 | Eviction process is psychologically frightening | Community advice, experienced investor coaching | Medium |
| P8 | Complex legal/tax filing after acquisition | Delegating to judicial/tax scriveners (costly) | Medium |
| P9 | First real bid is scary, no practical experience | Academy courses, YouTube (gap with reality) | High |

---

## 4. Feature Specifications

### F01. Onboarding Budget Setup Flow

| Item | Detail |
|---|---|
| Priority | P0 (MVP) |
| Pain Points | P3 |
| Deploy Order | 1st |

#### Description

Upon signup, the user answers a 3-step questionnaire to determine "what properties I can afford." The result automatically sets the property search filter. There is no separate calculator menu — it is embedded in the service entry flow.

#### Requirements

**(A) Onboarding Question Flow (3 Steps):**

- Step 1: Enter available cash for investment
- Step 2: Reserve fund setup — enter amounts per item or select "Use defaults"
  - Default values auto-applied by property type and size (sqm range)
  - Items: repair costs, acquisition tax, judicial scrivener fee, moving costs, unpaid maintenance fees
- Step 3: Expected loan ratio (%) — slider or presets: 60% / 70% / 80% / 90%

**(B) Calculation:**

- Formula: (Available Cash - Total Reserve Funds) / (1 - Loan Ratio) = Maximum Biddable Amount
- Output: Maximum biddable amount + itemized cost breakdown summary

**(C) Integration & Persistence:**

- Calculation result auto-sets F02 property search filter
- Settings editable anytime from My Page
- Upon onboarding completion, navigate to "View safe properties within my budget" screen

#### Acceptance Criteria

- [ ] 3-step question flow completes and produces a maximum biddable amount
- [ ] "Use defaults" applies property-type-specific average values for each reserve item
- [ ] Calculation result is persisted and retrievable/editable from My Page
- [ ] Onboarding completion redirects to the property list screen
- [ ] Changing budget settings on My Page updates the search filter accordingly

#### User Value

Complete the first step of auction investing naturally without separate menu navigation, and immediately enter property discovery.

#### Dependencies

- Upstream: None (service entry point)
- Downstream: F02 (search filter), F04 (budget data reference), F07 (loan-adjusted max bid)

---

### F02. Safe Property Auto-Filtering & Risk Warnings

| Item | Detail |
|---|---|
| Priority | P0 (MVP) |
| Pain Points | P1, P5 |
| Deploy Order | 2nd |

#### Description

Automatically identify risky properties across three axes — legal risk, resale risk, and loan risk — and either exclude them from results or display warnings. This goes beyond legal-only filtering to protect beginners from "properties you can't sell" and "properties you can't get a loan for."

#### Requirements

**(A) Legal Risk Filter:**

- Auto-detect special conditions in Sale Property Description remarks (lien, statutory superficies, grave site rights, etc.) → "Legal Risk" label
- Auto-identify partial-share auction items and provide filtering option
- Warn on properties with both opposing-power tenants AND tax office seizures

**(B) Resale Risk Filter:**

- New villa detection: completed within 2 years + appraisal significantly above nearby market price → "New Villa Caution" warning (inflated sale price risk)
- Studio/1.5-room identification → "Difficult to Resell + Loan Restrictions" warning
- Insufficient parking: building registry parking-to-unit ratio below threshold → "Parking Shortage Caution" warning
- Neighborhood facility (근생) villa identification: building registry usage is 'neighborhood living facility' → "Not Residential (Tax Disadvantage)" warning

**(C) Loan Disqualification Warning:**

- Cross-check building registry for illegal construction → "Loan Blocked Risk" warning
- Neighborhood facility villas, studios, etc. that lenders avoid → "Loan Restriction Possible" warning

**(D) Safety Rating System:**

- 3-tier rating per property: Safe (beginner recommended) / Caution (experienced recommended) / Danger (expert required)
- "Show safe properties only" one-click filter preset
- Display risk/caution basis per item on property detail page

#### Acceptance Criteria

- [ ] Properties with lien, statutory superficies, or grave site rights are labeled "Legal Risk"
- [ ] Partial-share properties are identifiable and filterable
- [ ] New villas (completed < 2 years, inflated appraisal) trigger "New Villa Caution"
- [ ] Studios/1.5-rooms are labeled with resale and loan warnings
- [ ] Illegal construction properties show "Loan Blocked Risk" warning
- [ ] Every property has a 3-tier safety rating (Safe/Caution/Danger)
- [ ] "Show safe properties only" filter works correctly as a one-click preset
- [ ] Risk basis is visible on property detail page for Caution/Danger items

#### User Value

Prevent financial loss by blocking not just legally risky properties but also "unsellable" and "unloanable" ones before beginners can bid on them.

#### Dependencies

- Upstream: F01 (budget filter values)
- Downstream: F03 (property feeds rights analysis), F06 (property feeds market price lookup)

---

### F03. Automated Rights Analysis Report

| Item | Detail |
|---|---|
| Priority | P0 (MVP) |
| Pain Points | P1 |
| Deploy Order | 3rd |

#### Description

Automatically analyze extinguishment base rights, tenant opposing power, and assumed amounts from registry transcripts and sale property descriptions, and deliver a report. The AI report must always be shown alongside the original document to prevent overconfidence. HUG opportunity property detection is a key differentiator.

#### Requirements

**(A) Core Analysis:**

- Extinguishment base right auto-extraction: identify the earliest-priority right (mortgage/provisional seizure/seizure) and set as the base date
- Tenant opposing power determination: compare move-in registration date (next day 00:00 basis) with extinguishment base right → auto-determine opposing power yes/no
- Assumed amount calculation: check confirmed date, dividend request deadline compliance → calculate actual deposit amount the winning bidder must bear
- Dividend simulation: upon entering expected winning bid, output creditor/tenant dividend priority and amounts as a table

**(B) Overconfidence Prevention (mandatory):**

- Place Sale Property Description original document viewer next to (or as tab-switch from) AI report
- Fixed notice at report bottom: "This analysis is AI-generated reference material. You must verify the Sale Property Description remarks section yourself."
- If user attempts to proceed to next step (market price check) without opening original document: show confirmation popup "Have you reviewed the Sale Property Description?"

**(C) Opportunity Property Detection (key differentiator):**

- Auto-detect properties where HUG has submitted an opposing-power waiver → "Safe Opportunity Property" label
- Among properties beginners avoid due to red-text (opposing-power tenants), identify those with no actual assumed-amount risk and expose as a separate recommendation list
- Explain "why it's safe" in plain language for each opportunity property

**(D) Report Output Format:**

- Per-property 1-page summary: Safe/Caution/Danger verdict + 3-line key basis summary
- Detailed analysis page: registry timeline, rights relationship diagram, dividend table

#### Acceptance Criteria

- [ ] Extinguishment base right is correctly extracted from registry data
- [ ] Tenant opposing power is correctly determined based on move-in date vs. base right date
- [ ] Assumed amount calculation accounts for confirmed date and dividend request deadline
- [ ] Dividend simulation produces correct priority-ordered distribution table
- [ ] Original document viewer is accessible alongside every AI report
- [ ] Disclaimer text is displayed on every report
- [ ] Skipping original document review triggers a confirmation popup
- [ ] HUG opposing-power waiver properties are auto-detected and labeled
- [ ] Opportunity properties include plain-language safety explanations
- [ ] Report includes both 1-page summary and detailed analysis views

#### User Value

Replace consulting costs of tens of thousands to millions of KRW per case, while building the habit of source-document verification to prevent AI overconfidence accidents. HUG opportunity property discovery finds "valuable properties others miss" — the core differentiator.

#### Dependencies

- Upstream: F02 (property data feed)
- Downstream: F04 (assumed amount feeds profit calculation), F10 (dividend simulation feeds eviction difficulty)

---

### F04. Net Profit Calculator with Tax & Cost Breakdown

| Item | Detail |
|---|---|
| Priority | P0 (MVP) |
| Pain Points | P2 |
| Deploy Order | 4th |

#### Description

Based on the user's ownership status and property information, calculate "the amount actually deposited in your bank account" after deducting all taxes and costs from the expected sale price. The reverse-calculation mode — determining the maximum bid from a target profit — is an MVP-essential feature.

#### Requirements

**(A) User Profile Input:**

- Ownership type: Individual (no property / 1 property / multi-property), Real estate trader, Corporation
- Planned holding period: under 1 year / 1–2 years / 2+ years

**(B) Auto-Deduction Items (full cost breakdown):**

- Acquisition tax: auto-applied 1–12% based on officially assessed price and property count
- Capital gains tax: auto-matched rate by holding period and ownership type
- Property tax / Comprehensive real estate tax: reflected proportionally to holding period
- Judicial scrivener fee, brokerage commission, eviction moving costs, interior repair costs, unpaid maintenance fees

**(C) Tax Rate Comparison Display:**

- Show side-by-side: Individual short-term (< 1 year) rate 77% vs. Real estate trader rate 6–45%
- Enable immediate recognition of profit difference based on trader registration

**(D) Reverse-Calculation Mode (MVP essential):**

- Input target net profit → reverse-calculate the maximum bid price to achieve that profit
- Answer: "To earn 20M KRW from this property, what should I bid?"
- Reverse-calculated result links as reference amount when writing bid form

**(E) Output:**

- Itemized cost breakdown table
- Final net profit amount (highlighted)
- Fixed notice: "This calculation is an estimate. Consult a tax advisor for exact tax amounts."

#### Acceptance Criteria

- [ ] All 5 ownership types produce correct tax rate calculations
- [ ] Acquisition tax auto-applies correct rate (1–12%) based on assessed price and property count
- [ ] Capital gains tax correctly reflects holding period and ownership type
- [ ] Side-by-side comparison shows individual vs. trader rates for short-term sales
- [ ] Reverse mode: inputting target profit produces the correct maximum bid price
- [ ] Itemized breakdown shows every deduction line item
- [ ] Tax disclaimer is displayed on every calculation result
- [ ] All cost items are editable (user can override defaults)

#### User Value

Prevent the most common beginner mistake: "Celebrated earning 50M KRW, then went negative after taxes." Reverse-calculation mode builds data-driven bidding habits instead of gut-feel pricing.

#### Dependencies

- Upstream: F01 (budget data), F03 (assumed amount data), F06 (market price as expected sale price)
- Downstream: F08 (profit simulation for virtual bids)

---

### F05. Auction Process Checklist & Progress Management

| Item | Detail |
|---|---|
| Priority | P0 (MVP) |
| Pain Points | P3, P8, P9 |
| Deploy Order | 5th |

#### Description

Provide a per-property checklist tracking the 8-step auction process, ensuring beginners follow every step without skipping. This is the service's "backbone" — it drives repetition cycles and prevents critical mistakes through step-skip warnings.

#### Requirements

**(A) Per-Property Progress Tracking:**

- 8-step pipeline: Budget set → Property found → Rights analysis done → Market price checked → Loan confirmed → Inspection done → Bid submitted → Post-winning processing
- Completion check and date recording per step
- Dashboard showing: properties currently being analyzed, completed properties count

**(B) Step-Skip Warnings (safety guards):**

- Attempting to bid without loan confirmation: "You have not completed loan verification. If you fail to pay the balance after winning, you will lose the entire bid deposit (10% of minimum price)."
- Attempting market price check without rights analysis: "Please complete rights analysis first."
- Each warning offers "Proceed anyway" option but clearly states the risk

**(C) Repetition Cycle Promotion:**

- Upon completing (or abandoning) a property analysis: immediately show "Analyze next property" button
- Cumulative analysis count display: "You have analyzed N properties so far"
- Weekly analysis goal setting: "Analyze 3 properties this week" → achievement rate display

**(D) Auction Date Alerts:**

- Calendar integration for watched properties' auction dates with push notifications
- D-3 and D-1 reminders: required items checklist (ID, seal/stamp, deposit cashier's check at 10% of minimum price — single check)

#### Acceptance Criteria

- [ ] Each property has an 8-step pipeline with per-step completion tracking
- [ ] Step completion records the date automatically
- [ ] Dashboard shows active and completed property counts
- [ ] Skipping loan confirmation before bidding triggers a warning with risk description
- [ ] Skipping rights analysis before market price check triggers a warning
- [ ] "Proceed anyway" option exists but risk is explicitly stated
- [ ] "Analyze next property" button appears after completing or abandoning analysis
- [ ] Cumulative analysis count is displayed and updates correctly
- [ ] Weekly goal can be set and achievement rate is tracked
- [ ] Auction date alerts fire at D-3 and D-1 with preparation checklist

#### User Value

The checklist serves as the service backbone, building the habit of "continuously analyzing properties." Step-skip warnings prevent catastrophic mistakes like deposit forfeiture at the system level.

#### Dependencies

- Upstream: F01–F04 (each step corresponds to a feature)
- Downstream: F08 (virtual bid practice integrates with repetition cycle)

---

### F06. Integrated Market Price Dashboard

| Item | Detail |
|---|---|
| Priority | P1 (Early Expansion) |
| Pain Points | P4 |
| Deploy Order | 6th |

#### Description

When a user selects an auction property, show actual transaction prices, listing prices, and distressed-sale prices for comparable properties on a single screen. Includes a gap-rate warning system to prevent beginners from mistaking listing prices for market prices.

#### Requirements

**(A) Data Source Integration:**

- Recent 3-month actual transaction prices (Ministry of Land public data) — displayed with highest priority
- Current listing prices
- Distressed-sale prices (separately highlighted)

**(B) Gap-Rate Warning:**

- Auto-calculate and display gap between listing price and recent actual transaction price: "This listing is +15% above recent actual transaction price"
- Listings with gap rate > 10%: "Caution: Large gap from actual transaction prices" warning label
- Also display appraisal value vs. actual transaction price gap rate

**(C) Comparison Criteria:**

- Same complex same size / nearby similar complex / area average
- Note on floor/orientation/renovation price differences: "Exact floor/view differences require on-site agent verification"

**(D) Trends & Market Indicators:**

- 1–3 year actual transaction price trend graph
- Area supply volume and unsold inventory summary (future price decline risk assessment)
- Listing ratio (current listings / total units) display

**(E) Integration:**

- One-click market price lookup from auction property detail page
- Market price data auto-feeds F04 net profit calculator's "expected sale price"

#### Acceptance Criteria

- [ ] Actual transaction prices (last 3 months) are displayed with priority
- [ ] Listing prices and distressed-sale prices are shown separately
- [ ] Gap rate between listing and actual transaction price is calculated and displayed
- [ ] Gap rate > 10% triggers a warning label
- [ ] Comparable data shows same-complex, nearby, and area-average tiers
- [ ] Price trend graph covers 1–3 year range
- [ ] Supply/unsold data is summarized for the relevant area
- [ ] Market price auto-feeds F04 expected sale price field

#### User Value

Eliminate the hassle of checking multiple proptech apps separately, and prevent the mistake of overbidding by mistaking listing prices for actual market prices through gap-rate warnings.

#### Dependencies

- Upstream: F02 (property selection)
- Downstream: F04 (market price as expected sale price)

---

### F07. Pre-Auction Loan Matching Service

| Item | Detail |
|---|---|
| Priority | P1 (Early Expansion) |
| Pain Points | P5 |
| Deploy Order | 7th |

#### Description

Input the user's credit, income, existing loans, and target property information to pre-check auction balance loan eligibility, estimated limits, and interest rates. The minimum "loan disqualification warning" is already handled in F02 (P0); this feature focuses on active loan condition comparison and matching.

#### Requirements

**(A) User Input:**

- Annual income, credit score (or grade), existing loan balance, DSR-related information

**(B) Policy Loan Auto-Check:**

- First-time buyer Didimdol loan (LTV 80%), Newborn special loan, etc. — auto-determine eligibility

**(C) "Max Biddable Amount Based on My Conditions" Calculation:**

- Combine F01 onboarding budget with loan limit to precisely calibrate actual biddable range

**(D) Loan Consultant Network Connection:**

- Auto-request anonymous quotes from partner loan consultants → provide limit/rate comparison list
- User selects and directly contacts the consultant with the best terms

#### Acceptance Criteria

- [ ] User can input income, credit, and existing loan information
- [ ] Policy loan eligibility (Didimdol, Newborn special) is automatically checked
- [ ] Max biddable amount reflects both budget (F01) and loan limit
- [ ] Anonymous quote requests are sent to partner consultants
- [ ] Comparison list shows limit and rate from multiple consultants
- [ ] User can select and initiate contact with a consultant

#### User Value

Eliminate the hassle of collecting dozens of business cards at the courthouse, and prevent the catastrophic risk of forfeiting the bid deposit (10% of minimum price) due to balance payment failure after winning.

#### Dependencies

- Upstream: F01 (budget data), F02 (loan-risk flagged properties)
- Downstream: F05 (loan confirmation step in checklist)

---

### F08. Virtual Bid Simulation

| Item | Detail |
|---|---|
| Priority | P1 (Early Expansion) |
| Pain Points | P9 |
| Deploy Order | 8th |

#### Description

Using completed past auction data, users can practice submitting virtual bids and compare their bid price against actual results (winning/losing, estimated profit). This feature was added based on expert feedback: "What beginners fear most is the first real bid with real money."

#### Requirements

**(A) Past Auction Data-Based Virtual Bidding:**

- Provide completed "beginner-safe-rated" auction properties as practice cases
- User enters bid price → "Your bid: ○○M KRW / Actual winning bid: ○○M KRW → Won/Lost"

**(B) Profit Simulation Integration:**

- If won: link with F04 net profit calculator → "If you won at this price, net profit would have been ○○M KRW"
- If actual subsequent sale history exists, also compare with realized profit

**(C) Repetition Training Promotion:**

- Cumulative practice count: "You have completed N virtual bids so far"
- Accuracy stats: percentage of bids within ±10% of actual winning price
- Integration with F05 checklist's "analysis repetition cycle"

#### Acceptance Criteria

- [ ] Completed past auction properties are available as practice cases
- [ ] Practice cases are filtered to "beginner-safe" rated properties
- [ ] User can input a bid price and see win/loss result against actual winning bid
- [ ] Winning scenarios show net profit calculation via F04 integration
- [ ] Cumulative practice count and accuracy statistics are tracked
- [ ] Practice activity connects to F05 repetition cycle metrics

#### User Value

Build practical intuition before risking real money, and lower the psychological barrier to the first real bid.

#### Dependencies

- Upstream: F04 (profit calculation), F02 (safety rating data)
- Downstream: F05 (repetition cycle integration)

---

### F09. Online Pre-Inspection Assistant

| Item | Detail |
|---|---|
| Priority | P2 (Growth) |
| Pain Points | P6 |
| Deploy Order | 9th |

#### Description

Before visiting in person, provide integrated online information about the property's external environment, view, sunlight, and building condition to efficiently screen inspection candidates. This is explicitly a pre-screening tool — it does not replace on-site inspection.

#### Requirements

**(A) Fixed Notice (mandatory):**

- Display at top upon feature entry: "This feature is for pre-inspection screening. Final decisions must be made through on-site verification."

**(B) Property Environment Information:**

- Street view / satellite image integration: embed street view of property location on detail page
- View/sunlight pre-analysis: property orientation (compass direction), distance to adjacent buildings → "Wall-view Risk" pre-warning
- Building registry parsing: elevator availability, construction year, structure type (reinforced concrete, etc.) auto-display

**(C) Surrounding Infrastructure Summary:**

- Station proximity, school district, amenities — basic location information
- Villa/standalone apartment density, recent 1-year transaction turnover rate display

**(D) Nearby Real Estate Agent List:**

- Auto-display list and contact information of nearby and station-area real estate agencies
- Guide: "Visit 2–3 or more agencies during inspection to cross-check achievable sale price"

#### Acceptance Criteria

- [ ] Fixed "pre-screening only" notice is always visible at top
- [ ] Street view is embedded on property detail page
- [ ] Building orientation and adjacent-building distance analysis is provided
- [ ] Building registry data (elevator, year, structure) is auto-parsed and displayed
- [ ] Nearby infrastructure summary is shown (station, schools, amenities)
- [ ] Nearby real estate agent list with contacts is displayed
- [ ] Cross-check guidance message is shown alongside agent list

#### User Value

Office workers can pre-screen promising properties with minimal use of vacation days, while being guided to recognize the importance of on-site verification and act on it.

#### Dependencies

- Upstream: F02 (property data)
- Downstream: F05 (inspection completion step in checklist)

---

### F10. Eviction Scenario Guide & Document Auto-Generation

| Item | Detail |
|---|---|
| Priority | P2 (Growth) |
| Pain Points | P7 |
| Deploy Order | 10th |

#### Description

Predict eviction difficulty before winning and provide situation-specific response scenarios regardless of difficulty level — "here's specifically what to do." Auto-generate required legal documents. The focus is on actionable guidance, not just difficulty labeling.

#### Requirements

**(A) Eviction Difficulty Labeling:**

- Auto-classify as High/Medium/Low based on dividend simulation (F03 integration) results
- Display eviction difficulty icon on property search list

**(B) Situation-Specific Response Scenario Guide:**

| Situation | Difficulty | Scenario Guide |
|---|---|---|
| Tenant will receive 100% dividend | Low | "Get the tenant to sign a vacancy confirmation. They need this document to receive their money, so they will cooperate." |
| Small-sum tenant with priority repayment | Medium | "Part of the deposit is resolved through dividend distribution. Negotiate moving costs for the remainder. Benchmark: approx. 100K KRW per pyeong." |
| Deposit fully unrecoverable (no opposing power) | High | "Resistance is possible. (1) Attempt moving cost negotiation → (2) If no agreement, file delivery order → (3) Finally resolved through court-enforced eviction. This is a legal process handled by the court." |
| Debtor (owner) residing | Medium-High | "Send certified notice → File delivery order → Execute forced eviction, in this order." |

**(C) Document Auto-Generation:**

- Auto-generate upon entering case number and user information: certified notice, delivery order application, eviction agreement
- Tone selection: Firm tone (legal procedure notice) / Soft negotiation tone (moving cost offer)
- One-click navigation from scenario guide to corresponding document

#### Acceptance Criteria

- [ ] Eviction difficulty (High/Medium/Low) is auto-determined from dividend simulation
- [ ] Difficulty icon is visible on property search list
- [ ] Each difficulty level shows the corresponding scenario guide with actionable steps
- [ ] Certified notice, delivery order, and eviction agreement are auto-generated from case number input
- [ ] Tone selection (firm/soft) produces appropriately worded documents
- [ ] Scenario guide links directly to relevant document generation

#### User Value

Reframe eviction from "something frightening" to "something resolved by following a procedure." Situation-specific action steps connected to documents maximize execution capability.

#### Dependencies

- Upstream: F03 (dividend simulation data)
- Downstream: F05 (post-winning processing step in checklist)

---

### F11. Expert 1:1 Feedback Connection (Mentoring Marketplace)

| Item | Detail |
|---|---|
| Priority | P3 (Advanced) |
| Pain Points | P1, P7 |
| Deploy Order | 11th |

#### Description

Provide a channel for users who lack confidence in automated analysis results to request paid 1:1 feedback from verified auction experts. Includes expert verification system and AI-vs-expert analysis comparison to prevent fraudulent consulting firms from entering the platform.

#### Requirements

**(A) Expert Verification System (mandatory):**

- Credential verification upon expert registration: actual winning history, relevant certifications, activity history
- User review and rating system
- Feedback quality monitoring: warning/removal criteria for experts providing inaccurate analysis

**(B) Feedback Request Types:**

- Rights analysis verification, bid price appropriateness review, eviction strategy consultation

**(C) AI vs. Expert Analysis Comparison:**

- Share service's AI analysis report (F03) with the expert to improve feedback efficiency
- When expert analysis differs from AI analysis, explicitly show the difference and reasoning to the user
- Guide users to understand judgment basis rather than blindly following experts

**(D) Transparent Pricing:**

- Per-case or monthly subscription plans, with upfront quote confirmation

#### Acceptance Criteria

- [ ] Expert registration requires credential verification (winning history, certifications)
- [ ] User review and rating system is functional
- [ ] Quality monitoring system can flag and remove underperforming experts
- [ ] Users can request feedback for rights analysis, bid pricing, and eviction strategy
- [ ] AI report is shareable with the matched expert
- [ ] Differences between AI and expert analysis are explicitly shown with reasoning
- [ ] Pricing is transparently displayed before purchase

#### User Value

Complement AI analysis limitations with expert review while preventing damage from fraudulent firms through the verification system.

#### Dependencies

- Upstream: F03 (AI analysis report shared with expert)
- Downstream: None (callable from any step via F05 checklist)

---

## 5. Priority & Deployment Strategy

### Priority Summary

| Priority | Feature ID | Feature Name | Deploy Order | P0 Selection Rationale |
|---|---|---|---|---|
| P0 (MVP) | F01 | Onboarding Budget Setup | 1st | Service entry flow. Prerequisite for property search |
| P0 (MVP) | F02 | Safe Property Filtering (Legal + Resale + Loan Risk) | 2nd | Loss prevention first line of defense. 3-axis filter is differentiator |
| P0 (MVP) | F03 | Rights Analysis Report + Original Document | 3rd | Core paid feature. HUG opportunity detection is key differentiator |
| P0 (MVP) | F04 | Net Profit Calculator + Reverse Mode | 4th | Tax mistake prevention = as critical as rights analysis mistakes |
| P0 (MVP) | F05 | Process Checklist | 5th | Service backbone. Repetition mastery = retention core |
| P1 (Early Expansion) | F06 | Integrated Market Price (Gap-Rate Warning) | 6th | Bid price evidence. Listing-price overconfidence prevention |
| P1 (Early Expansion) | F07 | Pre-Auction Loan Matching | 7th | Deposit forfeiture prevention. B2B revenue model |
| P1 (Early Expansion) | F08 | Virtual Bid Simulation | 8th | First-bid fear reduction. Practical intuition training |
| P2 (Growth) | F09 | Online Pre-Inspection | 9th | Office worker acquisition. "Cannot replace inspection" explicit |
| P2 (Growth) | F10 | Eviction Scenario Guide + Documents | 10th | Psychological barrier reduction. Situation-specific response is key |
| P3 (Advanced) | F11 | Expert Mentoring Connection | 11th | Verification system prerequisite. Trust risk management |

### Deployment Principle

1. Each feature is an independent deliverable — fully completed before the next begins
2. Upon completion of one feature, the next feature's schedule is separately planned
3. Deploy order reflects both priority and dependency chain
4. The goal is to build the complete service incrementally, one perfect feature at a time
5. Cross-priority dependencies (e.g., F04 references F06 market price data) are designed as optional integrations — the feature works standalone at launch, and the integration activates when the upstream feature is deployed later

---

## 6. Feature Dependency Map

```
[Service Entry]
 |
 v
F01 Onboarding Budget Setup ──────────────────────────────┐
 |                                                         |
 v                                                         |
F02 Safe Property Filtering ──→ F06 Integrated Market Price|
|   (Legal+Resale+Loan Risk)    |   (Gap-Rate Warning)    |
|                               v                          |
v                          F04 Net Profit Calculator ←─────┘
F03 Rights Analysis Report      |   (Reverse Mode)
|   (Original Doc Parallel)     |
|                               v
├── F10 Eviction Scenario  F07 Pre-Auction Loan Matching
|   (Dividend Simulation        |
|    Integration)                |
v                               v
F09 Online Pre-Inspection  F05 Process Checklist ←── Backbone
|                          |   (Step-Skip Warnings)
|                          |   (Repetition Cycle)
|                          |
|                          ├── F08 Virtual Bid Simulation
|                          |   (Past Data Practice)
|                          |
v                          v
[On-Site Inspection]   F11 Expert Feedback Connection
                           (Callable from any step)
```

### Key Dependency Rules

- F02 requires F01 (budget-based search filter)
- F03 requires F02 (property data feed)
- F04 requires F03 (assumed amount data) and F06 (expected sale price)
- F05 orchestrates F01–F04 as pipeline steps
- F10 requires F03 (dividend simulation for eviction difficulty)
- F07 refines F01 (loan-adjusted max bid)
- F08 uses F04 (profit calculation for virtual bids)
- F11 shares F03 (AI report with experts)

---

## 7. Monetization Model

| Feature | Pricing Model | Rationale |
|---|---|---|
| F01 Onboarding | Free | User acquisition |
| F02 Safe Filter (basic) | Free | User acquisition & trust building |
| F02 Safe Filter (detailed basis) | Premium subscription | Detailed risk verdict reports |
| F03 Rights Analysis Report | Per-use or monthly subscription | Core consulting-replacement feature |
| F03 HUG Opportunity Properties | Premium only | Differentiated profit opportunity |
| F04 Net Profit Calculator (reverse mode) | Premium subscription | Expert bid-pricing replacement |
| F05 Checklist | Free | Retention & repeat usage |
| F06 Integrated Market Price | Free basic / Premium detailed | Data value-add |
| F07 Loan Matching | B2B commission (consultant fee) | User free, consultant pays |
| F08 Virtual Simulation | Free basic / Premium analysis | Acquisition & education |
| F10 Document Generation | Per-use | Legal document value-add |
| F11 Expert Connection | Per-use (platform fee) | Marketplace model |
