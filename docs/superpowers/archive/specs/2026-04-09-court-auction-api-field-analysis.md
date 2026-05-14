# CourtAuction API Field Analysis — Live Test Results

> **Test date:** 2026-04-09T03:15:00Z
> **Source:** courtauction.go.kr `/pgj/pgjsearch/searchControllerMain.on` (POST)
> **Method:** Playwright browser route interception
> **Note:** Direct HTTP (curl/Faraday) is blocked by WAF. Browser-based requests work.

## Critical Finding: HTTP Client Blocked by WAF

| Method | Result |
|--------|--------|
| curl / Faraday (direct HTTP) | **BLOCKED** — WAF returns "Web firewall security policies have been blocked" |
| Playwright browser | **WORKS** — Full API response received |

**Impact on architecture:** The current plan (Faraday HTTP POST) will NOT work. The scraper must use Playwright (headless browser) to bypass the government WAF. This requires:
1. Reverting to Playwright-based scraping approach
2. Adding Playwright/Chromium to Docker image
3. Updating `GovernmentCourtAuctionAdapter` to use browser automation

## Request Structure (Captured)

The actual request body differs significantly from what was documented in open-source references:

```json
{
  "dma_pageInfo": {
    "pageNo": 1,
    "pageSize": 10,
    "totalCnt": "",
    "totalYn": "Y"
  },
  "dma_srchGdsDtlSrchInfo": {
    "cortAuctnSrchCondCd": "0004601",
    "lclDspslGdsLstUsgCd": "20000",
    "mclDspslGdsLstUsgCd": "20100",
    "pgmId": "PGJ151M01",
    "csNo": "",
    "cortOfcCd": "",
    "rprsAdongSdCd": "",
    ...50+ fields...
  }
}
```

Key differences from spec assumption:
- Request is **nested** in `dma_pageInfo` + `dma_srchGdsDtlSrchInfo` wrapper objects
- Field names use Korean abbreviation system, not the simpler names assumed in spec
- All search parameters must be included (even empty strings), not just the ones being used

## Response Structure (Captured)

```json
{
  "status": 200,
  "message": "검색 결과가 조회되었습니다.",
  "data": {
    "dma_pageInfo": {
      "totalCnt": "11983",
      "groupTotalCount": 9143
    },
    "dlt_srchResult": [
      { ...property item... }
    ]
  }
}
```

Key differences from spec assumption:
- Results are in `data.dlt_srchResult`, NOT `dlt_list`
- Total count is in `data.dma_pageInfo.totalCnt`

## Field Mapping: API → Project DB

### Used by Project (Direct DB columns)

| API Field | Value Example | DB Column | Usage |
|-----------|---------------|-----------|-------|
| `srnSaNo` | "2021타경105850" | `properties.case_number` | Primary identifier, unique key |
| `jiwonNm` | "서울중앙지방법원" | `properties.court_name` | Display, court identification |
| `dspslUsgNm` | "다세대" | `properties.property_type` | Property classification |
| `printSt` | "서울특별시 서초구 강남대로97길 49-20 3층304호" | `properties.address` | Display address |
| `gamevalAmt` | "12887000000" | `properties.appraisal_price` | Appraisal value (감정가) |
| `minmaePrice` | "5278515000" | `properties.min_bid_price` | Minimum sale price (최저매각가) |

### Used by Project (Stored in raw_data JSON, used by InspectionRunner)

| API Field | Value Example | Maps To | Inspection Usage |
|-----------|---------------|---------|-----------------|
| `mulBigo` | "일괄매각" | `raw_data.court_auction.remarks` | rights-011: 유치권/법정지상권 감지 |
| `yuchalCnt` | "5" | `raw_data.court_auction.failed_bid_count` | 유찰횟수 (가격 하락 판단) |
| `mokGbncd` | "03" | `raw_data.court_auction.is_partial_share` | property-001: 지분 여부 감지 |
| `spJogCd` | "0004302,0004303" | `raw_data.court_auction.special_conditions` | 특수조건 (별도 해석 필요) |
| `inqCnt` | "69" | `raw_data.court_auction.view_count` | market-012: 조회수 500회 이상 경쟁 판단 |

### Available but NOT currently used by project

