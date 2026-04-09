# Checklist-to-Field Mapping Analysis

> Analysis of how court_auction structured fields map to the 89 checklist items in `db/seeds/checklist_items_summary.json`, determining which items can be auto-answered.

**Scope:** Only court_auction API fields (56 columns across 5 tables). Building ledger, registry transcript, and external data sources are out of scope.

**Reference:** Field definitions from `docs/superpowers/plans/2026-04-09-property-schema-redesign.md`

---

## Summary

| Grade | Count | Description |
|-------|-------|-------------|
| **Auto** | 10 | court_auction fields fully determine yes/no answer |
| **Partial** | 7 | court_auction fields provide hints or partial conditions |
| **Manual** | 72 | court_auction data insufficient — requires external data, on-site inspection, or user input |

**Coverage: 11.2% auto, 19.1% with partial assistance**

### Nil Handling Principle

When court_auction text fields (remarks, specification_remarks, goods_remarks, etc.) are blank or the `sale_detail` record is absent, the item is treated as **safe (has_risk: false)** — not as unknown. Rationale: if the court's sale specification document contains no mention of a risk, that risk is considered absent.

This principle applies to: `rights-002`, `rights-011`, `property-002`, `rights-020`.

---

## Auto Grade — 10 Items

Items where court_auction fields are sufficient for automatic yes/no determination.

### rights-002 — 인수 권리 유무

- **Question:** 매각물건명세서 '소멸되지 아니하는 것' 비고란에 낙찰자가 인수할 권리 기재가 없는 깨끗한 물건입니까?
- **Tab:** 권리분석
- **Fields:** `sale_detail.non_extinguished_rights`
- **Logic:** `text.present?` → `has_risk: true`
- **Nil:** `sale_detail` absent → `has_risk: false` (no record = no rights to assume)
- **yes_means_safe:** true (default)

### rights-011 — 유치권·법정지상권 기재

- **Question:** 매각물건명세서 비고란에 유치권 또는 법정지상권 기재가 있습니까?
- **Tab:** 권리분석
- **Fields:** `property.remarks` + `sale_detail.specification_remarks` + `sale_detail.goods_remarks` + `sale_detail.superficies_details`
- **Logic:** Combined text matches `/유치권|법정지상권/` → `has_risk: true`
- **Nil:** All fields blank → `has_risk: false`
- **yes_means_safe:** false
- **Note:** `superficies_details` is a dedicated field for 법정지상권, added in schema redesign.

### property-002 — 벽체 구분·불법 구조변경

- **Question:** 호실 간 벽체 구분이 불명확하거나 불법 구조변경이 있습니까?
- **Tab:** 물건분석
- **Fields:** `property.remarks` + `sale_detail.specification_remarks` + `sale_detail.goods_remarks`
- **Logic:** Combined text matches `/벽체|구조변경|불법.*증축|불법.*개축/` → `has_risk: true`
- **Nil:** All fields blank → `has_risk: false`
- **yes_means_safe:** false

### rights-019 — 토지·건물 일체 매각

- **Question:** 아파트이거나, 토지와 건물이 일체로 매각되는 물건입니까?
- **Tab:** 권리분석
- **Fields:** `property.property_type` + `property.land_category`
- **Logic:** `property_type == "아파트"` → `has_risk: false`. Otherwise `land_category == "전유"` → `has_risk: false`. Neither → `has_risk: true`
- **Nil:** `land_category` nil → `nil` (cannot determine)
- **yes_means_safe:** true

### rights-020 — 유치권 신고

- **Question:** 현황조사서에 유치권 신고 표시가 있습니까?
- **Tab:** 권리분석
- **Fields:** `property.remarks` + `sale_detail.specification_remarks` + `sale_detail.goods_remarks`
- **Logic:** Combined text matches `/유치권/` → `has_risk: true`
- **Nil:** All fields blank → `has_risk: false`
- **yes_means_safe:** false
- **Note:** Overlaps with rights-011 but checks only 유치권 (not 법정지상권). Court auction remarks often reflect 현황조사서 findings.

