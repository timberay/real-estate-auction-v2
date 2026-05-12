# E2E 전문가 검사 보고서 (부동산 경매 도메인 베테랑 페르소나)

- **일시**: 2026-05-12
- **대상**: http://localhost:3000 (Rails 부동산 경매 도구, Turbo + Stimulus)
- **페르소나**: 권리분석/임차인 대항력/말소기준권리/인수금액/명도/입찰가 산정 베테랑
- **도구**: Playwright MCP (탭 격리, 코드 변경 없음, 게스트 세션)
- **세션 시작**: 새 탭 인덱스 2에서 진행, 다른 탭 무간섭

## 라우트/플로우별 결과

| 플로우 | URL | 상태 | 도메인 이슈 | 증거 |
|---|---|---|---|---|
| 온보딩 1단계 (현금/지역) | `/onboarding` | SUSPECT | 관심지역 기본값 "제주특별자치도", 행정구역 통합(강원특별자치도/전북특별자치도)이 구버전과 중복 노출 | `before/01-onboarding-step1.png` |
| 온보딩 2단계 (예비비) | `/onboarding` step2 | SUSPECT | 예비비 산식이 입찰가가 아닌 "평균 4.8억" 고정 기준. 취득세 528만원은 4.8억 × 1.1% 가정 — 실제 입찰가 6,540만원에는 부적합 | `before/02-onboarding-step2.png` |
| 온보딩 3단계 (대출) | `/onboarding` step3 | SUSPECT | "예상 최대입찰가: 계산 불가" 표시 — 사용자에게 사유 안내 없음 | `before/02-onboarding-step2.png` |
| 매물 목록 | `/properties` | SUSPECT | 시드/세션 매물 0건. 매물 추가 시 redirect가 시뮬레이터로 가는 비직관적 흐름 | `before/05-properties-empty.png` |
| 매물 대량 임포트 | `/properties/bulk_import` | PASS/SUSPECT | 빈 입력에도 200 + "실패 0건" 응답 → 사용자 피드백 미흡. 잘못된 법원명은 422 정상 | `before/06-bulk-import.png` |
| 매물 비교 | `/properties/compare` | PASS | 2건 미만일 때 안내 후 /properties로 redirect | (인라인 텍스트) |
| 검색 페이지 | `/search` | PASS | UI는 정상, 조건검색 폼 존재 | `before/03-search-empty.png` |
| 검색 결과 | `/search_results` | PASS (빈 결과) | 시드 매물 0건이라 결과 검증 불가 | (HTML 응답에 매물 링크 0건) |
| 명도 가이드 | `/eviction_guide` | PASS | 단계 S1~S15, 점유자별 분기(JT/ST/DO/IO) 모두 표시. 시간 추정치 합리적 | `before/07-eviction-guide.png` |
| 명도 시뮬레이터 진입 | `/eviction_guide/simulator/select_type` | PASS | 4가지 점유자 유형 (junior_tenant/senior_tenant/debtor_owner/illegal_occupant) | `before/08-simulator-select-type.png` |
| 시뮬레이터 질문(JT-Q1) | `/eviction_guide/simulator/question/JT-Q1` | PASS | 배당표 확인 흐름, 명확한 분기 안내 | `before/09-simulator-JT-Q1.png` |
| 시뮬레이터 잘못된 코드 | `/eviction_guide/simulator/question/INVALID` | PASS | 404를 친절한 메시지로 처리 ("해당 질문을 찾을 수 없습니다") | (인라인 텍스트) |
| 시뮬레이터 ST-Q2 법근거 | `/eviction_guide/simulator/question/ST-Q2` | SUSPECT | 매수인의 보증금 잔액 인수 협상 근거로 "주임법 제3조의5"(임차권등기명령)를 인용 — 제3조 또는 제3조의2가 더 정확 | fetch 응답 |
| 예산 설정 | `/settings/budget` | SUSPECT | 첫 GET 직후 콘솔 422 에러 노이즈. 최대입찰가 6,539~6,540만원 산식은 (현금-예비비)/(1-LTV)로 정확 | `before/10-settings-budget.png`, `error/13-settings-budget-422-on-load.png` |
| AI 분석 (수동) | `/analyses/new` | PASS | 수동분석 프롬프트 복사 → AI에 붙여넣기 → JSON 결과 업로드 워크플로 명확 | `before/11-analyses-new.png` |
| AI 분석 상세 | `/analyses/1`, `/properties/1/...` | N/A | 시드 매물 0건이라 검증 불가 (모두 404) | (HTTP 404) |
| 사용자 매뉴얼 | `/manual` | PASS | 6단계 워크북, "50개 체크리스트" 명시 | `before/12-manual.png` |
| 이용약관 | `/terms` | SUSPECT | 모든 절이 "정식 법무 검토 후 교체 예정" 자리표시자 — 운영 환경 노출 위험 | (인라인 텍스트) |
| 개인정보처리방침 | `/privacy` | SUSPECT | terms와 동일하게 자리표시자 | (인라인 텍스트) |
| API credentials/data sources | `/settings/budget/api_credentials`, `/settings/budget/data_sources` | N/A | 게스트 세션 또는 라우트 부재 — 모두 404 | (HTTP 404) |

