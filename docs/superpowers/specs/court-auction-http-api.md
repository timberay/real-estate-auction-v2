# Court Auction Direct HTTP API

Both search and detail APIs can be called directly via HTTP POST without browser automation.
No session, cookie, or login required.

## Base URL

```
https://www.courtauction.go.kr/pgj/
```

## Common Headers

```
Content-Type: application/json;charset=UTF-8
Accept: application/json
Referer: https://www.courtauction.go.kr/pgj/index.on?w2xPath=/pgj/ui/pgj100/PGJ151F00.xml
User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36
```

## 1. Search API

**Endpoint:** `POST pgjsearch/searchControllerMain.on`

**Extra headers:**
```
submissionid: mf_wfm_mainFrame_sbm_selectGdsDtlSrch
SC-Userid: SYSTEM
```

### Request body (criteria search)

```json
{
  "dma_pageInfo": {
    "pageNo": 1,
    "pageSize": 10,
    "bfPageNo": "",
    "startRowNo": "",
    "totalCnt": "",
    "totalYn": "Y",
    "groupTotalCount": ""
  },
  "dma_srchGdsDtlSrchInfo": {
    "rletDspslSpcCondCd": "",
    "bidDvsCd": "",
    "mvprpRletDvsCd": "00031R",
    "cortAuctnSrchCondCd": "0004601",
    "rprsAdongSdCd": "",
    "rprsAdongSggCd": "",
    "rprsAdongEmdCd": "",
    "rdnmSdCd": "11",
    "rdnmSggCd": "",
    "rdnmNo": "",
    "mvprpDspslPlcAdongSdCd": "",
    "mvprpDspslPlcAdongSggCd": "",
    "mvprpDspslPlcAdongEmdCd": "",
    "rdDspslPlcAdongSdCd": "",
    "rdDspslPlcAdongSggCd": "",
    "rdDspslPlcAdongEmdCd": "",
    "cortOfcCd": "",
    "jdbnCd": "",
    "execrOfcDvsCd": "",
    "lclDspslGdsLstUsgCd": "20000",
    "mclDspslGdsLstUsgCd": "20100",
    "sclDspslGdsLstUsgCd": "20104",
    "cortAuctnMbrsId": "",
    "aeeEvlAmtMin": "",
    "aeeEvlAmtMax": "",
    "lwsDspslPrcRateMin": "",
    "lwsDspslPrcRateMax": "",
    "flbdNcntMin": "",
    "flbdNcntMax": "",
    "objctArDtsMin": "",
    "objctArDtsMax": "",
    "mvprpArtclKndCd": "",
    "mvprpArtclNm": "",
    "mvprpAtchmPlcTypCd": "",
    "notifyLoc": "on",
    "lafjOrderBy": "",
    "pgmId": "PGJ151F01",
    "csNo": "",
    "cortStDvs": "3",
    "statNum": 1,
    "bidBgngYmd": "20260410",
    "bidEndYmd": "20260424",
    "dspslDxdyYmd": "",
    "fstDspslHm": "",
    "scndDspslHm": "",
    "thrdDspslHm": "",
    "fothDspslHm": "",
    "dspslPlcNm": "",
    "lwsDspslPrcMin": "50000000",
    "lwsDspslPrcMax": "100000000",
    "grbxTypCd": "",
    "gdsVendNm": "",
    "fuelKndCd": "",
    "carMdyrMax": "",
    "carMdyrMin": "",
    "carMdlNm": "",
    "sideDvsCd": ""
  }
}
```

### Key parameters

| Parameter | Description | Values |
|---|---|---|
| `cortStDvs` | Search mode | `1` = 법원, `2` = 소재지(지번), `3` = 소재지(새주소) |
| `csNo` | Case number | e.g. `2025타경12345` (empty for criteria search) |
| `cortOfcCd` | Court code | e.g. `B000210` (서울중앙). Empty for criteria search. |
| `bidDvsCd` | Bid type | `000331` = 기일입찰, `000332` = 기간입찰, `""` = 전체 |
| `rdnmSdCd` | Region (시/도) code | See region codes below |
| `rdnmSggCd` | District (시/군/구) code | Empty = all districts |
| `lclDspslGdsLstUsgCd` | Usage large category | `10000` = 토지, `20000` = 건물 |
| `mclDspslGdsLstUsgCd` | Usage mid category | `20100` = 주거용건물, etc. |
| `sclDspslGdsLstUsgCd` | Usage small category | `20104` = 아파트, etc. See table below |
| `lwsDspslPrcMin` | Min price (won) | e.g. `"50000000"` |
| `lwsDspslPrcMax` | Max price (won) | e.g. `"100000000"` |
| `notifyLoc` | Listing filter mode | `"on"` = active listings with bid schedule, `"off"` = all cases |
| `bidBgngYmd` | Bid schedule start date | `YYYYMMDD` format (used when `notifyLoc: "on"`) |
| `bidEndYmd` | Bid schedule end date | `YYYYMMDD` format (used when `notifyLoc: "on"`) |