| API Field | Value Example | Potential Use |
|-----------|---------------|--------------|
| `boCd` | "B000210" | Internal court code (for detail API call) |
| `saNo` | "20210130105850" | Internal case ID |
| `maemulSer` | "1" | Property sequence in case |
| `mokmulSer` | "1" | Item sequence |
| `jpDeptCd` / `jpDeptNm` | "1011" / "경매11계" | Court department info |
| `jinstatCd` | "0002100001" | Detailed status code |
| `mulStatcd` | "01" | Property status code |
| `mulJinYn` | "Y" | Is property proceeding (Y/N) |
| `maemulUtilCd` | "13" | Property usage code |
| `maeAmt` | "0" | Sale amount (populated after sale) |
| `gwansMulRegCnt` | "48" | Interest registration count |
| `maeGiil` | "20260409" | Sale date (YYYYMMDD) |
| `maegyuljGiil` | "20260416" | Sale decision date |
| `maeHh1~4` | "1000" | Sale time slots |
| `maeGiilCnt` | "5" | Number of sale dates |
| `maePlace` | "경매법정4별관211호" | Sale location |
| `ipchalGbncd` | "000331" | Bidding type code |
| `jongCd` | "000" | Category code |
| `stopsaGbncd` | "00" | Case suspension code |
| `hjguSido/Sigu/Dong` | "서울특별시/서초구/잠원동" | Structured address (행정동) |
| `daepyoLotno` | "24-21" | Lot number (지번) |
| `buldNm` | "" | Building name |
| `buldList` | "3층304호" | Floor/unit detail |
| `pjbBuldList` | "철근콘크리트구조 23.63㎡" | Structure + area description |
| `lclsUtilCd/mclsUtilCd/sclsUtilCd` | "20000/20100/20106" | Usage classification codes (3-level) |
| `minArea/maxArea` | "23/23" | Area range (㎡) |
| `xCordi/yCordi` | "313312/546158" | Map coordinates (Korean TM) |
| `wgs84Xcordi/Ycordi` | "127/37" | GPS coordinates (WGS84) |
| `rdNm` | "강남대로97길" | Road name |
| `buldNo` | "49-20" | Building number |
| `rd1Nm/rd2Nm` | "서울특별시/서초구" | Road address parts |
| `notifyMinmaePrice1~4` | "4222812000" | Notified minimum prices per round |
| `notifyMinmaePriceRate1~2` | "33" | Minimum price rate (%) |
| `tel` | "02-530-1817" | Court phone number |
| `remaeordDay` | "" | Re-sale order date |

## Spec vs Reality Comparison

| Spec Assumed | Reality | Status |
|-------------|---------|--------|
| Field name: `cortOfcNm` | Actual: `jiwonNm` | **WRONG** — must update |
| Field name: `aprsAmt` | Actual: `gamevalAmt` | **WRONG** — must update |
| Field name: `lwstSaleAmt` | Actual: `minmaePrice` | **WRONG** — must update |
| Field name: `gdsMdlClsNm` | Actual: `dspslUsgNm` | **WRONG** — must update |
| Field name: `gdsDtlAdr` | Actual: `printSt` | **WRONG** — must update |
| Field name: `cortOfcCd` | Actual: `boCd` | **WRONG** — must update |
| Field name: `csNo` | Actual: `srnSaNo` | **WRONG** — must update |
| Field name: `csDtlNo` | Actual: `mokmulSer` | **WRONG** — must update |
| Field name: `flbdCnt` | Actual: `yuchalCnt` | **WRONG** — must update |
| Field name: `gdsStndCd` | Actual: `mokGbncd` | **WRONG** — must update |
| Field name: `prcsCd` | Actual: `jinstatCd` or `mulStatcd` | **WRONG** — must update |
| Response wrapper: `dlt_list` | Actual: `data.dlt_srchResult` | **WRONG** — must update |
| Request: flat JSON | Actual: nested `dma_pageInfo` + `dma_srchGdsDtlSrchInfo` | **WRONG** — must update |
| HTTP method: Faraday POST | **WAF blocks** direct HTTP | **MUST USE PLAYWRIGHT** |

## Action Items

1. **Architecture change required**: Switch from Faraday HTTP POST to Playwright browser automation
2. **Update ResponseParser**: All field name mappings must be corrected based on this analysis
3. **Update SearchClient**: Request body structure must be nested as captured
4. **Update spec and plan**: Correct all field name assumptions
5. **Docker**: Must include Chromium for Playwright
6. **Detail API**: Need to capture detail endpoint response separately (different field structure expected)
