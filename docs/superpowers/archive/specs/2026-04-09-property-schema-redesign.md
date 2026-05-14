# Property Schema Redesign — Full Court Auction Data Storage

> **Date:** 2026-04-09
> **Status:** Approved
> **Scope:** DB schema redesign, ResponseParser rewrite, seed data migration, InspectionRunner rule update

## Problem

The current `properties` table stores only 6 DB columns + a `raw_data` JSON blob with 17 extracted fields. The court auction APIs provide ~95 property-relevant fields across two endpoints, but most are discarded. This makes it impossible to:

1. Query/filter by detailed property attributes (area, coordinates, share info)
2. Display auction history (schedule, price changes per round)
3. Use land/building details for analysis
4. Leverage appraisal data for investment evaluation

## Decision

Replace the single `properties` table + `raw_data` JSON with 5 normalized tables that store all useful fields from both the search API (1st) and detail API (2nd).

## Data Sources

| API | Endpoint | Fields (total) | Fields (property) | Fields (stored) |
|-----|----------|---------------|-------------------|-----------------|
| 1st Search | `searchControllerMain.on` | 117 | 42 | 24 |
| 2nd Detail | `selectAuctnCsSrchRslt.on` | ~170 | 78 | 32 |
| **Total** | | ~287 | ~95 | **56** |

## Excluded Fields (by decision)

`jpDeptNm`, `tel`, `daepyoLotno`, `areaList`, `jimokList`, `maxArea`, `notifyMinmaePrice1~4`, `notifyMinmaePriceRate1~2`, `maeAmt`, `ipchalGbncd`, `maegyuljGiil`, `maePlace`, `ipgiganFday/Tday`, `dupSaNo`, `rdNm`, `buldNo`, `rdAddrSub`, `jiwonNm`, `csRcptYmd`, `csCmdcYmd`, `prchDposRate`, `maeGiil+maeHh1`, `byungSaNo`, `gdsSpcfcWrtYmd`, `dspslStkNmrtVal`, `dspslStkDnmnVal`

Also excluded: `csPicLst` (base64 images), `picDvsIndvdCnt`, `gdsRletStLtnoLstAll` (duplicate addresses), `bldSdtrDtlLstAll` (redundant with building_structure).

## Schema Design

### Table 1: `properties` — 24 columns

Core identification, pricing, location, and status.

| Column | Type | Source Field | Purpose |
|--------|------|-------------|---------|
| `id` | bigint PK | — | Primary key |
| `case_number` | string, unique, not null | `srnSaNo` | Case number (2024타경1423) |
| `case_type` | string | `csNm` | Case type (부동산임의경매) |
| `claim_amount` | bigint | `clmAmt` | Claim amount |
| `property_type` | string | `dspslUsgNm` | Usage name (아파트) |
| `property_usage_code` | string | `auctnGdsUsgCd` | Usage code (01=apartment) |
| `status` | string | `mulJinYn`+`mulStatcd` | Proceeding status |
| `address` | string | `printSt` | Full display address |
| `sido` | string | `hjguSido` | Province/City |
| `sigungu` | string | `hjguSigu` | District |
| `dong` | string | `hjguDong` | Town/Village |
| `building_name` | string | `buldNm` | Building name |
| `building_detail` | string | `buldList`/`bldDtlDts` | Unit detail (동·층·호) |
| `building_structure` | string | `pjbBuldList` | Structure & area text |
| `exclusive_area` | decimal | `minArea` | Exclusive area (㎡) |
| `land_category` | string | `rletDvsDts` | Real estate category (전유/토지/일반건물) |
| `appraisal_price` | bigint | `gamevalAmt` | Appraisal value |
| `min_bid_price` | bigint | `minmaePrice` | Current minimum bid price |
| `failed_bid_count` | integer | `yuchalCnt` | Failed auction count |
| `view_count` | integer | `inqCnt` | View count |
| `interest_count` | integer | `gwansMulRegCnt` | Interest registration count |
| `latitude` | decimal(10,7) | `wgs84Ycordi` | GPS latitude |
| `longitude` | decimal(10,7) | `wgs84Xcordi` | GPS longitude |
| `special_conditions_code` | string | `spJogCd` | Special sale conditions code |
| `remarks` | text | `mulBigo` | Property remarks (from search) |
| `created_at` | datetime | — | |
| `updated_at` | datetime | — | |

**Indexes:** `case_number` (unique), `sido+sigungu+dong`, `property_type`, `appraisal_price`, `min_bid_price`

### Table 2: `property_sale_details` — 12 columns (1:1 with properties)

Sale specification document data — core source for rights analysis and InspectionRunner.

| Column | Type | Source Field | Purpose |
|--------|------|-------------|---------|
| `id` | bigint PK | — | Primary key |
| `property_id` | bigint FK, unique | — | References properties |
| `non_extinguished_rights` | text | `ndstrcRghCtt` | Rights not extinguished by sale |
| `superficies_details` | text | `sprfcExstcDts` | Superficies existence details |
| `specification_remarks` | text | `gdsSpcfcRmk` | Sale spec document remarks |
| `senior_mortgage_basis` | string | `tprtyRnkHypthcStngDts` | Senior mortgage date/type |
| `goods_remarks` | text | `dspslGdsRmk` | Auction goods remarks |
| `dividend_demand_deadline` | date | `dstrtDemnLstprdYmd` | Dividend demand deadline |
| `share_description` | text | `dspslStkCtt` | Share sale description |
| `price_round_1` | bigint | `fstPbancLwsDspslPrc` | Round 1 minimum price |
| `price_round_2` | bigint | `scndPbancLwsDspslPrc` | Round 2 minimum price |
| `price_round_3` | bigint | `thrdPbancLwsDspslPrc` | Round 3 minimum price |
| `price_round_4` | bigint | `fothPbancLwsDspslPrc` | Round 4 minimum price |
| `created_at` | datetime | — | |
| `updated_at` | datetime | — | |

