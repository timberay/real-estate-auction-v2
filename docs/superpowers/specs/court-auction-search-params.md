# Court Auction Search Parameters

Source: `app/adapters/court_auction/browser_client.rb`
Target: https://www.courtauction.go.kr/pgj/index.on?w2xPath=/pgj/ui/pgj100/PGJ151F00.xml

## Form Parameters

| Field | Value | Notes |
|---|---|---|
| **Location mode** | "소재지(새주소)" radio | Always use this mode (not "법원") to avoid court restriction |
| **Region (시/도)** | User-selected region | Iterate all 19 regions for criteria search |
| **Year (사건번호)** | YYYY | UI-only filter; NOT transmitted in HTTP API. See note below. |
| **Bid category (입찰구분)** | "전체" | |
| **Usage (용도)** | "건물" → "주거용건물" → 소분류 | Three-level cascade (대분류 → 중분류 → 소분류) |
| **Min price (최저매각가격)** | "5천만원" | Fixed |
| **Max price (최저매각가격)** | 1억~10억 (5천만원 단위) | Iterate 19 price tiers |

### Year Parameter Note

The year dropdown (`mf_wfm_mainFrame_sbx_rletCsYear`) exists on the UI but is **NOT included in the HTTP request body** for criteria search. The API filters by bid schedule dates (`bidBgngYmd`/`bidEndYmd`) instead. To filter by case year, extract from `srnSaNo` (first 4 chars, e.g. `"2024타경881"` → `2024`).

## Valid Regions

```
서울특별시, 부산광역시, 대구광역시, 인천광역시, 광주광역시,
대전광역시, 울산광역시, 세종특별자치시, 경기도, 강원도,
충청북도, 충청남도, 전라북도, 전라남도, 경상북도, 경상남도,
제주특별자치도, 강원특별자치도, 전북특별자치도
```

## Price Tiers

Available options on the site, used for max price selection:

```
1천만원 (10,000,000)
5천만원 (50,000,000)
1억원 ~ 10억원 (100,000,000 ~ 1,000,000,000) in 5천만원 increments
```

For criteria search iteration:
- **Min price**: fixed at `50000000` (5천만원)
- **Max price**: iterate from `100000000` (1억원) to `1000000000` (10억원) in `50000000` increments → **19 tiers**

## Small Category (소분류) for 주거용건물

| Code | Label |
|---|---|
| `20101` | 단독주택 |
| `20102` | 다가구주택 |
| `20103` | 다중주택 |
| `20104` | 아파트 |
| `20105` | 연립주택 |
| `20106` | 다세대주택 |
| `20107` | 기숙사 |
| `20108` | 빌라 |
| `20109` | 상가주택 |
| `20110` | 오피스텔 |
| `20111` | 주상복합 |

## WebSquare Element IDs

| Purpose | Element ID |
|---|---|
| Year select | `mf_wfm_mainFrame_sbx_rletCsYear` |
| Case number input | `mf_wfm_mainFrame_ibx_rletCsNo` |
| 소재지(새주소) radio | `mf_wfm_mainFrame_rad_rletSrchBtn_input_2` |
| Region (시/도) select | `mf_wfm_mainFrame_sbx_rletAdongSdR` |
| Bid category 전체 radio | `mf_wfm_mainFrame_rad_mvprpBidLst_input_0` |
| Usage large select | `mf_wfm_mainFrame_sbx_rletLclLst` |
| Usage mid select | `mf_wfm_mainFrame_sbx_rletMclLst` |
| Usage small select | `mf_wfm_mainFrame_sbx_rletSclLst` |
| Min price select | `mf_wfm_mainFrame_sbx_rletLwsDspslMin` |
| Max price select | `mf_wfm_mainFrame_sbx_rletLwsDspslMax` |
| Search button | `mf_wfm_mainFrame_btn_gdsDtlSrch` |
