import { Controller } from "@hotwired/stimulus"
import { KOR_EOK_TO_MAN } from "controllers/constants"

// Manages Step 2 reserve fund form:
// - Area dropdown change triggers auto-recalculation of reserve defaults
// - "자동 계산" checkbox: when checked, fills reserve items based on average area
// - Maintains running total of all reserve items
export default class extends Controller {
  static targets = [
    "autoCalc", "propertyType",
    "areaCategory",
    "repairCost", "acquisitionTax", "scrivenerFee",
    "movingCost", "maintenanceFee", "total",
    "repairCostHint", "acquisitionTaxHint", "scrivenerFeeHint",
    "movingCostHint", "maintenanceFeeHint",
    "summaryBox", "warning", "submitBtn"
  ]
  static values = {
    defaults: Object, // reserve_fund_defaults grouped by property_type_id
    availableCash: { type: Number, default: 0 }
  }

  connect() {
    this.updateTotal()
    if (this.hasAutoCalcTarget && this.autoCalcTarget.checked) {
      this.applyDefaults()
    }
  }

  // Called when "자동 계산" checkbox changes
  toggleAutoCalc() {
    if (this.autoCalcTarget.checked) {
      this.applyDefaults()
    }
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

  // Apply default reserve values based on property type and average area
  applyDefaults() {
    const propertyTypeId = this.propertyTypeTarget.value
    const defaults = this.defaultsValue[propertyTypeId]

    if (!defaults || defaults.length === 0) return

    // Read selected category key from dropdown
    const key = this.areaCategoryTarget.value
    if (!key) return

    // Find matching default by category key → area range
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
      this.acquisitionTaxTarget.value = Math.round(match.acquisition_tax_rate * match.average_price)
      this.scrivenerFeeTarget.value = match.scrivener_fee
      this.movingCostTarget.value = match.moving_cost
      this.maintenanceFeeTarget.value = match.maintenance_fee
      this.updateTotal()
      this.updateHints(match)
      this.dispatch("changed")
    }
  }

  updateHints(match) {
    const priceLabel = `평균 ${(match.average_price / KOR_EOK_TO_MAN).toFixed(1)}억`
    const taxPercent = (match.acquisition_tax_rate * 100).toFixed(1)

    if (this.hasRepairCostHintTarget)
      this.repairCostHintTarget.textContent = `${priceLabel} 기준 수선비`
    if (this.hasAcquisitionTaxHintTarget)
      this.acquisitionTaxHintTarget.textContent = `${priceLabel} × ${taxPercent}%`
    if (this.hasScrivenerFeeHintTarget)
      this.scrivenerFeeHintTarget.textContent = `${priceLabel} 기준 법무사 수수료`
    if (this.hasMovingCostHintTarget)
      this.movingCostHintTarget.textContent = `면적 기준 이사비`
    if (this.hasMaintenanceFeeHintTarget)
      this.maintenanceFeeHintTarget.textContent = `미납 관리비 (없으면 0)`
  }

  updateTotal() {
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
