# TODOS

Deferred work captured by `/plan-eng-review`. Each item includes context so a future session can pick it up without losing the reasoning.

---

## Post-launch follow-ups (case-number direct registration)

### Auto-discovery fallback (60-court iteration)

**What**: When `court_code` is not provided in the case-number-add form, iterate `priority_court_codes` (Seoul → Gyeonggi → rest, 60 entries) via the same `pgj15A/selectAuctnCsSrchRslt.on` HTTP endpoint, with adaptive backoff (BASE_DELAY 0.5s → MAX_DELAY 5s, abort after 5 consecutive HTTP errors).

**Why**: Some users know the case_number from external sources (newspapers, brokerage listings) but not which court holds it. Today they have to look it up separately. The fallback closes that gap.

**Pros**: Removes a UX dead-end for the user-without-court-knowledge segment. Implementation pattern is well-specified (recoverable from `git show 4521efb^:app/services/case_search_service.rb`'s `discover_court` method).

**Cons**: Worst-case 60s wait under sustained court-site degradation holds a Puma worker. On Cafe24 4GB single-server with 5 default Puma threads, multiple concurrent submissions could exhaust workers. Required to ship as ActiveJob + Turbo Stream broadcast, not sync — adds background-worker infra (Solid Queue or similar).

**Context**: Originally implemented in commit `c15c23a` (2026-04-09), removed in `4521efb` (2026-04-11) as part of MVP scope reduction. Current `/plan-eng-review` (2026-05-04) explicitly dropped it from the revival PR for launch-timing reasons.

**Depends on / blocked by**: Solid Queue (or equivalent) deployed on Cafe24. Decision needed on background-worker infrastructure for the production deployment.

---

### Property refresh from court auction site

**What**: Add `Property#refresh_from_court_auction!` instance method. Uses stored `court_code` + `case_number` to re-call `pgj15A/selectAuctnCsSrchRslt.on`, re-runs `parse_case_search`, updates Property attributes (status, min_bid_price, failed_bid_count, auction_date, etc.) without losing user-entered data.

**Why**: Auction details change weekly — bid dates shift, failed-bid counts increment, case status changes (진행중 → 종결). Today users must re-search via the criteria flow to see updates, which is wasteful when they already track the property.

**Pros**: Real-time data freshness without forcing users back through criteria search. Most natural pairing with the case-number direct add: same code path, same auth-free HTTP API.

**Cons**: Need to define refresh policy — manual button vs scheduled job vs on-page-view-trigger. Each has different cost/complexity trade-offs.

**Context**: Enabled by A1 migration adding `court_code/court_name` columns to Property in this PR. Without those columns, refresh would require a separate court-discovery step.

**Depends on / blocked by**: The case-number direct registration PR (this design doc) must ship first to populate `court_code` on existing properties via the 1-time backfill.

---
