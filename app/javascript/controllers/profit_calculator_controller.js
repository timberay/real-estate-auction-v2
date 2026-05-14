import { Controller } from "@hotwired/stimulus"
import { KOR_EOK_TO_MAN, KOR_CHEON_TO_MAN } from "controllers/constants"

// Real-time net profit calculator for pre-bid estimation.
// All amounts in 만원 (10,000 KRW). Tax rates are simplified
// effective rates — see spec section 5 for rationale.
export default class extends Controller {
  static targets = [
    "bidDisplay", "bidSlider", "bidPercent",
    "saleDisplay", "saleHidden",
    "ownership", "holdingPeriod",
    "resultArea", "emptyState",
    "totalOutlay", "totalCosts", "netProfit", "roi",
    "profitCard", "roiCard", "profitLabel", "roiLabel",
    "rowSalePrice", "rowBidPrice", "rowAssumed",
    "rowAcqTax", "rowAcqTaxNote", "rowScrivener", "rowRepair",
    "rowMoving", "rowMaintenance", "rowCgt", "rowCgtNote",
    "rowNetProfit", "rowRoi",
    "dsrWarning", "dsrRatioLabel", "dsrThresholdLabel",
    "residency", "residencyRow", "highValueWarning"
  ]

  static values = {
    minBid: Number,
    appraisal: Number,
    assumedAmount: Number,
    scrivenerFee: Number,
    repairCost: Number,
    movingCost: Number,
    maintenanceFee: Number,
    taxBrackets: Object,
    cgtMatrix: Object,
    preciseMode: Boolean,
    areaOver85: Boolean,
    residencyMet: Boolean,
    highValueThreshold: Number,
    dsrEnabled: Boolean,
    dsrLoanRatio: Number,
    dsrAnnualIncome: Number,
    dsrExistingDebtMonthly: Number,
    dsrAnnualRate: Number,
    dsrTermYears: Number,
    dsrThreshold: Number
  }

  // F-C-1 — bid range (in 만원) where the precise progressive formula
  // `(가액(억) × 2/3 − 3) / 100` overrides the bracket midpoint. Mirrors
  // the 6~9억 row in `AcquisitionTaxRate`.
  static PRECISE_BRACKET_MIN_MANWON = 60000
  static PRECISE_BRACKET_MAX_MANWON = 90000

  // Flat 농어촌특별세 surcharge baked into `area_over_85=true` rows of the
  // simplified seed table; re-applied on top of the precise formula so the
  // over-85 case stays differentiated from under-85.
  static AREA_OVER_85_SURCHARGE = 0.002

  // T1.2 — server-driven CGT matrix (TransferTaxCalculator.matrix_for) is
  // injected via cgtMatrixValue. This constant is the conservative fallback
  // when the matrix is empty (budget_setting nil or unseeded property_type).
  static CGT_FALLBACK_RATE = 0.20

  // Fallback rate when the server emitted no brackets for the selected tier
  // (e.g. budget_setting was nil, or a tax-table gap for this combination).
  static ACQ_TAX_FALLBACK_RATE = 0.011

  connect() {
    this.bidDisplayTarget.value = this.formatEok(this.minBidValue)
    this.bidSliderTarget.value = this.minBidValue
    this.updateBidPercent(this.minBidValue)
    if (this.appraisalValue > 0) {
      this.saleDisplayTarget.value = this.formatEok(this.appraisalValue)
      this.saleHiddenTarget.value = this.appraisalValue
    }
    this.calculate()
  }

  // --- Bid price: slider ↔ input sync ---

  onBidSlider() {
    const manwon = parseInt(this.bidSliderTarget.value, 10)
    this.bidDisplayTarget.value = this.formatEok(manwon)
    this.updateBidPercent(manwon)
    this.calculate()
  }

