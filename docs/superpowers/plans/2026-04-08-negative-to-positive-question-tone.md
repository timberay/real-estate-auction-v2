# Negative-to-Positive Question Tone Conversion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert 18 negative-phrased checklist questions ("~없습니까?") to positive tone ("~있습니까?") with yes/no logic inversion in `checklist_items_summary.json`.

**Architecture:** JSON seed data only. Each item's `question` field is rewritten and the `logic.yes` / `logic.no` values are swapped. No Ruby code, no schema, no test changes.

**Tech Stack:** JSON seed data, `bin/rails db:seed`

**Spec:** `docs/superpowers/specs/2026-04-08-negative-to-positive-question-tone-design.md`

---

### Task 1: Convert 매각물건명세서 tab items (6 items)

**Files:**
- Modify: `db/seeds/checklist_items_summary.json` (lines 22–237)

- [ ] **Step 1: Edit `rights-011` (line 26)**

Replace:
```json
    "question": "매각물건명세서 비고란에 유치권 또는 법정지상권 기재가 없습니까?",
```
```json
    "logic": {
      "yes": "치명적인 특수 권리가 없습니다.",
      "no": "인수해야 할 중대 권리가 명시되어 있습니다."
    },
```

With:
```json
    "question": "매각물건명세서 비고란에 유치권 또는 법정지상권 기재가 있습니까?",
```
```json
    "logic": {
      "yes": "인수해야 할 중대 권리가 명시되어 있습니다.",
      "no": "치명적인 특수 권리가 없습니다."
    },
```

- [ ] **Step 2: Edit `rights-003` (line 68) — natural rewrite**

Replace:
```json
    "question": "채무자/소유자만 거주 중이며, 전입신고된 제3자 임차인이 없습니까?",
```
```json
    "logic": {
      "yes": "인수할 임차인 보증금이 없어 안전합니다.",
      "no": "임차인의 미배당 보증금은 낙찰자가 전액 인수해야 합니다."
    },
```

With:
```json
    "question": "전입신고된 제3자 임차인이 거주하고 있습니까?",
```
```json
    "logic": {
      "yes": "임차인의 미배당 보증금은 낙찰자가 전액 인수해야 합니다.",
      "no": "인수할 임차인 보증금이 없어 안전합니다."
    },
```

- [ ] **Step 3: Edit `rights-010` (line 145) — natural rewrite**

Replace:
```json
    "question": "대항력 있는 임차인이 없거나, 보증금이 전액 배당되어 미배당 금액이 없습니까?",
```
```json
    "logic": {
      "yes": "보증금을 전액 배당받아 나가므로 추가 부담이 없습니다.",
      "no": "미배당 보증금 전액을 낙찰자가 추가로 물어줘야 합니다."
    },
```

With:
```json
    "question": "대항력 있는 임차인의 미배당 보증금이 있습니까?",
```
```json
    "logic": {
      "yes": "미배당 보증금 전액을 낙찰자가 추가로 물어줘야 합니다.",
      "no": "보증금을 전액 배당받아 나가므로 추가 부담이 없습니다."
    },
```

- [ ] **Step 4: Edit `property-002` (line 187) — natural rewrite**

Replace:
```json
    "question": "호실 간 벽체 구분이 명확하고 불법 구조변경이 없습니까?",
```
```json
    "logic": {
      "yes": "호실 구분이 명확합니다.",
      "no": "대출이 거절될 수 있는 매우 위험한 물건입니다."
    },
```

With:
```json
    "question": "호실 간 벽체 구분이 불명확하거나 불법 구조변경이 있습니까?",
```
```json
    "logic": {
      "yes": "대출이 거절될 수 있는 매우 위험한 물건입니다.",
      "no": "호실 구분이 명확합니다."
    },
```

- [ ] **Step 5: Edit `rights-016` (line 233) — natural rewrite**

Replace:
```json
    "question": "임차인이 없거나, 전입신고일이 말소기준일 이후여서 대항력이 없습니까?",
```
```json
    "logic": {
      "yes": "대항력이 없는 임차인이므로 안전합니다.",
      "no": "대항력이 있는 임차인이므로 추가 확인이 필요합니다."
    },
```

