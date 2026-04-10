# Court Auction Case Search API (PGJ159M00)

Case-number-based search via the 경매사건검색 page. Returns full case detail
(사건내역, 기일내역, 문건/송달내역) in a single request — no two-step
search-then-detail flow required.

Verified 2026-04-10. No authentication, session, or cookie required.

## Base URL

```
https://www.courtauction.go.kr/pgj/
```

## Endpoint

**`POST pgj15A/selectAuctnCsSrchRslt.on`**

This is different from the property detail endpoint (`pgj15B/…`) used by PGJ151F00.

### Headers

```
Content-Type: application/json;charset=UTF-8
Accept: application/json
Referer: https://www.courtauction.go.kr/pgj/index.on?w2xPath=/pgj/ui/pgj100/PGJ159M00.xml
User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36
submissionid: mf_wfm_mainFrame_sbm_selectCsDtlInf
sc-userid: NONUSER
sc-pgmid: PGJ15AF01
```

### Request Body

```json
{
  "dma_srchCsDtlInf": {
    "cortOfcCd": "B000530",
    "csNo": "2022타경564"
  }
}
```

| Parameter | Required | Description |
|---|---|---|
| `cortOfcCd` | **Yes** | Court code (see court code table below) |
| `csNo` | **Yes** | Case number in `{YYYY}타경{serial}` format |

### Case Number Format

```
{year}타경{serial_number}
 ^^^^      ^^^^^^^^^^^^^
 YYYY      digits only, no leading-zero padding required
```

- "타경" is fixed (경매 사건 type).
- Serial number: entered without the "타경" prefix. e.g., `564` not `타경564`.
- The site accepts unpadded numbers: `564` works the same as `00564`.

### Response — Valid Case

The response contains case detail data rendered across three tabs on the page:

```json
{
  "data": {
    "dma_result": { ... }
  }
}
```

**사건내역 (Case details):**

| Field | Description | Example |
|---|---|---|
| 사건번호 | Case number (may include 전자 suffix) | `2022타경564전자` |
| 사건명 | Case type | `부동산임의경매` |
| 접수일자 | Filing date | `2022.02.04` |
| 개시결정일자 | Decision start date | `2022.02.15` |
| 담당계 | Court division + contact | `경매2계 전화: 064-729-2152` |
| 청구금액 | Claim amount (won) | `260,000,000원` |
| 종국결과 | Final result | `미종국` (ongoing) |
| 중복/병합/이송 | Related/merged cases | `2024타경30057(중복)` |

**물건정보 (Property items):**

| Field | Description | Example |
|---|---|---|
| 물건번호 | Item number | `1` |
| 물건용도 | Usage type | `단독주택` |
| 감정평가액 | Appraisal value | `445,123,280원` |
| 최저매각가격 | Minimum sale price | `445,123,280원` |
| 매수신청보증금 | Bid deposit | `44,512,400원` |
| 소재지 (목록) | Address list per item | Multiple addresses possible |
| 목록구분 | Land/Building | `토지`, `건물` |
| 물건상태 | Current status | `매각준비 -> 매각공고` |
| 기일정보 | Next sale date | `2026.04.21` |
| 최근입찰결과 | Last bid result | `2022.11.22 유찰` |
| 물건비고 | Remarks | `-일괄매각. 제시외 건물 포함` |
| 제시외 | Unlisted extras | Structure details |

**당사자 (Parties):**

| Field | Description |
|---|---|
| 채권자 | Creditor |
| 채무자/소유자 | Debtor/Owner |
| 근저당권자 | Mortgage holder |
| 임차인 | Lessee |
| 압류권자 | Seizure holder |
| 공유자 | Co-owner |

**관련사건 (Related cases):**

| Field | Description |
|---|---|
| 관련법원 | Related court |
| 관련사건번호 | Related case number |
| 관련사건구분 | Relation type (e.g., 개시결정이의) |

### Response — Invalid Case

When the case number does not exist at the given court, the response data
renders as: `"해당 사건번호는 잘못된 번호입니다. 다시 한번 확인해 보시기 바랍니다."`

### Response — Not Yet Public

Per site notice: cases are searchable only **14 days after** the decision
start date (개시결정일). Ended cases (종국) stop providing schedule info,
and after 30 more days only basic info remains.

## Court List API

The court dropdown is populated by a separate API call on page load:

**`POST pgj002/selectCortOfcLst.on`**

```json
{"cortExecrOfcDvsCd": "00079B"}
```

Returns the full list of 60 courts with their codes.

## Court Code Table

