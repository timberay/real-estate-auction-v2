import { Controller } from "@hotwired/stimulus"

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
    maintenanceFee: Number
  }

  // Effective acquisition tax rates by ownership type
  static ACQ_TAX_RATES = {
    no_home: 0.011,
    one_home: 0.011,
    multi_home: 0.084
  }

  // Effective capital gains tax rates by ownership + holding period
  static CGT_RATES = {
    no_home:    { under_1y: 0.70, "1to2y": 0.60, over_2y: 0.20 },
    one_home:   { under_1y: 0.70, "1to2y": 0.60, over_2y: 0.00 },
    multi_home: { under_1y: 0.70, "1to2y": 0.60, over_2y: 0.40 }
  }

  connect() {
    this.bidDisplayTarget.value = this.formatEok(this.minBidValue)
    this.bidSliderTarget.value = this.minBidValue
    this.updateBidPercent(this.minBidValue)
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

    // Tax calculations
    const acqTaxRate = this.constructor.ACQ_TAX_RATES[ownership] || 0.011
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
    return checked ? checked.value : "no_home"
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
      const eok = parseInt(eokMatch[1], 10) * 10000
      let remainder = 0
      const rest = eokMatch[2]
      if (rest) {
        const cheonMatch = rest.match(/(\d+)천/)
        if (cheonMatch) {
          remainder = parseInt(cheonMatch[1], 10) * 1000
        } else {
          const digits = rest.replace(/[^0-9]/g, "")
          if (digits) remainder = parseInt(digits, 10)
        }
      }
      return eok + remainder
    }

    const cheonOnly = str.match(/(\d+)천/)
    if (cheonOnly) return parseInt(cheonOnly[1], 10) * 1000

    const digits = str.replace(/[^0-9]/g, "")
    return digits ? parseInt(digits, 10) : 0
  }

  // Format 만원 integer to Korean 억 display
  formatEok(manwon) {
    if (!manwon || manwon <= 0) return "0만원"
    const eok = Math.floor(manwon / 10000)
    const remainder = manwon % 10000
    if (eok >= 1 && remainder > 0) {
      return `${eok}억 ${remainder.toLocaleString("ko-KR")}만원`
    } else if (eok >= 1) {
      return `${eok}억`
    }
    return `${manwon.toLocaleString("ko-KR")}만원`
  }
}