With:
```json
    "question": "전입신고일이 말소기준일 이전인 대항력 있는 임차인이 있습니까?",
```
```json
    "logic": {
      "yes": "대항력이 있는 임차인이므로 추가 확인이 필요합니다.",
      "no": "대항력이 없는 임차인이므로 안전합니다."
    },
```

- [ ] **Step 6: Edit `rights-020` (line 287)**

Replace:
```json
    "question": "현황조사서에 유치권 신고 표시가 없습니까?",
```
```json
    "logic": {
      "yes": "신고된 유치권이 없습니다.",
      "no": "실제 공사 내역과 점유 내역을 반드시 확인해야 합니다."
    },
```

With:
```json
    "question": "현황조사서에 유치권 신고 표시가 있습니까?",
```
```json
    "logic": {
      "yes": "실제 공사 내역과 점유 내역을 반드시 확인해야 합니다.",
      "no": "신고된 유치권이 없습니다."
    },
```

- [ ] **Step 7: Verify no "없습니까" remains in 매각물건명세서 tab**

Run: `grep -n "없습니까" db/seeds/checklist_items_summary.json | head -20`
Expected: No matches on lines 1–400 (매각물건명세서 section)

- [ ] **Step 8: Commit**

```bash
git add db/seeds/checklist_items_summary.json
git commit -m "refactor(seeds): convert 6 매각물건명세서 negative questions to positive tone"
```

---

### Task 2: Convert 등기부등본 tab items (6 items)

**Files:**
- Modify: `db/seeds/checklist_items_summary.json` (lines 419–551)

- [ ] **Step 1: Edit `rights-001` (line 423)**

Replace:
```json
    "question": "등기부에 말소기준권리보다 앞선 선순위 가처분이 없습니까?",
```
```json
    "logic": {
      "yes": "가처분 리스크가 없습니다.",
      "no": "소유권 자체가 바뀔 수 있어 매우 위험합니다."
    },
```

With:
```json
    "question": "등기부에 말소기준권리보다 앞선 선순위 가처분이 있습니까?",
```
```json
    "logic": {
      "yes": "소유권 자체가 바뀔 수 있어 매우 위험합니다.",
      "no": "가처분 리스크가 없습니다."
    },
```

- [ ] **Step 2: Edit `rights-004` (line 442)**

Replace:
```json
    "question": "선순위 가등기가 없습니까?",
```
```json
    "logic": {
      "yes": "선순위 가등기 리스크가 없습니다.",
      "no": "가등기 종류(소유권이전청구권/담보)에 따라 인수 위험이 있으므로 추가 확인이 필요합니다."
    },
```

With:
```json
    "question": "선순위 가등기가 있습니까?",
```
```json
    "logic": {
      "yes": "가등기 종류(소유권이전청구권/담보)에 따라 인수 위험이 있으므로 추가 확인이 필요합니다.",
      "no": "선순위 가등기 리스크가 없습니다."
    },
```

- [ ] **Step 3: Edit `rights-007` (line 461)**

Replace:
```json
    "question": "등기부등본에 예고등기가 없습니까?",
```
```json
    "logic": {
      "yes": "예고등기에 의한 심각한 권리 하자가 없습니다.",
      "no": "예고등기가 있는 물건은 무조건 입찰을 피해야 합니다."
    },
```

With:
```json
    "question": "등기부등본에 예고등기가 있습니까?",
```
```json
    "logic": {
      "yes": "예고등기가 있는 물건은 무조건 입찰을 피해야 합니다.",
      "no": "예고등기에 의한 심각한 권리 하자가 없습니다."
    },
```

- [ ] **Step 4: Edit `rights-008` (line 480)**

Replace:
```json
    "question": "말소기준권리보다 앞선 선순위 세금 압류가 없습니까?",
```
```json
    "logic": {
      "yes": "압류 우선 배당 리스크가 없습니다.",
      "no": "대항력 있는 임차인과 압류가 같이 있으면 보증금 전액 인수 위험이 매우 큽니다."
    },
```

With:
```json
    "question": "말소기준권리보다 앞선 선순위 세금 압류가 있습니까?",
```
```json
    "logic": {
      "yes": "대항력 있는 임차인과 압류가 같이 있으면 보증금 전액 인수 위험이 매우 큽니다.",
      "no": "압류 우선 배당 리스크가 없습니다."
    },
```