### Table 3: `auction_schedules` — 10 columns (1:N with properties)

Auction date history — schedule, results, and price per round.

| Column | Type | Source Field | Purpose |
|--------|------|-------------|---------|
| `id` | bigint PK | — | Primary key |
| `property_id` | bigint FK | — | References properties |
| `schedule_date` | date | `dxdyYmd` | Schedule date |
| `schedule_time` | string | `dxdyHm` | Schedule time (HHMM) |
| `bid_start_date` | date | `bidBgngYmd` | Bid start (period bidding) |
| `bid_end_date` | date | `bidEndYmd` | Bid end (period bidding) |
| `place` | string | `dxdyPlcNm` | Location |
| `schedule_type` | string | `auctnDxdyKndCd` | Type (01=sale, 02=decision) |
| `result_code` | string | `auctnDxdyRsltCd` | Result (successful/failed) |
| `min_price` | bigint | `tsLwsDspslPrc` | Minimum price for this round |
| `sale_amount` | bigint | `dspslAmt` | Winning bid amount |
| `created_at` | datetime | — | |
| `updated_at` | datetime | — | |

**Indexes:** `property_id`, `schedule_date`

### Table 4: `land_details` — 7 columns (1:N with properties)

Land parcel information for multi-lot properties.

| Column | Type | Source Field | Purpose |
|--------|------|-------------|---------|
| `id` | bigint PK | — | Primary key |
| `property_id` | bigint FK | — | References properties |
| `land_type` | string | `rletDvsDts` | Category (전유/토지) |
| `land_area` | string | `landArDts` | Area description (22095.6㎡) |
| `land_category` | string | `landLdcgDts` | Land category (대/전/답) |
| `share_ratio` | string | `NmrtVal/DnmnVal` | Share ratio (11.236/6736.2) |
| `address` | string | `rletIndctDts` | Land address |
| `lot_number` | string | `rgltLandLtnoAddr` | Lot number |
| `created_at` | datetime | — | |
| `updated_at` | datetime | — | |

### Table 5: `appraisal_points` — 3 columns (1:N with properties)

Appraisal evaluation key points (typically 10 items per property).

| Column | Type | Source Field | Purpose |
|--------|------|-------------|---------|
| `id` | bigint PK | — | Primary key |
| `property_id` | bigint FK | — | References properties |
| `item_code` | string | `aeeWevlMnpntItmCd` | Item type code |
| `content` | text | `aeeWevlMnpntCtt` | Evaluation content |
| `created_at` | datetime | — | |
| `updated_at` | datetime | — | |

**Known item codes:**
- `00083001` — Location & surroundings (위치 및 주위환경)
- `00083003` — Transportation (교통상황)
- `00083005` — Road access (인접 도로상태)
- `00083006` — Usage status (이용상태)
- `00083009` — Land shape & usage (토지의 형상 및 이용상태)
- `00083011` — Land use plan (토지이용계획 및 제한상태)
- `00083014` — Discrepancy with records (공부와의 차이)
- `00083015` — Building structure (건물의 구조)
- `00083017` — Facilities (설비내역)
- `00083026` — Lease & other (임대관계 및 기타)

## Table Relationships

```
properties (1)
  ├── property_sale_details (1:1) — rights analysis core
  ├── auction_schedules (1:N) — date history
  ├── land_details (1:N) — land parcels
  └── appraisal_points (1:N) — appraisal evaluation
```

Existing relationships preserved:
```
properties (1)
  ├── user_properties (1:N) — user ↔ property join
  ├── inspection_results (1:N) — checklist answers
  └── rights_analysis_reports (1:N) — analysis reports
```

## Migration Strategy

1. Create 4 new tables (`property_sale_details`, `auction_schedules`, `land_details`, `appraisal_points`)
2. Alter `properties` table: add new columns, remove `raw_data`
3. Update `ResponseParser` to populate all tables
4. Update `seeds.rb` and `real_properties.json` seed data
5. Update `InspectionRunner` DETECTION_RULES to read from new column paths
6. Update `SourceDocViewerComponent` to use new tables
7. Update `PropertyDataSyncService` to persist to all tables

## InspectionRunner Impact

After migration, DETECTION_RULES will read from structured columns instead of `raw_data` JSON:

| Rule | Before (raw_data path) | After (column path) |
|------|----------------------|---------------------|
| `rights-002` | `raw.dig("court_auction", "non_extinguished_rights")` | `property.sale_detail.non_extinguished_rights` |
| `rights-011` | `raw.dig("court_auction", "remarks")` | `property.remarks` + `property.sale_detail.specification_remarks` + `property.sale_detail.goods_remarks` |
| `property-002` | `raw.dig("court_auction", "wall_partition_issue")` | Text analysis on `sale_detail.specification_remarks` |
| `rights-019` | `raw.dig("court_auction", "separate_land_registry")` | `property.land_category != "전유"` |
| `rights-020` | `raw.dig("court_auction", "lien_reported")` | Text analysis on combined remarks |
| `resale-003` | `raw.dig("court_auction", "floor_info")` | `property.building_detail` |
| `property-001` | `raw.dig("court_auction", "is_partial_share")` | `property.sale_detail.share_description.present?` |

## Out of Scope

- Tenant data (`tenants`) — requires 매각물건명세서 PDF/image OCR, not available as structured data
- Use approval (`use_approval`) — requires 건축물대장 API (DataGoKr provider)
- Registry transcript data — separate provider (iros/tilko)
