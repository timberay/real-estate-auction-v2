# Checklist Tab Reorganization

## Problem

The `tab` field in `db/seeds/checklist_items_summary.json` uses document names (매각물건명세서, 등기부등본, 건축물대장, etc.) as grouping values. These don't accurately represent where the data comes from — they were speculative labels, not actual data sources. The `data_source` field was already removed for the same reason.

## Decision

Reorganize `tab` values from document-based to **auction process flow** grouping, using `category` as the mapping key. The `category` field remains unchanged as a secondary classification within each tab.

## Tab Mapping

| New tab    | Categories included                                                          | Count |
|------------|-----------------------------------------------------------------------------|-------|
| 물건분석    | 물건 기본 필터링, 입지분석                                                      | 17    |
| 권리분석    | 권리분석, 명도 난이도                                                           | 29    |
| 수익분석    | 시세·수익성 분석, 경매 규제·수익성 분석, 세무·절세 분석, 자금·대출 분석                | 23    |
| 현장확인    | 현장조사·서류검증                                                               | 12    |
| 입찰&낙찰   | 입찰 실무, 투자 원칙·리스크 관리, 매도·출구전략                                    | 8     |

**Total: 89 items across 5 tabs**

## Scope

- Only `db/seeds/checklist_items_summary.json` is modified
- Only the `tab` field value changes per the mapping above
- `category`, `tab_position`, and all other fields remain unchanged
- No code, DB, or model changes in this session
