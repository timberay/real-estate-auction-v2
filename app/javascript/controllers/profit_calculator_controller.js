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
    "rowNetProfit", "rowRoi"
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
    preciseMode: Boolean,
    areaOver85: Boolean
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

  // Effective capital gains tax rates by ownership tier + holding period.
  // Keys mirror AcquisitionTaxRate::HOUSEHOLD_TIERS.
  static CGT_RATES = {
    homeless:         { under_1y: 0.70, "1to2y": 0.60, over_2y: 0.00 },
    single_home:      { under_1y: 0.70, "1to2y": 0.60, over_2y: 0.00 },
    multi_home_2:     { under_1y: 0.70, "1to2y": 0.60, over_2y: 0.40 },
    multi_home_3plus: { under_1y: 0.70, "1to2y": 0.60, over_2y: 0.40 }
  }

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

    // Capital gains tax
    const taxableGain = salePrice - totalInvestment - deductibleCosts
    const cgtRate = this.constructor.CGT_RATES[ownership]?.[holdingPeriod] || 0.20
    const capitalGainsTax = taxableGain > 0 ? Math.round(taxableGain * cgtRate) : 0

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