Omitted parameters can be sent as empty string `""`.

### Pagination

| Field | Description |
|---|---|
| `pageNo` | 1-based page number |
| `pageSize` | Items per page (default 10, max tested 50) |
| `totalYn` | `"Y"` to include total count in response |

Pagination works by incrementing `pageNo`. Total available items returned in `dma_pageInfo.totalCnt`.

### Search by case number

Set `cortStDvs: "1"`, `csNo: "2025타경12345"`, `notifyLoc: "off"`.
Leave region/usage/price fields empty.

### Response

```json
{
  "status": 200,
  "message": "검색 결과가 조회되었습니다.",
  "data": {
    "dma_pageInfo": { "totalCnt": "25", "pageNo": 1, "pageSize": 10 },
    "ipcheck": true,
    "dlt_srchResult": [
      {
        "docid": "B0002122024013012598111",
        "srnSaNo": "2024타경125981",
        "boCd": "B000212",
        "saNo": "20240130125981",
        "maemulSer": "1",
        "mokmulSer": "1",
        "printSt": "서울특별시 강남구 ...",
        "gamevalAmt": "154000000",
        "minmaePrice": "123200000",
        "yuchalCnt": "5",
        "ipchalGbncd": "000331",
        "maeGiil": "20260416",
        "maegyuljGiil": "20260423",
        "lclsUtilCd": "20000",
        "mclsUtilCd": "20100"
      }
    ]
  }
}
```

Key response fields per item:

| Field | Description |
|---|---|
| `srnSaNo` | Display case number (e.g. `2024타경125981`) — first 4 chars = case year |
| `boCd` | Court code (needed for detail API) |
| `saNo` | Internal case number |
| `maemulSer` | Item serial (needed for detail API) |
| `printSt` | Address |
| `gamevalAmt` | Appraisal value |
| `minmaePrice` | Minimum sale price |
| `yuchalCnt` | Failed auction count |
| `maeGiil` | Sale date (YYYYMMDD) |
| `lclsUtilCd` / `mclsUtilCd` | Usage codes |

## 2. Detail API

**Endpoint:** `POST pgj15B/selectAuctnCsSrchRslt.on`

**Extra headers:**
```
submissionid: mf_wfm_mainFrame_sbm_selectGdsDtlSrchDtlInfo
SC-Userid: NONUSER
```

### Request body

Built from search result item fields:

```json
{
  "dma_srchGdsDtlSrch": {
    "csNo": "2024타경125981",
    "cortOfcCd": "B000212",
    "dspslGdsSeq": "1",
    "pgmId": "PGJ151F01",
    "srchInfo": {}
  }
}
```

| Parameter | Source |
|---|---|
| `csNo` | `srnSaNo` from search result |
| `cortOfcCd` | `boCd` from search result |
| `dspslGdsSeq` | `maemulSer` from search result |

### Response

```json
{
  "data": {
    "dma_result": {
      "csBaseInfo": { ... },
      "dstrtDemnInfo": { ... },
      "dspslGdsDxdyInfo": { ... },
      "csPicLst": [ ... ]
    }
  }
}
```

## 3. Criteria Search Design

### User Inputs

| Input | Description | Example |
|---|---|---|
| **Address (주소)** | User's target address | `"서울특별시 강남구 역삼동"` |
| **Max bid price (최대입찰가격)** | User's maximum bid amount in won | `120000000` (1.2억원) |

### Parameter Mapping