### property-006 — 물건 종류 아파트 여부

- **Question:** 입찰하려는 경매 물건의 종류가 '아파트'입니까?
- **Tab:** 물건분석
- **Fields:** `property.property_type`
- **Logic:** `property_type == "아파트"` → `has_risk: false`
- **Nil:** Unlikely (required field from search API)
- **yes_means_safe:** true

### resale-003 — 지상층 위치

- **Question:** 해당 물건이 지상층에 위치합니까?
- **Tab:** 물건분석
- **Fields:** `property.building_detail`
- **Logic:** Matches `/지하|반지하/` AND does NOT match `/지상/` → `has_risk: true`
- **Nil:** `building_detail` blank → `nil`
- **yes_means_safe:** true

### property-001 — 비지분 물건

- **Question:** 온전한 소유권을 취득할 수 있는 일반(비지분) 물건입니까?
- **Tab:** 물건분석
- **Fields:** `sale_detail.share_description`
- **Logic:** `share_description.present?` → `has_risk: true` (partial share sale)
- **Nil:** `sale_detail` nil → `nil`
- **yes_means_safe:** true

### tax-006 — 전용면적 85㎡ 미만

- **Question:** 주택의 전용면적이 85㎡(약 25평) 미만입니까?
- **Tab:** 수익분석
- **Fields:** `property.exclusive_area`
- **Logic:** `exclusive_area < 85` → `has_risk: false` (VAT exempt)
- **Nil:** `exclusive_area` nil or 0 → `nil`
- **yes_means_safe:** true

### market-012 — 조회수 500회 미만

- **Question:** 경매 사이트에 표시된 해당 물건의 조회수가 500회 미만입니까?
- **Tab:** 수익분석
- **Fields:** `property.view_count`
- **Logic:** `view_count < 500` → `has_risk: false` (low competition = favorable)
- **Nil:** Unlikely (default: 0)
- **yes_means_safe:** true

---

## Partial Grade — 7 Items

Items where court_auction fields provide partial conditions or supplementary information, but cannot fully determine the answer.

### rights-005 — 사용 승인 정상 건물

- **Question:** 매각물건명세서에 건축법상 사용 승인을 받은 정상 건물로 기재되어 있습니까?
- **Tab:** 권리분석
- **Fields:** `sale_detail.specification_remarks` + `sale_detail.goods_remarks` + `appraisal_points[].content`
- **Logic:** Text matches `/무허가|미등기|사용승인.*미|허가.*미취득/` → `has_risk: true`
- **Limitation:** No dedicated field for use_approval. Only detects risk when explicitly mentioned in text. Absence of keywords does NOT confirm safety → returns `nil`.
- **Automation level:** Risk detection only; safety confirmation impossible.

### inspect-001 — 감정평가서 특이사항

- **Question:** 감정평가서 특이사항에 중대한 문제가 기재되어 있습니까?
- **Tab:** 현장확인
- **Fields:** `appraisal_points[].content`
- **Logic:** Combined content matches `/불법.*증축|무허가|환경오염|면적.*불일치|균열|누수|침수/` → `has_risk: true`
- **Limitation:** Only "key points" summary is collected, not full appraisal report. Keyword miss → `nil`.
- **Automation level:** Major keyword-based risk signal detection.
- **yes_means_safe:** false

### inspect-004 — 오피스텔 주거/업무 용도

- **Question:** 오피스텔이 아니거나, 관할 구청에서 주거용/업무용을 확인했습니까?
- **Tab:** 현장확인
- **Fields:** `property.property_type`
- **Logic:** `property_type != "오피스텔"` → `has_risk: false` (not applicable). If 오피스텔 → `nil` (requires 구청 confirmation).
- **Limitation:** Auto-clears non-오피스텔 properties only.
- **Automation level:** First condition only; 오피스텔 requires manual action_confirm.

### market-006 — 단지형 건물 여부

