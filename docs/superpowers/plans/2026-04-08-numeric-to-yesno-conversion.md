# Numeric-to-YesNo Checklist Conversion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert 12 numeric-input inspection items to yes/no selection format in `checklist_items_summary.json` so they render correctly in the existing yes/no UI.

**Architecture:** JSON-only change. All 12 items currently have numeric comparison keys in their `logic` field (e.g., `">= 85"`, `"< 10"`) which are invisible in the UI because `InspectionItemComponent#logic_present?` only checks for `logic["yes"]`. Converting to `{"yes": "...", "no": "..."}` makes them work automatically.

**Tech Stack:** JSON seed data, Rails db:seed

**Spec:** `docs/superpowers/specs/2026-04-08-numeric-to-yesno-conversion-design.md`

**Note:** `market-007` (매물 비율) was discovered during planning as an additional numeric item not in the original spec. Total is 12 items, not 11.

---

### Task 1: Convert `tax-006` (건축물대장, line 744)

**Files:**
- Modify: `db/seeds/checklist_items_summary.json:748-752`

- [ ] **Step 1: Edit the item**

Replace:
```json
    "question": "주택의 전용면적은 몇 ㎡입니까?",
    "description": "전용면적 40㎡ 이하(또는 60㎡ 이하)는 주택수 제외 특례가 있어 다주택자 중과를 피할 수 있습니다.",
    "logic": {
      ">= 85": "건물분 부가세 10% 추가 납부가 필요합니다.",
      "< 85": "건물분 부가세가 면제됩니다."
    },
```

With:
```json
    "question": "주택의 전용면적이 85㎡(약 25평) 미만입니까?",
    "description": "전용면적 40㎡ 이하(또는 60㎡ 이하)는 주택수 제외 특례가 있어 다주택자 중과를 피할 수 있습니다.",
    "logic": {
      "yes": "건물분 부가세가 면제됩니다.",
      "no": "건물분 부가세 10% 추가 납부가 필요합니다."
    },
```

---

### Task 2: Convert `market-002` (온라인조회, line 906)

**Files:**
- Modify: `db/seeds/checklist_items_summary.json:910-914`

- [ ] **Step 1: Edit the item**

Replace:
```json
    "question": "일반 급매물 또는 KB시세 대비 현재 경매 최저가가 최소 몇 % 이상 저렴한가?",
    "description": "경매의 본질은 시세 대비 할인 취득입니다. 할인율이 충분하지 않으면 경매의 의미가 없습니다.",
    "logic": {
      ">= 10": "수익성 달성이 가능합니다.",
      "< 10": "입찰 메리트가 떨어집니다."
    },
```

With:
```json
    "question": "일반 급매물 또는 KB시세 대비 현재 경매 최저가가 10% 이상 저렴합니까?",
    "description": "경매의 본질은 시세 대비 할인 취득입니다. 할인율이 충분하지 않으면 경매의 의미가 없습니다.",
    "logic": {
      "yes": "수익성 달성이 가능합니다.",
      "no": "입찰 메리트가 떨어집니다."
    },
```

---

### Task 3: Convert `market-004` (온라인조회, line 953)

**Files:**
- Modify: `db/seeds/checklist_items_summary.json:957-961`

- [ ] **Step 1: Edit the item**

Replace:
```json
    "question": "최근 한 달 기준 실거래 건수는 평균 몇 건입니까?",
    "description": "최근 한 달 기준 실거래 건수로 현재의 거래 활성도를 구체적 숫자로 파악합니다.",
    "logic": {
      ">= 2": "수요가 탄탄하고 거래가 활발합니다.",
      "< 2": "거래량이 부족하여 추가적인 수요 조사가 필요합니다."
    },
```

With:
```json
    "question": "최근 한 달 기준 실거래 내역이 있습니까?",
    "description": "최근 실거래 유무로 현재의 거래 활성도를 파악합니다.",
    "logic": {
      "yes": "거래가 활발하여 환금성이 확인됩니다.",
      "no": "거래 내역이 없어 추가적인 수요 조사가 필요합니다."
    },
```

---

### Task 4: Convert `market-006` (온라인조회, line 999)

**Files:**
- Modify: `db/seeds/checklist_items_summary.json:1003-1007`

