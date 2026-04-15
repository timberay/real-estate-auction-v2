import json

with open("db/seeds/checklist_items_summary.json", "r") as f:
    items = json.load(f)

# IDs to delete
DELETE_IDS = {"eviction-007", "rights-011", "market-004", "market-011",
              "regulation-001", "resale-002", "property-008", "finance-004"}

# Absorber updates: merge descriptions and logic
ABSORBER_UPDATES = {
    "eviction-003": {
        "description": "채무자 본인 / 임차인 / 가족 / 불법점유자 등 유형에 따라 법적 대응 방법과 명도 난이도가 완전히 다릅니다. 협의 명도 / 인도명령 / 강제집행 중 어떤 방식이 될지 사전 판단해야 비용·기간을 예측할 수 있습니다.",
        "merged_from": "eviction-002,eviction-007"
    },
    "rights-002": {
        "question": "매각물건명세서 '소멸되지 아니하는 것' 비고란에 낙찰자가 인수할 권리(가등기, 가처분, 전세권, 유치권, 법정지상권 등) 기재가 없는 깨끗한 물건입니까?",
        "description": "법원이 직접 '이 권리는 낙찰자가 떠안는다'고 명시한 것으로, 초보자에게 가장 위험한 함정입니다. 유치권은 공사대금 미지급 등으로 점유를 주장하는 것이고, 법정지상권은 토지와 건물 소유자가 달라질 때 발생합니다.",
        "merged_from": "rights-011"
    },
    "market-001": {
        "question": "최근 1년간 해당 지역 및 단지의 실거래가 활발하고, 최근 1개월 내 거래 내역이 있습니까?",
        "description": "거래량이 활발해야 매도 시 빠르게 현금화할 수 있습니다. 거래가 뜸한 지역은 유동성 리스크가 높습니다. 최근 1개월 실거래 유무로 현재의 거래 활성도를 교차 확인합니다.",
        "merged_from": "market-004"
    },
    "inspect-011": {
        "question": "실제 매도가에서 수리비와 실투자금을 바탕으로 순수익과 입찰가를 역산법으로 계산하여 흑자를 확인하였습니까?",
        "description": "감에 의한 입찰가 산정이 아닌, 역산법(예상 매도가 - 비용 = 수익 → 최대 입찰가)을 적용했는지 확인합니다. 순수익이 0원 이하이거나 경매 최저가가 시세에 근접하면 입찰 메리트가 없습니다.",
        "merged_from": "market-009,market-011,regulation-001"
    },
    "inspect-014": {
        "question": "건물 간격(뻥뷰), 조망, 세대수 대비 주차 공간이 양호합니까?",
        "description": "창문 앞이 바로 옆 건물 벽으로 막혀 있는 '벽뷰'는 일조량 부족과 답답함으로 매도가가 크게 하락합니다. 채광·조망이 차단된 물건은 시세 대비 20~30% 낮은 가격에도 매수자를 찾기 어렵습니다. 주차 공간이 협소하거나 없으면 임차인 구하기와 매도에 극심한 어려움을 겪습니다. 반드시 현장에서 확인해야 합니다.",
        "applicable_types": ["아파트", "빌라/다세대", "오피스텔", "단독주택"],
        "merged_from": "resale-002,property-008"
    },
    "tax-002": {
        "question": "매매사업자 또는 법인 명의로 입찰할 계획입니까?",
        "description": "개인/법인/공동명의에 따라 취득세·양도세·종합부동산세 부담이 완전히 달라집니다. 매매사업자 등록 시 취득세 중과 회피, 부가세 환급 등의 혜택이 있지만, 건강보험료 상승 등 부작용도 있어 사전 판단이 필요합니다.",
        "merged_from": "finance-004"
    }
}

# Add depends_on to child items
DEPENDS_ON = {
    "rights-016": {"code": "rights-003", "show_when_risk": True},
    "rights-015": {"code": "rights-003", "show_when_risk": True},
    "rights-006": {"code": "rights-003", "show_when_risk": True},
    "rights-009": {"code": "rights-003", "show_when_risk": True},
    "rights-010": {"code": "rights-003", "show_when_risk": True},
    "rights-014": {"code": "rights-003", "show_when_risk": True},
    "rights-012": {"code": "rights-003", "show_when_risk": True},
    "rights-013": {"code": "rights-003", "show_when_risk": True},
    "rights-017": {"code": "rights-008", "show_when_risk": True},
}

# Apply absorber updates
for item in items:
    item_id = item["id"]
    if item_id in ABSORBER_UPDATES:
        item.update(ABSORBER_UPDATES[item_id])
    if item_id in DEPENDS_ON:
        item["depends_on"] = DEPENDS_ON[item_id]

# Remove deleted items
items = [item for item in items if item["id"] not in DELETE_IDS]

print(f"Total items: {len(items)}")
print(f"Items with depends_on: {sum(1 for i in items if 'depends_on' in i)}")
print(f"Items with applicable_types: {sum(1 for i in items if i.get('applicable_types'))}")

with open("db/seeds/checklist_items_summary.json", "w") as f:
    json.dump(items, f, ensure_ascii=False, indent=2)
    f.write("\n")

print("Done.")