- **Question:** 단독(나홀로) 건물이 아닌 단지형 아파트(또는 오피스텔·빌라 등)입니까?
- **Tab:** 수익분석
- **Fields:** `property.property_type` + `property.building_name`
- **Logic:** `property_type == "아파트"` AND `building_name.present?` → `has_risk: false` (complex-type). Otherwise → `nil`.
- **Limitation:** For 빌라·오피스텔, `building_name` presence alone does not confirm complex-type.
- **Automation level:** Apartment + complex name combination only.

### rights-021 — 전세사기 피해자 우선매수권

- **Question:** 전세사기 피해자의 우선매수권 행사 가능성이 있습니까?
- **Tab:** 권리분석
- **Fields:** `property.special_conditions_code` + `property.remarks` + `sale_detail.specification_remarks`
- **Logic:** Text matches `/우선매수|전세사기|특별법/` → `has_risk: true`
- **Limitation:** Only detectable when court notes it in remarks. No keyword match → `nil`.
- **Automation level:** Court-noted cases only.
- **yes_means_safe:** false

### bidding-001 — 경매 진행 상태 확인

- **Question:** 출발 전 해당 경매 사건이 정상적으로 진행 중인지 확인하셨습니까?
- **Tab:** 입찰&낙찰
- **Fields:** `property.status`
- **Logic:** `status == "진행중"` → display status info to user.
- **Limitation:** `answer_type: action_confirm`. Status is displayable but user must confirm they checked.
- **Automation level:** Status info auto-display; final confirmation is user action.

### bidding-003 — 입찰 보증금 준비

- **Question:** 입찰 보증금으로 해당 물건 최저가의 10% 이상을 자기앞수표 한 장으로 준비하셨습니까?
- **Tab:** 입찰&낙찰
- **Fields:** `property.min_bid_price`
- **Logic:** `min_bid_price * 0.1` → calculate and display required deposit amount.
- **Limitation:** `answer_type: action_confirm`. Amount is auto-calculated but preparation is user action.
- **Automation level:** Deposit amount auto-calculation; preparation confirmation is user action.

---

## Manual Grade — 72 Items

Items where court_auction API data is insufficient for any level of automatic determination. Grouped by tab.

### 권리분석 (23 items)

Reason: tenant info, registry transcript, dividend data, or on-site inspection required.

| ID | Question Summary | Reason |
|----|-----------------|--------|
| rights-003 | 전입신고된 임차인 거주 여부 | 임차인 정보 미수집 |
| rights-006 | 임차인 배당요구 신청 여부 | 임차인 정보 미수집 |
| rights-009 | HUG 대항력 포기 확약서 제출 여부 | 확약서 정보 미수집 |
| rights-010 | 대항력 임차인 미배당 보증금 유무 | 배당 정보 미수집 |
| rights-014 | 임차인 보증금·확정일자·배당요구 정보 확인 | 임차인 정보 미수집 |
| rights-015 | 임차권/전세권 말소기준 후순위 여부 | 권리순위 정보 미수집 |
| rights-016 | 전입신고일 vs 말소기준일 선후관계 | 전입신고일 미수집 |
| rights-001 | 선순위 가처분 유무 | 등기부등본 정보 미수집 |
| rights-004 | 선순위 가등기 유무 | 등기부등본 정보 미수집 |
| rights-007 | 예고등기 유무 | 등기부등본 정보 미수집 |
| rights-008 | 선순위 세금 압류 유무 | 등기부등본 정보 미수집 |
| rights-012 | 선순위 임차권 등기 후 신규 전입 임차인 | 등기부등본 + 전입세대 정보 미수집 |
| rights-013 | 임차권 등기 설정 여부 | 등기부등본 정보 미수집 |
| rights-017 | 말소기준권리 vs 세금 압류 간격 | 송달 일자 미수집 |
| rights-022 | 질권 표시 유무 | 질권 정보 미수집 |
| rights-023 | 금전 채권만 구성 여부 | 등기부등본 정보 미수집 |
| eviction-003 | 점유자 유무·명도 수월성 | 점유자 정보 미수집 |
| eviction-004 | 소액임차인 최우선변제금 배당 여부 | 임차인 상세 정보 미수집 |
| eviction-005 | 미납 관리비 수준 | 관리비 정보 미수집 |
| eviction-006 | 명도확인서 필수 상황 여부 | 배당 구조 정보 미수집 |
| eviction-007 | 협의 명도 가능 여부 | 점유자 정보 미수집 |
| eviction-001 | 화재·누수·크랙 등 치명적 하자 | 현장 확인 필요 |
| manual-001 | 토지 분묘기지권 유무 | 현장 확인 필요 |