  onBidInput() {
    const manwon = this.parseKorean(this.bidDisplayTarget.value)
    if (manwon > 0) {
      this.bidSliderTarget.value = manwon
      this.updateBidPercent(manwon)
    }
    this.calculate()
  }

  onBidBlur() {
    const manwon = this.parseKorean(this.bidDisplayTarget.value)
    if (manwon > 0) {
      this.bidDisplayTarget.value = this.formatEok(manwon)
      this.bidSliderTarget.value = manwon
      this.updateBidPercent(manwon)
    }
    this.calculate()
  }

  // --- Sale price input ---

  onSaleInput() {
    const manwon = this.parseKorean(this.saleDisplayTarget.value)
    this.saleHiddenTarget.value = manwon > 0 ? manwon : ""
    this.calculate()
  }

  onSaleBlur() {
    const manwon = this.parseKorean(this.saleDisplayTarget.value)
    if (manwon > 0) {
      this.saleDisplayTarget.value = this.formatEok(manwon)
      this.saleHiddenTarget.value = manwon
    } else {
      this.saleDisplayTarget.value = ""
      this.saleHiddenTarget.value = ""
    }
    this.calculate()
  }

  // --- Core calculation ---

  calculate() {
    const bidPrice = this.parseKorean(this.bidDisplayTarget.value)
    const salePrice = parseInt(this.saleHiddenTarget.value, 10) || 0

    if (salePrice <= 0) {
      this.resultAreaTarget.classList.add("hidden")
      this.emptyStateTarget.classList.remove("hidden")
      return
    }

    this.resultAreaTarget.classList.remove("hidden")
    this.emptyStateTarget.classList.add("hidden")

    const ownership = this.selectedOwnership()
    const holdingPeriod = this.selectedHoldingPeriod()

    // Costs from budget settings
    const scrivenerFee = this.scrivenerFeeValue
    const repairCost = this.repairCostValue
    const movingCost = this.movingCostValue
    const maintenanceFee = this.maintenanceFeeValue
    const assumedAmount = this.assumedAmountValue

    // Investment
    const totalInvestment = bidPrice + assumedAmount

    // Tax calculations — bracket-based per the AcquisitionTaxRate table
    // (kept in sync with the server-rendered tax-brackets value).
    const acqTaxRate = this.findAcqTaxRate(bidPrice, ownership)
    const acquisitionTax = Math.round(bidPrice * acqTaxRate)

    // All costs (for net profit)
    const allCosts = acquisitionTax + scrivenerFee + repairCost + movingCost + maintenanceFee

    // Deductible costs only (for taxable gain)
    const deductibleCosts = acquisitionTax + scrivenerFee + repairCost

    // Capital gains tax (T1.2 — server matrix lookup, fallback if missing)
    const taxableGain = salePrice - totalInvestment - deductibleCosts
    const matrix = this.cgtMatrixValue || {}
    const effectiveTier = this.effectiveOwnershipTier(ownership, holdingPeriod)
    const cgtRate = matrix[effectiveTier]?.[holdingPeriod] ?? this.constructor.CGT_FALLBACK_RATE
    const capitalGainsTax = taxableGain > 0 ? Math.round(taxableGain * cgtRate) : 0

    // T1.2-F-B — toggle the residency row + 12억 banner whenever ownership /
    // holding / sale price could change their visibility.
    this.updateResidencyRowVisibility(ownership, holdingPeriod)
    this.updateHighValueWarning(ownership, holdingPeriod, salePrice)

    // Final results
    const netProfit = salePrice - totalInvestment - allCosts - capitalGainsTax
    const totalOutlay = totalInvestment + allCosts
    const totalCostsAll = allCosts + capitalGainsTax
    const roiPercent = totalOutlay > 0 ? (netProfit / totalOutlay * 100) : 0

    // Update UI
    this.renderResults({
      salePrice, bidPrice, assumedAmount,
      acquisitionTax, acqTaxRate,
      scrivenerFee, repairCost, movingCost, maintenanceFee,
      capitalGainsTax, cgtRate,
      netProfit, totalOutlay, totalCostsAll, roiPercent
    })

    // T1.5 — DSR warning banner reflects the *current* bid (loan principal
    // = bid * loan_ratio). Hidden entirely if DSR inputs are missing.
    this.updateDsrWarning(bidPrice)
  }

