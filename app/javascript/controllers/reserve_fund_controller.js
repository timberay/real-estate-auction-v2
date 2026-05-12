import { Controller } from "@hotwired/stimulus"
import { KOR_EOK_TO_MAN } from "controllers/constants"

// Manages Step 2 reserve fund form:
// - Area / property-type / household-tier changes trigger auto-recalculation
// - "자동 계산" checkbox: when checked, fills reserve items and flips the
//   acquisition_tax input to readonly while running bracket iteration to
//   derive the tax from the user's cash + LTV + non-tax reserves.
// - Maintains running total of all reserve items
export default class extends Controller {
  static targets = [
    "autoCalc", "propertyType",
    "areaCategory", "householdTier", "acquisitionTaxAuto",
    "repairCost", "acquisitionTax", "scrivenerFee",
    "movingCost", "maintenanceFee", "total",
    "repairCostHint", "acquisitionTaxHint", "scrivenerFeeHint",
    "movingCostHint", "maintenanceFeeHint",
    "summaryBox", "warning", "submitBtn"
  ]
  static values = {
    defaults: Object, // reserve_fund_defaults grouped by property_type_id
    availableCash: { type: Number, default: 0 },
    taxBrackets: { type: Array, default: [] },
    loanRatio: { type: Number, default: 0.7 }
  }

  connect() {
    if (this.hasAcquisitionTaxTarget && this.hasAutoCalcTarget) {
      const auto = this.autoCalcTarget.checked
      this.acquisitionTaxTarget.readOnly = auto
      this.acquisitionTaxTarget.classList.toggle("bg-slate-100", auto)
    }
    this.updateTotal()
    if (this.hasAutoCalcTarget && this.autoCalcTarget.checked) {
      this.applyDefaults()
    }
  }

  // Called when "자동 계산" checkbox changes
  toggleAutoCalc() {
    const auto = this.autoCalcTarget.checked
    if (this.hasAcquisitionTaxAutoTarget) {
      this.acquisitionTaxAutoTarget.value = auto ? "true" : "false"
    }
    if (this.hasAcquisitionTaxTarget) {
      this.acquisitionTaxTarget.readOnly = auto
      this.acquisitionTaxTarget.classList.toggle("bg-slate-100", auto)
    }
    if (auto) {
      this.applyDefaults()
    }
    this.updateTotal()
  }

  // Called when property type changes
  propertyTypeChanged() {
    if (this.hasAutoCalcTarget && this.autoCalcTarget.checked) {
      this.applyDefaults()
    }
    this.updateTotal()
  }

  // Called when area dropdown changes
  areaChanged() {
    if (this.hasAutoCalcTarget && this.autoCalcTarget.checked) {
      this.applyDefaults()
    }
    this.updateTotal()
  }

  // Called when household tier dropdown changes
  householdTierChanged() {
    if (this.hasAutoCalcTarget && this.autoCalcTarget.checked && this.hasAcquisitionTaxTarget) {
      this.acquisitionTaxTarget.value = this.computeAuto()
    }
    this.updateTotal()
  }

  // Apply default reserve values based on property type and average area.
  // Acquisition tax is now derived from bracket iteration (computeAuto)
  // rather than from a static average price × rate.
  applyDefaults() {
    const propertyTypeId = this.propertyTypeTarget.value
    const defaults = this.defaultsValue[propertyTypeId]

    if (!defaults || defaults.length === 0) return

    const key = this.areaCategoryTarget.value
    if (!key) return

    const categories = {
      small: { min: 0, max: 40 }, mid_small: { min: 40, max: 60 },
      mid: { min: 60, max: 85 }, mid_large: { min: 85, max: 102 },
      large: { min: 102, max: 150 }
    }
    const cat = categories[key]
    if (!cat) return

    const match = defaults.find(d =>
      d.area_range_min === cat.min && d.area_range_max === cat.max
    )

    if (match) {
      this.repairCostTarget.value = match.repair_cost
      this.scrivenerFeeTarget.value = match.scrivener_fee
      this.movingCostTarget.value = match.moving_cost
      this.maintenanceFeeTarget.value = match.maintenance_fee
      if (this.hasAcquisitionTaxTarget) {
        this.acquisitionTaxTarget.value = this.computeAuto()
      }
      this.updateTotal()
      this.updateHints(match)
      this.dispatch("changed")
    }
  }