### 수익분석 (20 items)

Reason: external market data, tax/regulatory databases, or user-specific input required.

| ID | Question Summary | Reason |
|----|-----------------|--------|
| finance-003 | 근저당 설정 은행 지점 확인 | 등기부등본 정보 미수집 |
| market-001 | 최근 1년 실거래 건수 활성도 | 실거래 데이터 미수집 |
| market-002 | KB시세 대비 10% 이상 할인 여부 | 시세 데이터 미수집 |
| market-003 | 전용면적·연식 동일 매물 비교 (action_confirm) | 사용자 확인 필요 |
| market-004 | 최근 한 달 실거래 내역 유무 | 실거래 데이터 미수집 |
| market-005 | 미분양·입주 물량 적정 여부 | 공급량 데이터 미수집 |
| market-007 | 매물 비율 5% 이하 여부 | 매물 데이터 미수집 |
| market-008 | 주변 신축 입주 시기 | 입주 물량 데이터 미수집 |
| market-011 | 순수익 흑자 여부 | 비용 계산 필요 |
| tax-001 | 비규제지역 여부 | 규제지역 데이터 미수집 |
| tax-002 | 매매사업자/법인 명의 계획 | 사용자 입력 필요 |
| tax-003 | 양도세 중과 배제 대상 여부 | 보유 현황 미수집 |
| tax-004 | 공시가격 9억 이하 여부 | 공시가격 미수집 |
| tax-005 | 인구감소지역 + 공시가 4억 이상 | 공시가격·지역 분류 미수집 |
| tax-007 | 6월 1일 이전 매도 계획 | 사용자 입력 필요 |
| finance-001 | DSR 한도·대출 계획 수립 (action_confirm) | 사용자 확인 필요 |
| finance-002 | 특례 대출 적용 가능 여부 | 사용자별 자격 요건 상이 |
| finance-004 | 매매사업자 활용 계획 | 사용자 입력 필요 |
| regulation-001 | 실거래가 이하 매입 가능 여부 | 실거래가 데이터 미수집 |
| regulation-002 | 토지거래허가구역 여부 | 규제 데이터 미수집 |

### 물건분석 (13 items)

Reason: building ledger, floor plans, map data, or on-site inspection required.

| ID | Question Summary | Reason |
|----|-----------------|--------|
| property-003 | 상가 1층 가시성 | 도면·현장 확인 필요 |
| property-004 | 위반건축물 표시 유무 | 건축물대장 미수집 |
| property-005 | 용도 주거용 확인 | 건축물대장 미수집 |
| property-007 | 엘리베이터 유무 | 건축물대장 미수집 |
| property-008 | 창문 앞 조망 확보 | 현장 확인 필요 |
| resale-002 | 주차 공간 충분 여부 | 건축물대장 미수집 |
| resale-004 | 신축 2년 이내 감정가 과대 여부 | 준공년도 미수집 |
| location-001 | 현장 임장 수행 여부 (action_confirm) | 사용자 확인 필요 |
| location-003 | 핵심 인프라 인접 여부 | 지도 데이터 미수집 |
| location-004 | 빌라 투룸 이상 구조 | 도면 미수집 |
| location-007 | 빌라 수요 유무 | 수요 데이터 미수집 |
| location-008 | 층수 지역 수요 적합성 | 지역 수요 데이터 미수집 |
| inspect-014 | 건물 간격·주차 양호 여부 | 현장 확인 필요 |