| Parameter | Derivation |
|---|---|
| `rdnmSdCd` | Extract 시/도 from address → map to region code |
| `lwsDspslPrcMin` | Fixed: `"50000000"` (5천만원) |
| `lwsDspslPrcMax` | First price tier strictly greater than user's max bid price |
| `sclDspslGdsLstUsgCd` | `""` (empty = all residential building types) |
| `lclDspslGdsLstUsgCd` | Fixed: `"20000"` (건물) |
| `mclDspslGdsLstUsgCd` | Fixed: `"20100"` (주거용건물) |
| `bidDvsCd` | Fixed: `""` (전체) |
| `cortStDvs` | Fixed: `"3"` (소재지 새주소) |
| `notifyLoc` | Fixed: `"on"` |

**Max price selection example**: User's max bid = 1.2억원 → next tier = `"150000000"` (1억5천만원)

### Pagination Strategy

1. First request: `pageNo: 1, pageSize: 10, totalYn: "Y"` → get `totalCnt`
2. If `totalCnt > 10`: paginate through remaining pages
3. Calculate total pages: `ceil(totalCnt / 10)`
4. Request pages 2..N with 1-2 second random delay between each

### Rate Limiting

Simulate natural browsing behavior:
- **Between pages**: 1-2 seconds random delay
- **On error/timeout**: exponential backoff starting at 30 seconds

### JSON Storage Format

```json
{
  "search_params": {
    "rdnmSdCd": "11",
    "lwsDspslPrcMin": "50000000",
    "lwsDspslPrcMax": "150000000",
    "bidBgngYmd": "20260410",
    "bidEndYmd": "20260424"
  },
  "fetched_at": "2026-04-10T09:00:00+09:00",
  "total_count": 25,
  "items": [ ... all paginated results merged ... ]
}

## Appendix: Internal Code Tables

### Region codes (`rdnmSdCd`)

| Code | Region |
|---|---|
| `11` | 서울특별시 |
| `26` | 부산광역시 |
| `27` | 대구광역시 |
| `28` | 인천광역시 |
| `29` | 광주광역시 |
| `30` | 대전광역시 |
| `31` | 울산광역시 |
| `36` | 세종특별자치시 |
| `41` | 경기도 |
| `42` | 강원도 |
| `43` | 충청북도 |
| `44` | 충청남도 |
| `45` | 전라북도 |
| `46` | 전라남도 |
| `47` | 경상북도 |
| `48` | 경상남도 |
| `50` | 제주특별자치도 |
| `51` | 강원특별자치도 |
| `52` | 전북특별자치도 |

### Usage codes

**Large category (`lclDspslGdsLstUsgCd`):**

| Code | Label |
|---|---|
| `10000` | 토지 |
| `20000` | 건물 |
| `30000` | 차량및운송장비 |
| `40000` | 기타 |

**Mid category for 건물 (`mclDspslGdsLstUsgCd`):**

| Code | Label |
|---|---|
| `20100` | 주거용건물 |
| `21100` | 상업용및업무용 |
| `22100` | 산업용및기타특수용 |
| `23100` | 용도복합용 |

**Small category for 주거용건물 (`sclDspslGdsLstUsgCd`):**

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

### Bid type codes (`bidDvsCd`)

| Code | Label |
|---|---|
| `000331` | 기일입찰 |
| `000332` | 기간입찰 |
| `""` | 전체 |

### Search mode codes (`cortStDvs`)

| Code | Label |
|---|---|
| `1` | 법원/담당계 |
| `2` | 소재지(지번주소) |
| `3` | 소재지(새주소) |

### Price values (`lwsDspslPrcMin` / `lwsDspslPrcMax`)

Values are in won (원), sent as string:

```
"10000000"    → 1천만원
"50000000"    → 5천만원
"100000000"   → 1억원
"150000000"   → 1억5천만원
...increments of 50000000...
"1000000000"  → 10억원
```

### Fixed values

| Parameter | Value | Note |
|---|---|---|
| `mvprpRletDvsCd` | `00031R` | 부동산 (real estate) |
| `cortAuctnSrchCondCd` | `0004601` | Search condition code |
| `pgmId` | `PGJ151F01` | Program ID |
| `statNum` | `1` | Status number |

## Notes

- Verified 2026-04-10. No authentication or session required.
- The `BrowserClient` can be replaced with a simple Faraday HTTP client for criteria search.
- Response time: ~0.5s (HTTP) vs ~10s+ (browser automation).
- `sc-userid` header: `SYSTEM` for search, `NONUSER` for detail.
- Year dropdown on UI does NOT transmit in HTTP request. Filter by case year from `srnSaNo` client-side.
- `cortOfcCd` may contain default value `"B000210"` from browser; send as `""` for criteria search via HTTP.