## 🚨 도메인 정확성 위반 / 의심

1. **취득세 산정이 평균가 기반 정적값** (`/onboarding` step2, `/settings/budget`)
   - 화면: "취득세 528만원 (평균 4.8억 × 1.1%)"
   - 문제: 사용자의 실제 입찰가가 6,540만원으로 산출되는데 취득세는 여전히 4.8억 기준. 취득세는 **낙찰가 기반**(주택 무주택 6억 이하 1.1%, 6~9억 1.1~3.3% 누진, 9억 초과 3.3%, 다주택자 가중 등)으로 산정해야 정확.
   - 제안: 입력 입찰가에 연동, 무주택/다주택 단계 누진세율 반영.
   - 증거: `before/02-onboarding-step2.png`, `before/10-settings-budget.png`

2. **이사비 기본 50만원이 비현실적** (`/onboarding` step2)
   - 화면: "이사비 50만원 (면적 기준 이사비)" — 소형(10~15평) 가정.
   - 문제: 2026년 기준 소형 이사 평균비용 80~150만원. 50만원은 도배·청소·이사를 분리하지 않은 단순값.
   - 제안: 60~120만원 범위 또는 "체크 해제 후 직접 입력 권장" 안내.
   - 증거: `before/02-onboarding-step2.png`

3. **ST-Q2 법률 근거 부정확** (`/eviction_guide/simulator/question/ST-Q2`)
   - 화면: "임차인의 미회수 보증금 잔액을 산정하고 인수 협상을 시작했나요?" + 법률 근거 "주택임대차보호법 제3조의5".
   - 문제: 주임법 **제3조의5는 임차권등기명령** 제도. 매수인이 선순위 임차인의 미회수 보증금을 인수해야 한다는 근거는 **제3조 제4항**(대항력 효과로 매수인이 임대인 지위 승계) 또는 제3조의2(우선변제권). 인용 조문 교체 필요.
   - 증거: fetch 응답 (보고서 내 ST-Q2 항목)

4. **관심 지역 기본값 "제주특별자치도"** (`/onboarding`, `/properties`, `/search`)
   - 화면: 모든 선택지 상단에 "제주특별자치도" selected.
   - 문제: 전국 부동산 경매 도구에서 사용자 기반이 가장 큰 수도권을 우선 노출하는 게 자연스러움. UX/비즈니스 가치 모두 약함.
   - 제안: "서울특별시" 또는 사용자 IP 기반 기본값 + "전체" 옵션.

5. **법원 목록 첫 행 "제주지방법원"** (`/properties` 사건번호 폼)
   - 화면: 콤보박스에서 강릉/거창/경주… 가나다 순인데 맨 위만 제주지방법원.
   - 문제: 정렬 일관성 깨짐. 가나다 순이라면 강릉지원이 먼저.
   - 증거: `before/05-properties-empty.png`

6. **행정구역 옵션 중복** (`/onboarding`, `/properties`, `/search`)
   - 화면: "강원도" + "강원특별자치도", "전라북도" + "전북특별자치도" 동시 노출.
   - 문제: 2023년 강원특별자치도, 2024년 전북특별자치도로 전환됨. 구·신 행정명을 모두 노출하면 사용자가 어느 쪽을 선택할지 혼란. 시드 데이터 정리 필요.
   - 증거: `before/01-onboarding-step1.png`

## 🧪 엣지케이스에서 깨진 동작

1. **`/settings/budget/update_region` 500 Internal Server Error** (`/onboarding`, region 변경)
   - 트리거: 관심 지역 select 변경 시 ajax POST.
   - 영향: 매 페이지 로드마다 콘솔에 500 노이즈, 지역 설정이 실제로 저장되는지 확신 불가.
   - 증거: 콘솔 로그, `before/02-onboarding-step2.png`

2. **`/settings/budget` GET 시점에 422 Unprocessable Content** (`/settings/budget`)
   - 트리거: 페이지를 단순 GET만 해도 422가 함께 떨어짐 (Turbo Stream 응답 처리 추정).
   - 영향: 정상 페이지인데 콘솔에 422가 남아 사용자/QA에게 혼란.
   - 증거: `error/13-settings-budget-422-on-load.png`, 콘솔 메시지

3. **LTV 200% 입력 silent ignore** (`/settings/budget` 폼)
   - 트리거: `budget_setting[loan_ratio]=200` 으로 POST.
   - 응답: 200 OK, 별도 에러 메시지 없음, 저장값은 70%로 그대로 유지(silent).
   - 문제: 사용자에게 입력이 무시되었다는 피드백이 전혀 없음. 범위 초과 시 명시적 에러 또는 클램프 안내 필요.