- [ ] **Step 1: Edit the item**

Replace:
```json
    "question": "검색하려는 아파트 단지의 총 세대수는 몇 세대입니까?",
    "description": "세대수가 적은 단지는 거래가 드물어 환금성이 낮습니다. 대단지(500세대+)가 유리합니다.",
    "logic": {
      ">= 300": "매물 검색 및 거래가 용이한 단지입니다.",
      "< 300": "매물 회전율이나 환금성이 떨어질 수 있습니다."
    },
```

With:
```json
    "question": "단독(나홀로) 건물이 아닌 단지형 아파트(또는 오피스텔·빌라 등)입니까?",
    "description": "단독(나홀로) 건물은 거래가 드물어 환금성이 낮습니다. 단지형 건물이 유리합니다.",
    "logic": {
      "yes": "매물 검색 및 거래가 용이한 단지입니다.",
      "no": "매물 회전율이나 환금성이 떨어질 수 있습니다."
    },
```

---

### Task 5: Convert `market-007` (온라인조회, line 1018)

**Note:** This item was not in the original spec but was discovered during planning.

**Files:**
- Modify: `db/seeds/checklist_items_summary.json:1022-1026`

- [ ] **Step 1: Edit the item**

Replace:
```json
    "question": "단지 총 세대수 대비 현재 나와 있는 매물 비율(%)은 얼마입니까?",
    "description": "매물 비율이 높으면 공급 과잉으로 매도가 어렵고, 낮으면 희소성이 있어 유리합니다.",
    "logic": {
      "<= 5.8": "준수한 수준의 단지입니다.",
      "> 5.8": "매물이 기준치 이상으로 쌓여 있어 환금성에 불리할 수 있습니다."
    },
```

With:
```json
    "question": "단지 총 세대수 대비 현재 나와 있는 매물 비율이 적정 수준(5.8% 이하)입니까?",
    "description": "매물 비율이 높으면 공급 과잉으로 매도가 어렵고, 낮으면 희소성이 있어 유리합니다.",
    "logic": {
      "yes": "준수한 수준의 단지입니다.",
      "no": "매물이 기준치 이상으로 쌓여 있어 환금성에 불리할 수 있습니다."
    },
```

---

### Task 6: Convert `market-008` (온라인조회, line 1037)

**Files:**
- Modify: `db/seeds/checklist_items_summary.json:1041-1045`

- [ ] **Step 1: Edit the item**

Replace:
```json
    "question": "금액대가 비슷한 주변 신축 아파트의 입주 시기까지 남은 기간(개월)은?",
    "description": "인근 신축 입주가 임박하면 기존 물건의 시세·임대가가 하락 압력을 받습니다. 타이밍 리스크 점검입니다.",
    "logic": {
      "<= 3": "전세입자 이동 및 급매 출현으로 가격 하락 위험이 큽니다.",
      "> 3": "입주장 리스크가 낮습니다."
    },
```

With:
```json
    "question": "금액대가 비슷한 주변 신축 아파트의 입주 시기가 3개월 이상 남아 있습니까?",
    "description": "인근 신축 입주가 임박하면 기존 물건의 시세·임대가가 하락 압력을 받습니다. 타이밍 리스크 점검입니다.",
    "logic": {
      "yes": "입주장 리스크가 낮습니다.",
      "no": "전세입자 이동 및 급매 출현으로 가격 하락 위험이 큽니다."
    },
```

---

### Task 7: Convert `market-012` (온라인조회, line 1060)

**Files:**
- Modify: `db/seeds/checklist_items_summary.json:1064-1068`

- [ ] **Step 1: Edit the item**

Replace:
```json
    "question": "경매 사이트에 표시된 해당 물건의 조회수는 얼마입니까?",
    "description": "조회수가 높으면 경쟁 입찰자가 많아 낙찰가가 올라갈 가능성이 높습니다. 경쟁도 간접 지표입니다.",
    "logic": {
      "< 500": "경쟁이 적어 합리적인 가격에 낙찰 가능성이 높습니다.",
      ">= 500": "가격이 비정상적으로 올라갈 수 있습니다."
    },
```

