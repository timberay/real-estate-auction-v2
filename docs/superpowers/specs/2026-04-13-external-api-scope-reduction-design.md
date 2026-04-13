# External API Integration Scope Reduction

**Date:** 2026-04-13
**Status:** Approved
**Supersedes:** `2026-04-12-real-transaction-price-api-design.md` (deleted)

## Context

The app's unique value lies in two capabilities no other tool provides:

1. **LLM-based rights analysis** — extracting legal risk from court auction PDF documents
2. **Auction-specific inspection workflow** — 89-item structured checklist guiding investment decisions

All other data the app planned to integrate (market prices, building ledgers, loan policies, registry documents) is **commodity information** already served better by dedicated free tools Korean real estate investors use daily.

## Decision

### Retain (2 integrations)

| Integration | Reason |
|---|---|
| **LLM PDF Analysis** (Claude, Gemini, etc.) | Core differentiator. No alternative provides automated rights analysis from auction documents. |
| **Court Auction Search** (courtauction.go.kr) | Essential for property registration workflow. Enables search → register → inspect flow. |

### Remove (5 integrations)

| Integration | Planned Cost | Why Remove |
|---|---|---|
| **Real Transaction Price API** (data.go.kr, 3 endpoints) | High — XML parsing, district code mapping, 3 adapter classes, background job | Naver Real Estate, Hogangnono, KB Real Estate provide superior UX with trend charts, maps, and years of history. Our table-based rendering would be an inferior experience. |
| **Building Ledger API** (data.go.kr) | Medium — REST API, field mapping | Seumteo (eais.go.kr) provides free lookup. Only 4 checklist items would be auto-populated. |
| **Government Loan Policy APIs** (FSC, HF, HUG) | Very high — 3 agencies, frequently changing policies | Bank consultations are more accurate and personalized. Policy data goes stale quickly. |
| **Registry APIs** (Tilko, Codef) | Medium — paid ₩1,000~2,000/query | Manual PDF upload + LLM analysis already covers this. Auto-fetching is convenience, not necessity. |
| **IROS Preview** (iros.go.kr) | Low — free but summary only | Insufficient for rights analysis. 1,000/day limit. Not useful without full registry. |

### Guiding Principle

> **Build what no other tool does. For commodity data, let specialized tools handle it.**

The 89 inspection checklist items remain unchanged. Items that previously depended on removed APIs (e.g., market-001 through market-004 from real transaction API) continue to function as manual-entry items — users check external tools and record their assessment.

## Code Cleanup Required

### Files to Delete

- `docs/superpowers/specs/2026-04-12-real-transaction-price-api-design.md` — superseded by this document
- `app/adapters/government_loan_policy_adapter.rb` — stub adapter that just delegates to MockLoanPolicyAdapter

### Code to Modify

- **`app/adapters/loan_policy_adapter.rb`** — remove `:real` branch from factory. Always return `MockLoanPolicyAdapter` (government API will never be implemented).
- **`ApiCredential::PROVIDERS`** — remove `data_go_kr`, `tilko`, `codef`, `iros`, `hyphen` entries. Keep only `court_auction`.
- **Settings UI** — verify removed providers don't render cards in `/settings/data_sources`. Check I18n translation files and view templates for hardcoded provider references.

### Explicitly Retained

- `app/adapters/mock_loan_policy_adapter.rb` — seed data source for loan policies used in onboarding step 3 and budget settings. Not an external API; contains static reference data (경락대출 LTV ratios).

### No Impact

- 89 inspection items — unchanged, manual entry continues
- LLM PDF analysis pipeline — independent
- Court auction search — independent
- Onboarding/budget features — independent

## Retained Integration Architecture

After cleanup, the external integration surface is minimal:

```
┌─────────────────────────────────────┐
│           Application               │
│                                     │
│  ┌──────────┐    ┌───────────────┐  │
│  │ Court    │    │ LLM Adapters  │  │
│  │ Auction  │    │ (5 providers) │  │
│  │ Adapter  │    │               │  │
│  └────┬─────┘    └──────┬────────┘  │
│       │                 │           │
└───────┼─────────────────┼───────────┘
        │                 │
        ▼                 ▼
  courtauction.go.kr   Claude/Gemini/
                       OpenAI/Ollama/
                       OpenRouter
```

## Impact on Feature Roadmap

| Feature | Previous Dependency | After This Change |
|---|---|---|
| **F02 Property Inspection** | Real transaction API for 4 auto-judgment items | 4 items become manual-only (no functionality loss) |
| **F03 Net Profit Calculator** (P1) | Real transaction API for expected sale price | User inputs sale price manually (more accurate — reflects user judgment) |
| **F04 Market Dashboard** (P1) | Real transaction API as data source | Feature removed — see F04 Reconsideration below |
| **F05 Report PDF Export** (P1) | No dependency on removed APIs | Unaffected |
| **F06 Eviction Guide** (P2) | No dependency on removed APIs | Unaffected |

### F04 Removal

F04 (Integrated Market Price Dashboard) loses its primary data source with the real transaction API removal. Since users already use Naver Real Estate, Hogangnono, and KB Real Estate for market data — tools that provide far superior visualization and depth — rebuilding this as a link aggregator adds minimal value. **F04 is removed from the roadmap.**

## SRS Update Needed

The SRS v2.0 should be updated to reflect:

- F04 removed from roadmap
- F02 auto-judgment items reduced (4 market items → manual only)
- External API dependency list simplified
- Data provider implementation phases simplified to: Court Auction (done) + LLM (done)