  // --- T1.2-F-B: 1주택 거주요건 toggle + 12억 advisory ---

  // Re-runs the calculation when the residency checkbox flips. The full
  // calculation is the cleanest path because the residency-driven rate
  // change cascades into net profit / ROI / DSR rendering.
  onResidencyChange() {
    this.calculate()
  }

  // The calculator stores the residency_met state as a Boolean value.
  // Bind reads from the checkbox itself so the value stays the source of
  // truth even if calculate() runs before the change event fires.
  get residencyMet() {
    if (!this.hasResidencyTarget) return this.residencyMetValue
    return this.residencyTarget.checked
  }

  // 1세대 1주택 비과세는 보유 2년 + 거주 2년 요건이 필요하다. 거주 요건이
  // 충족되지 않은 1주택 over_2y 양도는 비과세가 아니라 일반 양도세 대상.
  // Calculator 서버 단의 effective_household_tier 와 같은 로직이다.
  effectiveOwnershipTier(ownership, holdingPeriod) {
    if (ownership === "single_home" && holdingPeriod === "over_2y" && !this.residencyMet) {
      return "homeless"
    }
    return ownership
  }

  // 거주요건 row 는 1주택 + 2년 이상 보유 조합에서만 의미가 있다. 다른
  // 조합에서는 숨겨서 사용자 혼선을 줄인다.
  updateResidencyRowVisibility(ownership, holdingPeriod) {
    if (!this.hasResidencyRowTarget) return
    const visible = ownership === "single_home" && holdingPeriod === "over_2y"
    this.residencyRowTarget.classList.toggle("hidden", !visible)
  }

  // 양도가액 > 12억 + 1주택 + over_2y + 거주요건 충족인 경우 본 계산기는
  // 단순 비과세를 가정하지만 실제로는 12억 초과분에 대해 분리 과세가
  // 적용되므로 사용자에게 advisory banner 를 노출한다.
  updateHighValueWarning(ownership, holdingPeriod, salePriceManwon) {
    if (!this.hasHighValueWarningTarget) return
    const threshold = this.highValueThresholdValue || 0
    const triggered =
      ownership === "single_home" &&
      holdingPeriod === "over_2y" &&
      this.residencyMet &&
      salePriceManwon > threshold
    this.highValueWarningTarget.classList.toggle("hidden", !triggered)
  }

  // --- DSR (T1.5) ---

  updateDsrWarning(bidPriceManwon) {
    if (!this.dsrEnabledValue || !this.hasDsrWarningTarget) {
      if (this.hasDsrWarningTarget) this.dsrWarningTarget.classList.add("hidden")
      return
    }

    const principalManwon = Math.round(bidPriceManwon * this.dsrLoanRatioValue)
    const ratio = this.computeDsrRatio(principalManwon)
    const threshold = this.dsrThresholdValue || 0.40

    if (ratio > threshold) {
      this.dsrWarningTarget.classList.remove("hidden")
      if (this.hasDsrRatioLabelTarget) {
        this.dsrRatioLabelTarget.textContent = `DSR ${(ratio * 100).toFixed(1)}%`
      }
      if (this.hasDsrThresholdLabelTarget) {
        this.dsrThresholdLabelTarget.textContent = (threshold * 100).toFixed(0)
      }
    } else {
      this.dsrWarningTarget.classList.add("hidden")
    }
  }