With:
```json
    "question": "경매 사이트에 표시된 해당 물건의 조회수가 500회 미만입니까?",
    "description": "조회수가 높으면 경쟁 입찰자가 많아 낙찰가가 올라갈 가능성이 높습니다. 경쟁도 간접 지표입니다.",
    "logic": {
      "yes": "경쟁이 적어 합리적인 가격에 낙찰 가능성이 높습니다.",
      "no": "가격이 비정상적으로 올라갈 수 있습니다."
    },
```

---

### Task 8: Convert `tax-004` (온라인조회, line 1165)

**Files:**
- Modify: `db/seeds/checklist_items_summary.json:1169-1173`

- [ ] **Step 1: Edit the item**

Replace:
```json
    "question": "해당 주택의 공시 가격은 얼마입니까? (단위: 만원)",
    "description": "공시가격은 모든 세금(취득세, 보유세, 양도세) 산정의 기준이 되는 핵심 수치입니다.",
    "logic": {
      "<= 90000": "종합부동산세가 부과되지 않습니다.",
      "> 90000": "종부세 부과 대상이 되므로 보유세 부담을 포함해야 합니다."
    },
```

With:
```json
    "question": "해당 주택의 공시가격이 9억 원 이하입니까?",
    "description": "공시가격은 모든 세금(취득세, 보유세, 양도세) 산정의 기준이 되는 핵심 수치입니다.",
    "logic": {
      "yes": "종합부동산세가 부과되지 않습니다.",
      "no": "종부세 부과 대상이 되므로 보유세 부담을 포함해야 합니다."
    },
```

---

### Task 9: Convert `tax-005` (온라인조회, line 1184)

**IMPORTANT:** This item has **inverted logic** — "yes" = risk, "no" = safe.

**Files:**
- Modify: `db/seeds/checklist_items_summary.json:1188-1192`

- [ ] **Step 1: Edit the item**

Replace:
```json
    "question": "인구 감소 지역 내 주택의 공시가격은 얼마입니까? (단위: 만원)",
    "description": "인구감소지역은 세컨드홈 특례(취득세 1.1%, 양도세 비과세 혜택)가 적용될 수 있어 절세 효과가 큽니다.",
    "logic": {
      "<= 40000": "1세대 1주택 비과세 특례 유지, 종부세 합산 배제, 취득세 최대 50% 감면 혜택 적용이 가능합니다.",
      "> 40000": "지방 저가 주택 요건을 초과하여 특례 적용이 불가합니다."
    },
```

With:
```json
    "question": "인구 감소 지역(또는 지방 저가 주택)이면서 공시가격이 4억 원 이상입니까?",
    "description": "인구감소지역은 세컨드홈 특례(취득세 1.1%, 양도세 비과세 혜택)가 적용될 수 있어 절세 효과가 큽니다.",
    "logic": {
      "yes": "지방 저가 주택 요건을 초과하여 특례 적용이 불가합니다.",
      "no": "1세대 1주택 비과세 특례 유지, 종부세 합산 배제, 취득세 최대 50% 감면 혜택 적용이 가능합니다."
    },
```

---

### Task 10: Convert `rights-017` (현장임장, line 1262)

**Files:**
- Modify: `db/seeds/checklist_items_summary.json:1266-1270`

- [ ] **Step 1: Edit the item**

Replace:
```json
    "question": "말소기준권리 설정일과 세금 압류 송달 일자의 간격은 몇 년입니까?",
    "description": "간격이 길면 체납 세금이 누적되어 있을 가능성이 높고, 선순위 세금 압류는 낙찰자가 인수할 수 있습니다. 체납 규모를 간접 추정하는 지표입니다.",
    "logic": {
      ">= 1": "간격이 1년 이상이면 안심하고 입찰 가능합니다.",
      "< 1": "송달 일자를 반드시 체크해야 합니다."
    },
```

With:
```json
    "question": "말소기준권리 설정일과 세금 압류 송달 일자의 간격이 1년 이상입니까?",
    "description": "간격이 길면 체납 세금이 누적되어 있을 가능성이 높고, 선순위 세금 압류는 낙찰자가 인수할 수 있습니다. 체납 규모를 간접 추정하는 지표입니다.",
    "logic": {
      "yes": "간격이 1년 이상이면 안심하고 입찰 가능합니다.",
      "no": "송달 일자를 반드시 체크해야 합니다."
    },
```

