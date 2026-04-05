# Real Estate Auction Service

A web service for real estate auction beginners in Korea. Guides users through the entire auction process — from budget planning to bidding — with automated risk analysis, profit calculation, and step-by-step checklists.

## What This Service Does

Real estate auctions in Korea offer properties at below-market prices, but beginners face steep barriers: complex legal rights analysis, hidden tax costs, loan uncertainty, and fear of the eviction process. This service eliminates those barriers through automation and structured guidance.

### Core Features (MVP — P0)

| Feature | Description |
|---|---|
| **F01. Onboarding Budget Setup** | 3-step questionnaire after signup to calculate maximum biddable amount based on cash, reserve funds, and expected loan ratio. Results auto-set the property search filter. |
| **F02. Safe Property Filtering** | Auto-identify risky properties across 3 axes — legal risk (liens, statutory superficies), resale risk (new villas, studios), and loan risk (illegal construction) — with a 3-tier safety rating system. |
| **F03. Rights Analysis Report** | Automated analysis of extinguishment base rights, tenant opposing power, and assumed amounts from registry data. AI report always shown alongside original court documents to prevent overconfidence. Detects HUG opportunity properties. |
| **F04. Net Profit Calculator** | Calculate actual bank-deposit profit after all taxes and costs. Reverse mode: input target profit to get maximum bid price. Side-by-side individual vs. trader tax rate comparison. |
| **F05. Process Checklist** | Per-property 8-step pipeline tracking with step-skip warnings (e.g., warns if bidding without loan confirmation). Drives repetition mastery through analysis count tracking and weekly goals. |

### Expansion Features (P1)

| Feature | Description |
|---|---|
| **F06. Market Price Dashboard** | Integrated actual transaction prices, listing prices, and distressed-sale prices with gap-rate warnings to prevent overbidding. |
| **F07. Loan Matching** | Pre-check auction balance loan eligibility and compare terms from partner consultants. |
| **F08. Virtual Bid Simulation** | Practice bidding on completed past auctions to build practical intuition before risking real money. |

### Growth Features (P2–P3)

| Feature | Description |
|---|---|
| **F09. Online Pre-Inspection** | Pre-screen properties online (street view, building data, nearby agents) before on-site visits. |
| **F10. Eviction Scenario Guide** | Situation-specific eviction response guides with auto-generated legal documents. |
| **F11. Expert Mentoring** | Verified expert marketplace for 1:1 feedback on AI analysis results. |

## Design Principles

- **Repetition & Mastery** — Guide users to analyze multiple properties, not just one
- **Overconfidence Prevention** — AI reports always shown with original court documents
- **Respect for Fieldwork** — Online tools are pre-screening only; final decisions require on-site inspection

## Tech Stack

- **Framework**: Ruby on Rails 8.1 (Ruby 3.4.8)
- **Frontend**: Hotwire (Turbo + Stimulus), TailwindCSS, ViewComponent
- **Database**: SQLite + Solid Cache / Queue / Cable
- **Assets**: Propshaft + ImportMap (no Node.js)
- **Deployment**: Docker + Kamal + Thruster

## Getting Started

```bash
bin/setup        # Install dependencies and prepare database
bin/dev          # Start dev server (Puma + CSS/JS watchers)
bin/rails test   # Run tests
bin/ci           # Full CI pipeline (setup, lint, security, tests, seed check)
```

## Documentation

- [SRS v1.0](docs/superpowers/specs/2026-04-05-srs-design.md) — Full requirements specification
- [STANDARDS.md](STANDARDS.md) — Development standards and architecture patterns
- [CLAUDE.md](CLAUDE.md) — AI assistant guidelines