| Code | Court | Code | Court |
|---|---|---|---|
| `B000210` | 서울중앙지방법원 | `B000310` | 대구지방법원 |
| `B000211` | 서울동부지방법원 | `B000311` | 안동지원 |
| `B000215` | 서울서부지방법원 | `B000312` | 경주지원 |
| `B000212` | 서울남부지방법원 | `B000313` | 김천지원 |
| `B000213` | 서울북부지방법원 | `B000314` | 상주지원 |
| `B000214` | 의정부지방법원 | `B000315` | 의성지원 |
| `B214807` | 고양지원 | `B000316` | 영덕지원 |
| `B214804` | 남양주지원 | `B000317` | 포항지원 |
| `B000240` | 인천지방법원 | `B000320` | 대구서부지원 |
| `B000241` | 부천지원 | `B000410` | 부산지방법원 |
| `B000250` | 수원지방법원 | `B000412` | 부산동부지원 |
| `B000251` | 성남지원 | `B000414` | 부산서부지원 |
| `B000252` | 여주지원 | `B000411` | 울산지방법원 |
| `B000253` | 평택지원 | `B000420` | 창원지방법원 |
| `B250826` | 안산지원 | `B000431` | 마산지원 |
| `B000254` | 안양지원 | `B000421` | 진주지원 |
| `B000260` | 춘천지방법원 | `B000422` | 통영지원 |
| `B000261` | 강릉지원 | `B000423` | 밀양지원 |
| `B000262` | 원주지원 | `B000424` | 거창지원 |
| `B000263` | 속초지원 | `B000510` | 광주지방법원 |
| `B000264` | 영월지원 | `B000511` | 목포지원 |
| `B000270` | 청주지방법원 | `B000512` | 장흥지원 |
| `B000271` | 충주지원 | `B000513` | 순천지원 |
| `B000272` | 제천지원 | `B000514` | 해남지원 |
| `B000273` | 영동지원 | `B000520` | 전주지방법원 |
| `B000280` | 대전지방법원 | `B000521` | 군산지원 |
| `B000281` | 홍성지원 | `B000522` | 정읍지원 |
| `B000282` | 논산지원 | `B000523` | 남원지원 |
| `B000283` | 천안지원 | `B000530` | 제주지방법원 |
| `B000284` | 공주지원 | | |
| `B000285` | 서산지원 | | |

## Search-by-Case-Number Logic

### Parameters

- **Court code**: Required. One of the 60 court codes above.
- **Serial number**: The numeric part only (e.g., `564`).
- **Year range**: Current year down to 5 years prior (6 years total).

### Algorithm

```
input:  court_code, serial_number
output: list of matching case records

for year in (current_year .. current_year - 5):
    cs_no = "{year}타경{serial_number}"
    response = POST pgj15A/selectAuctnCsSrchRslt.on
                 body: { dma_srchCsDtlInf: { cortOfcCd: court_code, csNo: cs_no } }

    if response contains valid case data:
        collect result
    else:
        skip (invalid case number)

    sleep random(1.5..3.0) seconds   # natural browsing interval

return collected results
```

### Rate Limiting Policy

| Context | Delay |
|---|---|
| Between year iterations (same court + serial) | 1.5–3.0s random |
| Between different serial numbers (batch mode) | 3.0–5.0s random |
| After 5+ consecutive failures | 5.0–10.0s backoff |

These intervals simulate natural browsing behavior and avoid
triggering rate limits on the court auction site.

## Comparison with PGJ151F00 (물건상세검색)

| Aspect | PGJ151F00 | PGJ159M00 |
|---|---|---|
| Purpose | Property search by criteria/location | Case lookup by number |
| Search endpoint | `pgjsearch/searchControllerMain.on` | — |
| Detail endpoint | `pgj15B/selectAuctnCsSrchRslt.on` | `pgj15A/selectAuctnCsSrchRslt.on` |
| Court required | No (can use region mode) | **Yes** |
| Steps | 2 (search → detail) | 1 (direct detail) |
| Response focus | Property listing + sale info | Full case record (parties, schedules, documents) |
| Referer pgmId | `PGJ151F01` | `PGJ15AF01` |

## WebSquare Element IDs (Browser Automation Reference)

| Purpose | Element ID |
|---|---|
| Court select | `mf_wfm_mainFrame_sbx_auctnCsSrchCortOfc` |
| Year select | `mf_wfm_mainFrame_sbx_auctnCsSrchCsYear` |
| Case number input | `mf_wfm_mainFrame_ibx_auctnCsSrchCsNo` |
| Search button | `mf_wfm_mainFrame_btn_auctnCsSrchBtn` |
| Submission ID | `mf_wfm_mainFrame_sbm_selectCsDtlInf` |