### 현장확인 (10 items)

Reason: physical on-site inspection, document cross-verification, or user action required.

| ID | Question Summary | Reason |
|----|-----------------|--------|
| inspect-002 | 감정평가서 vs 건축물대장 일치 | 건축물대장 미수집 |
| inspect-003 | 등기소 실매도가 교차검증 (action_confirm) | 사용자 확인 필요 |
| inspect-005 | 무상거주 확인서·가장 임차인 추정 | 현황조사서 미수집 |
| inspect-007 | 우편함 공과금 통지서 수신인 확인 | 현장 확인 필요 |
| inspect-008 | 점유자 관계 계약서 확인 | 현장 확인 필요 |
| inspect-009 | 부동산 소장 매도가 팁 (action_confirm) | 사용자 확인 필요 |
| inspect-010 | 월세 시세·대출 한도 교차검증 (action_confirm) | 사용자 확인 필요 |
| inspect-011 | 순수익·입찰가 역산 계산 (action_confirm) | 사용자 확인 필요 |
| inspect-012 | 계량기·가스밸브 확인 | 현장 확인 필요 |
| inspect-013 | 섀시·누수 흔적 확인 | 현장 확인 필요 |

### 입찰&낙찰 (6 items)

Reason: user judgment, planning decisions, or physical verification required.

| ID | Question Summary | Reason |
|----|-----------------|--------|
| invest-001 | 투자 기준 확립 여부 (action_confirm) | 사용자 확인 필요 |
| invest-002 | 모든 리스크 파악 여부 | 사용자 판단 필요 |
| exit-001 | 악취·환기 문제 | 현장 확인 필요 |
| exit-002 | 다수 부동산 매물 등록 계획 (action_confirm) | 사용자 확인 필요 |
| bidding-002 | 비교 물건 탐색 수행 여부 | 사용자 확인 필요 |
| bidding-004 | 입찰표 숫자 교차검증 (action_confirm) | 사용자 확인 필요 |

---

## Field Usage Map

Reverse mapping: which court_auction fields contribute to checklist auto-detection.

| Table | Field | Used By |
|-------|-------|---------|
| properties | `property_type` | property-006, rights-019, inspect-004(P), market-006(P) |
| properties | `remarks` | rights-011, rights-020, property-002, rights-021(P) |
| properties | `building_detail` | resale-003 |
| properties | `land_category` | rights-019 |
| properties | `exclusive_area` | tax-006 |
| properties | `view_count` | market-012 |
| properties | `min_bid_price` | bidding-003(P) |
| properties | `status` | bidding-001(P) |
| properties | `special_conditions_code` | rights-021(P) |
| properties | `building_name` | market-006(P) |
| sale_detail | `non_extinguished_rights` | rights-002 |
| sale_detail | `specification_remarks` | rights-011, rights-020, property-002, rights-005(P), rights-021(P) |
| sale_detail | `goods_remarks` | rights-011, rights-020, property-002 |
| sale_detail | `superficies_details` | rights-011 |
| sale_detail | `share_description` | property-001 |
| appraisal_points | `content` | rights-005(P), inspect-001(P) |

**(P) = Partial grade item**

### Unused Fields (not mapped to any checklist item)

| Table | Field |
|-------|-------|
| properties | case_number, case_type, claim_amount, property_usage_code, sido, sigungu, dong, building_structure, failed_bid_count, interest_count, latitude, longitude |
| sale_detail | senior_mortgage_basis, dividend_demand_deadline, price_round_1~4 |
| auction_schedules | all fields (schedule_date, schedule_time, bid_start_date, bid_end_date, place, schedule_type, result_code, min_price, sale_amount) |
| land_details | all fields (land_type, land_area, land_category, share_ratio, address, lot_number) |
| appraisal_points | item_code |

These fields serve display/informational purposes (property detail page, auction history, etc.) rather than checklist auto-detection.