  // Closed-form bracket iteration mirroring BudgetCalculationService.
  // Returns acquisition tax in 만원 (integer).
  computeAuto() {
    const cash = this.availableCashValue
    const loanRatio = this.loanRatioValue
    const brackets = this.taxBracketsValue

    if (!brackets || brackets.length === 0) return 0

    const reserveExclTax = [
      this.repairCostTarget, this.scrivenerFeeTarget,
      this.movingCostTarget, this.maintenanceFeeTarget
    ].reduce((sum, f) => sum + (parseInt(String(f.value).replace(/,/g, ""), 10) || 0), 0)

    if (cash - reserveExclTax <= 0) return 0

    for (const b of brackets) {
      const rate = parseFloat(b.rate)
      const denom = 1 - loanRatio + rate
      const candidate = Math.floor((cash - reserveExclTax) / denom)
      if (b.max == null || candidate <= b.max) {
        return Math.round(rate * candidate)
      }
    }
    return 0
  }

  updateHints(match) {
    const priceLabel = `평균 ${(match.average_price / KOR_EOK_TO_MAN).toFixed(1)}억`

    if (this.hasRepairCostHintTarget)
      this.repairCostHintTarget.textContent = `${priceLabel} 기준 수선비`
    if (this.hasAcquisitionTaxHintTarget) {
      const tax = this.computeAuto()
      this.acquisitionTaxHintTarget.textContent = `예상 낙찰가 기반 ${tax.toLocaleString("ko-KR")}만원`
    }
    if (this.hasScrivenerFeeHintTarget)
      this.scrivenerFeeHintTarget.textContent = `${priceLabel} 기준 법무사 수수료`
    if (this.hasMovingCostHintTarget)
      this.movingCostHintTarget.textContent = `면적 기준 이사비`
    if (this.hasMaintenanceFeeHintTarget)
      this.maintenanceFeeHintTarget.textContent = `미납 관리비 (없으면 0)`
  }

  updateTotal() {
    // Keep acquisition_tax in sync when auto mode is on and reserves change.
    if (this.hasAutoCalcTarget && this.autoCalcTarget.checked && this.hasAcquisitionTaxTarget) {
      this.acquisitionTaxTarget.value = this.computeAuto()
    }

    const fields = [
      this.repairCostTarget,
      this.acquisitionTaxTarget,
      this.scrivenerFeeTarget,
      this.movingCostTarget,
      this.maintenanceFeeTarget
    ]
    const total = fields.reduce((sum, field) => {
      return sum + (parseInt(String(field.value).replace(/,/g, ""), 10) || 0)
    }, 0)

    this.totalTarget.textContent = total.toLocaleString("ko-KR")

    // Compare with available cash
    const exceeded = this.availableCashValue > 0 && total > this.availableCashValue

    if (this.hasWarningTarget)
      this.warningTarget.classList.toggle("hidden", !exceeded)

    if (this.hasSummaryBoxTarget) {
      this.summaryBoxTarget.classList.toggle("bg-red-50", exceeded)
      this.summaryBoxTarget.classList.toggle("dark:bg-red-900/20", exceeded)
      this.summaryBoxTarget.classList.toggle("border-red-300", exceeded)
      this.summaryBoxTarget.classList.toggle("dark:border-red-700", exceeded)
      this.summaryBoxTarget.classList.toggle("bg-slate-50", !exceeded)
      this.summaryBoxTarget.classList.toggle("dark:bg-slate-800", !exceeded)
      this.summaryBoxTarget.classList.toggle("border-slate-200", !exceeded)
      this.summaryBoxTarget.classList.toggle("dark:border-slate-700", !exceeded)
    }

    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = exceeded
      this.submitBtnTarget.classList.toggle("opacity-50", exceeded)
      this.submitBtnTarget.classList.toggle("cursor-not-allowed", exceeded)
    }
  }
}