  // 원리금균등상환 산식 — 서버 DsrCalculator#compute_monthly_payment 미러.
  computeDsrRatio(principalManwon) {
    const annualIncome = this.dsrAnnualIncomeValue
    if (annualIncome <= 0) return 0

    const months = (this.dsrTermYearsValue || 30) * 12
    const annualRate = this.dsrAnnualRateValue || 0.045
    const r = annualRate / 12

    let monthlyPayment = 0
    if (principalManwon > 0) {
      if (r === 0) {
        monthlyPayment = principalManwon / months
      } else {
        const pow = Math.pow(1 + r, months)
        monthlyPayment = principalManwon * (r * pow) / (pow - 1)
      }
    }

    const annualDebt = (monthlyPayment + this.dsrExistingDebtMonthlyValue) * 12
    return annualDebt / annualIncome
  }

  // --- Rendering ---

  renderResults(r) {
    const positive = r.netProfit >= 0

    // Summary cards
    this.totalOutlayTarget.textContent = this.formatEok(r.totalOutlay)
    this.totalCostsTarget.textContent = this.formatEok(r.totalCostsAll)
    this.netProfitTarget.textContent = (positive ? "" : "-") + this.formatEok(Math.abs(r.netProfit))
    this.roiTarget.textContent = `${r.roiPercent.toFixed(1)}%`

    // Card colors
    const profitBg = positive
      ? "bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800"
      : "bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800"
    const profitText = positive
      ? "text-green-700 dark:text-green-400"
      : "text-red-700 dark:text-red-400"

    this.profitCardTarget.className = `rounded-lg p-3 text-center ${profitBg}`
    this.roiCardTarget.className = `rounded-lg p-3 text-center ${profitBg}`
    this.profitLabelTarget.className = `text-sm mb-1 ${positive ? "text-green-600 dark:text-green-400" : "text-red-600 dark:text-red-400"}`
    this.roiLabelTarget.className = `text-sm mb-1 ${positive ? "text-green-600 dark:text-green-400" : "text-red-600 dark:text-red-400"}`
    this.netProfitTarget.className = `text-xl font-extrabold ${profitText}`
    this.roiTarget.className = `text-xl font-extrabold ${profitText}`

    // Breakdown rows (show "-" prefix only for non-zero amounts)
    this.rowSalePriceTarget.textContent = this.formatEok(r.salePrice)
    this.rowBidPriceTarget.textContent = this.formatDeduction(r.bidPrice)
    this.rowAssumedTarget.textContent = this.formatDeduction(r.assumedAmount)
    this.rowAcqTaxTarget.textContent = this.formatDeduction(r.acquisitionTax)
    this.rowAcqTaxNoteTarget.textContent = `추정 ~${(r.acqTaxRate * 100).toFixed(1)}% (필요경비)`
    this.rowScrivenerTarget.textContent = this.formatDeduction(r.scrivenerFee)
    this.rowRepairTarget.textContent = this.formatDeduction(r.repairCost)
    this.rowMovingTarget.textContent = this.formatDeduction(r.movingCost)
    this.rowMaintenanceTarget.textContent = this.formatDeduction(r.maintenanceFee)
    this.rowCgtTarget.textContent = this.formatDeduction(r.capitalGainsTax)
    this.rowCgtNoteTarget.textContent = `추정 ~${(r.cgtRate * 100).toFixed(0)}% (필요경비만 공제)`

    // Bottom row
    this.rowNetProfitTarget.textContent = (positive ? "" : "-") + this.formatEok(Math.abs(r.netProfit))
    this.rowNetProfitTarget.className = `px-4 py-3 text-right text-lg font-extrabold ${profitText}`
    this.rowRoiTarget.textContent = `수익률 ${r.roiPercent.toFixed(1)}%`
    this.rowRoiTarget.className = `px-4 py-3 text-right font-semibold ${profitText}`
  }

  // --- Helpers ---

  selectedOwnership() {
    const checked = this.ownershipTargets.find(el => el.checked)
    return checked ? checked.value : "homeless"
  }