4. **bulk_import 빈 입력 통과** (`/properties/bulk_import`)
   - 트리거: `bulk_input=""` POST.
   - 응답: 200 OK + "실패 0건" 텍스트. 폼이 의미 있게 막지 못함.
   - 제안: 1건 이상 요구 또는 "입력이 비어 있습니다" 메시지.

5. **사건번호 검증 메시지가 매물 폼에는 노출되나 형식 가이드 부재**
   - 잘못된 사건번호 입력 시 422 + "사건번호 형식이 올바르지 않습니다. (예: 2026타경1234)" 정상 표시. ✓
   - 하지만 정상 사건번호로 추가 시 redirect가 `/eviction_guide/simulator/select_type`으로 가는 어색한 흐름(미인증/세션 상태 관련). 사용자가 "왜 시뮬레이터로 가지?"라고 느낄 수 있음.

## 📉 비즈니스 규칙 모순

1. **예비비 산식과 최대입찰가 산식의 분리**
   - 최대입찰가 = (현금 − 예비비) / (1 − LTV) 는 정확하게 작동 ((3000−1038)/0.3 ≈ 6,540만원).
   - 그러나 예비비를 구성하는 취득세·수선비·법무사비는 **4.8억 가정으로 고정**.
   - 결과적으로 사용자의 가용 입찰가는 6,540만원인데 예비비는 4.8억 기준 → **소형 매물 실제 인수원가 대비 과대 잡힘**. invariant: "예비비 ≤ 입찰가의 합리적 비율"이 깨짐.
   - 한 줄: 이 화면만 봐도 사용자가 1,000만원짜리 매물을 입찰할 수 없게 막아버림.

2. **onboarding step3 → step2 회귀**
   - step3에서 submit 후 다시 step2 화면이 보여 사용자가 "되돌아갔나?" 오인 가능. 두 번째 submit이 비로소 `/onboarding/complete`로 진행.
   - 결과: 진행 단계 표시(1·2·3) UI와 실제 step 진행이 어긋날 수 있음.

3. **시뮬레이터 occupant_type 4종 vs 명도 가이드 4종**
   - 시뮬레이터: junior_tenant / senior_tenant / debtor_owner / illegal_occupant
   - 가이드 페이지(S1~S15, JT/ST/DO/IO) 와 1:1 매칭됨. ✓ 일관성 OK.

## 🔎 데이터 신뢰성 의심

1. **기본값(reserve_fund_defaults) 비현실** — 이사비 50만원(소형) 등 (위 도메인 §2 참조).
2. **시드 매물 0건** — `/properties`, `/search_results`, `/properties/1` 모두 빈 상태. 따라서 `rights_analysis_report`, `inspections`, `inspections/tabs/:tab_key`, `source_doc_review`, `analyses/:id/*` 깊이 있는 검증 불가. 최근 commit `1e10969 feat(seed-check): warn on empty critical seed tables`가 정확히 이 문제를 경고하기 위해 추가된 것으로 보이며, dev 환경에서 시드 채워주는 작업이 누락된 듯.
3. **약관/개인정보처리방침 자리표시자** — `/terms`, `/privacy` 모든 절이 "정식 법무 검토 후 교체 예정". 운영 노출 시 컴플라이언스 리스크 (특히 외부 LLM API 제공사를 명시한 §4와 그 외 절의 비대칭).
4. **법원 콤보박스 상단 "제주지방법원"** — 가나다 정렬과 어긋남, 시드/seed 정렬 버그 가능성.
5. **관심 지역 기본값 "제주특별자치도"** — 두 차례(예산 설정, 검색) 동일하게 잡혀 시드 default 문제로 추정.

## 검증된 도메인 표현 (PASS)

- 매각허가결정 후 즉시항고 기간 1주, 대금지급기한 ~30일 ✓
- 인도명령 + 점유이전금지가처분 동시 신청 시점(잔금 납부일) ✓
- 명도소송 1심 6~12개월, 강제집행 1~3개월 ✓
- 주임법 제3조 (대항력 = 주택 인도 + 전입신고) ✓
- 민사집행법 제136조 본문/단서(인도명령/불가시 명도소송) ✓
- 4가지 점유자 유형 분기 ✓
- 취득세율 1.1% (6억 이하 무주택 기준) ✓ (단, 입찰가 연동되지 않는 게 별개 문제)
- 산식 (현금 − 예비비) / (1 − LTV) → 최대입찰가 ✓

## 한 줄 요약

총 19개 플로우 — passed 9 / suspect 8 / N/A (시드 부재) 2 / failed 0. 🚨 도메인 의심 6건, 🧪 엣지케이스 깨짐 5건. 가장 시급한 수정: (a) 취득세를 입찰가 연동으로 변경, (b) ST-Q2 법률 근거 교체(제3조의5 → 제3조 제4항/제3조의2), (c) `/settings/budget/update_region` 500 에러, (d) 시드 매물·약관 본문 채우기, (e) LTV 200% 같은 범위 초과 silent ignore.