- [ ] **Step 5: Edit `rights-012` (line 499) — natural rewrite**

Replace:
```json
    "question": "선순위 임차권 등기가 없거나, 등기 이후 새로 전입한 미상 임차인이 없습니까?",
```
```json
    "logic": {
      "yes": "해당 리스크가 없습니다. 기존 임차인의 확정일자 및 배당 요구 여부를 확인하세요.",
      "no": "임대차보호법 제3조의4 6항에 따라 우선변제권이 없어 배당을 받을 수 없으나 대항력은 존재하므로 보증금 전액을 낙찰자가 떠안아야 합니다."
    },
```

With:
```json
    "question": "선순위 임차권 등기 또는 등기 이후 새로 전입한 미상 임차인이 있습니까?",
```
```json
    "logic": {
      "yes": "임대차보호법 제3조의4 6항에 따라 우선변제권이 없어 배당을 받을 수 없으나 대항력은 존재하므로 보증금 전액을 낙찰자가 떠안아야 합니다.",
      "no": "해당 리스크가 없습니다. 기존 임차인의 확정일자 및 배당 요구 여부를 확인하세요."
    },
```

- [ ] **Step 6: Edit `rights-022` (line 541)**

Replace:
```json
    "question": "경매정보지에 질권 표시가 없습니까?",
```
```json
    "logic": {
      "yes": "해당 사항이 없습니다.",
      "no": "대상이 부동산 자체인지, 권리에 설정된 것인지 파악해야 합니다."
    },
```

With:
```json
    "question": "경매정보지에 질권 표시가 있습니까?",
```
```json
    "logic": {
      "yes": "대상이 부동산 자체인지, 권리에 설정된 것인지 파악해야 합니다.",
      "no": "해당 사항이 없습니다."
    },
```

- [ ] **Step 7: Verify no "없습니까" remains in 등기부등본 tab**

Run: `grep -n "없습니까" db/seeds/checklist_items_summary.json | head -20`
Expected: No matches on lines 400–600 (등기부등본 section)

- [ ] **Step 8: Commit**

```bash
git add db/seeds/checklist_items_summary.json
git commit -m "refactor(seeds): convert 6 등기부등본 negative questions to positive tone"
```

---

### Task 3: Convert 온라인조회 tab items (2 items)

**Files:**
- Modify: `db/seeds/checklist_items_summary.json` (lines 819–878)

- [ ] **Step 1: Edit `rights-021` (line 823)**

Replace:
```json
    "question": "전세사기 피해자의 우선매수권 행사 가능성이 없습니까?",
```
```json
    "logic": {
      "yes": "우선매수권 리스크가 없습니다.",
      "no": "시간적 손실과 기회비용이 발생할 수 있습니다."
    },
```

With:
```json
    "question": "전세사기 피해자의 우선매수권 행사 가능성이 있습니까?",
```
```json
    "logic": {
      "yes": "시간적 손실과 기회비용이 발생할 수 있습니다.",
      "no": "우선매수권 리스크가 없습니다."
    },
```

- [ ] **Step 2: Edit `inspect-001` (line 869) — natural rewrite**

Replace:
```json
    "question": "감정평가서 특이사항에 중대한 문제 기재가 없습니까?",
```
```json
    "logic": {
      "yes": "현황과 서류가 일치합니다.",
      "no": "서류와 실제가 다르거나 특이한 하자가 있습니다."
    },
```

With:
```json
    "question": "감정평가서 특이사항에 중대한 문제가 기재되어 있습니까?",
```
```json
    "logic": {
      "yes": "서류와 실제가 다르거나 특이한 하자가 있습니다.",
      "no": "현황과 서류가 일치합니다."
    },
```

- [ ] **Step 3: Commit**

```bash
git add db/seeds/checklist_items_summary.json
git commit -m "refactor(seeds): convert 2 온라인조회 negative questions to positive tone"
```

---

### Task 4: Convert 현장임장 tab items (3 items)

**Files:**
- Modify: `db/seeds/checklist_items_summary.json` (lines 1428–1689)