  // Resolves the acquisition tax rate for a given bid amount + tier by
  // walking the server-supplied bracket list. Mirrors the SQL bracket
  // lookup in AcquisitionTaxCalculator#lookup_row. When precise mode is
  // opted in (F-C-1) and the bid falls inside the 6~9억 bracket, returns
  // the progressive formula rate instead of the bracket midpoint.
  findAcqTaxRate(bidManwon, tier) {
    if (this.preciseModeValue && this.isInPreciseBracket(bidManwon)) {
      return this.preciseProgressiveRate(bidManwon) +
             (this.areaOver85Value ? this.constructor.AREA_OVER_85_SURCHARGE : 0)
    }

    const brackets = this.taxBracketsValue?.[tier] || []
    for (const b of brackets) {
      if (b.max === null || b.max === undefined || bidManwon < b.max) {
        return parseFloat(b.rate)
      }
    }
    // Fall through (no bracket matched or table empty): use the last bracket's
    // rate when available, else the constant fallback.
    if (brackets.length > 0) return parseFloat(brackets[brackets.length - 1].rate)
    return this.constructor.ACQ_TAX_FALLBACK_RATE
  }

  isInPreciseBracket(bidManwon) {
    return bidManwon >= this.constructor.PRECISE_BRACKET_MIN_MANWON &&
           bidManwon < this.constructor.PRECISE_BRACKET_MAX_MANWON
  }

  // (가액(억) × 2/3 − 3) / 100 — the base rate, in decimal.
  preciseProgressiveRate(bidManwon) {
    const bidEok = bidManwon / 10000
    return (bidEok * (2 / 3) - 3) / 100
  }

  selectedHoldingPeriod() {
    const checked = this.holdingPeriodTargets.find(el => el.checked)
    return checked ? checked.value : "over_2y"
  }

  updateBidPercent(manwon) {
    if (this.appraisalValue > 0) {
      const pct = ((manwon / this.appraisalValue) * 100).toFixed(0)
      this.bidPercentTarget.textContent = `감정가의 ${pct}%`
    }
  }

  // Format a deduction amount: skip "-" prefix for zero values
  formatDeduction(manwon) {
    if (!manwon || manwon <= 0) return "0만원"
    return `-${this.formatEok(manwon)}`
  }

  // Parse Korean currency text to 만원 integer
  parseKorean(text) {
    if (!text || text.trim() === "") return 0
    let str = text.replace(/,/g, "").replace(/\s+/g, "").replace(/만원?/g, "")

    const eokMatch = str.match(/(\d+)억(.*)/)
    if (eokMatch) {
      const eok = parseInt(eokMatch[1], 10) * KOR_EOK_TO_MAN
      let remainder = 0
      const rest = eokMatch[2]
      if (rest) {
        const cheonMatch = rest.match(/(\d+)천/)
        if (cheonMatch) {
          remainder = parseInt(cheonMatch[1], 10) * KOR_CHEON_TO_MAN
        } else {
          const digits = rest.replace(/[^0-9]/g, "")
          if (digits) remainder = parseInt(digits, 10)
        }
      }
      return eok + remainder
    }

    const cheonOnly = str.match(/(\d+)천/)
    if (cheonOnly) return parseInt(cheonOnly[1], 10) * KOR_CHEON_TO_MAN

    const digits = str.replace(/[^0-9]/g, "")
    return digits ? parseInt(digits, 10) : 0
  }

  // Format 만원 integer to Korean 억 display
  formatEok(manwon) {
    if (!manwon || manwon <= 0) return "0만원"
    const eok = Math.floor(manwon / KOR_EOK_TO_MAN)
    const remainder = manwon % KOR_EOK_TO_MAN
    if (eok >= 1 && remainder > 0) {
      return `${eok}억 ${remainder.toLocaleString("ko-KR")}만원`
    } else if (eok >= 1) {
      return `${eok}억`
    }
    return `${manwon.toLocaleString("ko-KR")}만원`
  }
}
