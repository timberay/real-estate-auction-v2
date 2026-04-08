import { Controller } from "@hotwired/stimulus"

// Manages Step 2 reserve fund form:
// - Area dropdown change triggers auto-recalculation of reserve defaults
// - "자동 계산" checkbox: when checked, fills reserve items based on average area
// - Maintains running total of all reserve items
export default class extends Controller {
  static targets = [
    "autoCalc", "propertyType",
    "areaMin", "areaMax",
    "repairCost", "acquisitionTax", "scrivenerFee",
    "movingCost", "maintenanceFee", "total",
    "repairCostHint", "acquisitionTaxHint", "scrivenerFeeHint",
    "movingCostHint", "maintenanceFeeHint"
  ]
  static values = {
    defaults: Object // reserve_fund_defaults grouped by property_type_id
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

    // Dropdown values are already in ㎡
    const minVal = parseInt(this.areaMinTarget.value, 10) || 0
    const maxVal = parseInt(this.areaMaxTarget.value, 10) || 0
    const avgArea = (minVal + maxVal) / 2

    // Find matching default by average area
    const match = defaults.find(d =>
      avgArea >= d.area_range_min && avgArea <= d.area_range_max
    )

    if (match) {
      this.repairCostTarget.value = match.repair_cost
      this.acquisitionTaxTarget.value = Math.round(match.acquisition_tax_rate * 10000)
      this.scrivenerFeeTarget.value = match.scrivener_fee
      this.movingCostTarget.value = match.moving_cost
      this.maintenanceFeeTarget.value = match.maintenance_fee
      this.updateTotal()
      this.updateHints(match)
    }
  }

  updateHints(match) {
    const areaLabel = `${match.area_range_min}~${match.area_range_max}㎡`
    const taxPercent = (match.acquisition_tax_rate * 100).toFixed(1)

    if (this.hasRepairCostHintTarget)
      this.repairCostHintTarget.textContent = `${areaLabel} 기준 수선비`
    if (this.hasAcquisitionTaxHintTarget)
      this.acquisitionTaxHintTarget.textContent = `감정가 × ${taxPercent}% (취득세율)`
    if (this.hasScrivenerFeeHintTarget)
      this.scrivenerFeeHintTarget.textContent = `${areaLabel} 기준 법무사 수수료`
    if (this.hasMovingCostHintTarget)
      this.movingCostHintTarget.textContent = `${areaLabel} 기준 이사비`
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
  }
}