---

### Task 11: Convert `market-011` (현장임장, line 1497)

**Files:**
- Modify: `db/seeds/checklist_items_summary.json:1501-1505`

- [ ] **Step 1: Edit the item**

Replace:
```json
    "question": "예상 매도가에서 모든 비용을 뺀 순수익과 수익률(%)은 얼마입니까?",
    "description": "최종 수익을 구체적 숫자와 퍼센트로 산출했는지 확인합니다. (통합: 순수익 금액 + 수익률 %)",
    "logic": {
      "> 0": "안전한 투자가 가능합니다.",
      "<= 0": "순수익이 마이너스가 될 수 있습니다."
    },
```

With:
```json
    "question": "예상 매도가에서 모든 비용을 뺀 순수익이 0원 초과(흑자)입니까?",
    "description": "최종 수익이 흑자인지 확인합니다. 예상 매도가에서 모든 비용(취득세, 중개수수료, 수리비 등)을 차감하여 판단합니다.",
    "logic": {
      "yes": "안전한 투자가 가능합니다.",
      "no": "순수익이 마이너스가 될 수 있습니다."
    },
```

---

### Task 12: Convert `bidding-002` (기타, line 1848)

**Files:**
- Modify: `db/seeds/checklist_items_summary.json:1852-1856`

- [ ] **Step 1: Edit the item**

Replace:
```json
    "question": "동일 종목으로 사전에 직접 찾아본 비교 물건은 총 몇 개입니까?",
    "description": "비교 물건을 충분히 보지 않으면 적정 입찰가 판단이 불가능합니다. 최소 5~10개 이상 비교해야 합니다.",
    "logic": {
      ">= 5": "비교 분석을 통한 확신을 가질 수 있는 상태입니다.",
      "< 5": "비교 물건 탐색이 부족합니다."
    },
```

With:
```json
    "question": "동일 종목으로 사전에 직접 비교 물건 탐색을 수행하였습니까?",
    "description": "비교 물건을 충분히 보지 않으면 적정 입찰가 판단이 불가능합니다. 동일 종목의 다른 물건을 탐색하여 비교 분석해야 합니다.",
    "logic": {
      "yes": "비교 분석을 통한 확신을 가질 수 있는 상태입니다.",
      "no": "비교 물건 탐색이 부족합니다."
    },
```

---

### Task 13: Seed and verify

**Files:**
- None created or modified

- [ ] **Step 1: Validate JSON syntax**

Run: `python3 -c "import json; json.load(open('db/seeds/checklist_items_summary.json')); print('JSON valid')"`

Expected: `JSON valid`

- [ ] **Step 2: Run seed to load updated data**

Run: `bin/rails db:seed`

Expected: Seed completes without errors.

- [ ] **Step 3: Verify no numeric logic keys remain**

Run: `grep -cP '"(>=|<=|>|<) ' db/seeds/checklist_items_summary.json`

Expected: `0` — all numeric comparison keys have been replaced with `yes`/`no`.

- [ ] **Step 4: Verify all converted items have yes/no logic**

Run: `bin/rails runner "ids = %w[tax-006 market-002 market-004 market-006 market-007 market-008 market-012 tax-004 tax-005 rights-017 market-011 bidding-002]; ids.each { |id| item = InspectionItem.find_by!(code: id); raise \"#{id} missing yes key\" unless item.logic['yes']; raise \"#{id} missing no key\" unless item.logic['no'] }; puts 'All 12 items verified'"`

Expected: `All 12 items verified`

- [ ] **Step 5: Run existing tests**

Run: `bin/rails test`

Expected: All tests pass (no test changes needed — existing tests use yes/no fixture items).

- [ ] **Step 6: Commit**

```bash
git add db/seeds/checklist_items_summary.json
git commit -m "refactor(seeds): convert 12 numeric-input checklist items to yes/no format

Embed threshold values directly in question text so all items use
the existing yes/no binary answer UI. No code changes needed.

Items converted: tax-006, market-002, market-004, market-006,
market-007, market-008, market-012, tax-004, tax-005, rights-017,
market-011, bidding-002

Ref: docs/superpowers/specs/2026-04-08-numeric-to-yesno-conversion-design.md"
```