- [ ] **Step 1: Edit `eviction-001` (line 1432)**

Replace:
```json
    "question": "현장 확인 결과 화재·누수·크랙 등 치명적 하자가 없습니까?",
```
```json
    "logic": {
      "yes": "심각한 하자가 없습니다.",
      "no": "복구비용이 막대합니다."
    },
```

With:
```json
    "question": "현장 확인 결과 화재·누수·크랙 등 치명적 하자가 있습니까?",
```
```json
    "logic": {
      "yes": "복구비용이 막대합니다.",
      "no": "심각한 하자가 없습니다."
    },
```

- [ ] **Step 2: Edit `exit-001` (line 1591)**

Replace:
```json
    "question": "집 내부에 악취나 환기 문제가 없습니까?",
```
```json
    "logic": {
      "yes": "악취 리스크가 없습니다.",
      "no": "매수자에게 치명적인 단점으로 작용합니다."
    },
```

With:
```json
    "question": "집 내부에 악취나 환기 문제가 있습니까?",
```
```json
    "logic": {
      "yes": "매수자에게 치명적인 단점으로 작용합니다.",
      "no": "악취 리스크가 없습니다."
    },
```

- [ ] **Step 3: Edit `inspect-013` (line 1677) — natural rewrite**

Replace:
```json
    "question": "외부에서 섀시(창틀) 교체 여부 및 아랫집 누수 피해 여부를 확인하여 누수가 없습니까?",
```
```json
    "logic": {
      "yes": "누수가 없어 방수 공사 비용이 발생하지 않습니다.",
      "no": "누수가 있거나 확인하지 못하였으므로 방수 공사비를 입찰가에 반영해야 합니다."
    },
```

With:
```json
    "question": "외부에서 섀시(창틀) 및 아랫집 확인 결과 누수 흔적이 있습니까?",
```
```json
    "logic": {
      "yes": "누수가 있거나 확인하지 못하였으므로 방수 공사비를 입찰가에 반영해야 합니다.",
      "no": "누수가 없어 방수 공사 비용이 발생하지 않습니다."
    },
```

- [ ] **Step 4: Commit**

```bash
git add db/seeds/checklist_items_summary.json
git commit -m "refactor(seeds): convert 3 현장임장 negative questions to positive tone"
```

---

### Task 5: Convert 기타 tab item (1 item) and verify

**Files:**
- Modify: `db/seeds/checklist_items_summary.json` (line 1879)

- [ ] **Step 1: Edit `manual-001` (line 1879)**

Replace:
```json
    "question": "토지에 분묘기지권이 없습니까?",
```
```json
    "logic": {
      "yes": "분묘기지권 리스크가 없습니다.",
      "no": "토지 활용이 극도로 제한됩니다."
    },
```

With:
```json
    "question": "토지에 분묘기지권이 있습니까?",
```
```json
    "logic": {
      "yes": "토지 활용이 극도로 제한됩니다.",
      "no": "분묘기지권 리스크가 없습니다."
    },
```

- [ ] **Step 2: Verify zero "없습니까" remain in the file**

Run: `grep -c "없습니까" db/seeds/checklist_items_summary.json`
Expected: `0`

- [ ] **Step 3: Validate JSON syntax**

Run: `python3 -c "import json; json.load(open('db/seeds/checklist_items_summary.json')); print('JSON valid')"`
Expected: `JSON valid`

- [ ] **Step 4: Run seed to verify database loads**

Run: `bin/rails db:seed`
Expected: No errors, inspection items count unchanged

- [ ] **Step 5: Commit**

```bash
git add db/seeds/checklist_items_summary.json
git commit -m "refactor(seeds): convert 1 기타 negative question to positive tone"
```

---

### Task 6: Final verification and cleanup

- [ ] **Step 1: Count total "있습니까" questions to confirm conversion**

Run: `grep -c "있습니까" db/seeds/checklist_items_summary.json`
Expected: `31` (13 existing positive + 18 newly converted)

- [ ] **Step 2: Run full CI**

Run: `bin/ci`
Expected: All green — no code changes were made, only seed data

- [ ] **Step 3: Remove plan file checkbox marks (reset for tracking)**

No action needed — plan stays as reference.
