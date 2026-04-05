import { Controller } from "@hotwired/stimulus"

// Manages Step 2 reserve fund form:
// - Area unit toggle (평/㎡) auto-converts min/max values
// - "자동 계산" checkbox: when checked, fills reserve items based on average area
// - Area or property type change triggers auto-recalculation
// - Maintains running total of all reserve items
//
// 1평 = 3.305785㎡
const SQM_PER_PYEONG = 3.305785

export default class extends Controller {
  static targets = [
    "autoCalc", "propertyType",
    "areaMin", "areaMax", "areaMinLabel", "areaMaxLabel",
    "repairCost", "acquisitionTax", "scrivenerFee",
    "movingCost", "maintenanceFee", "total"
  ]
  static values = {
    defaults: Object, // reserve_fund_defaults grouped by property_type_id
    unit: { type: String, default: "pyeong" } // current area unit
  }

  connect() {
    this.updateTotal()
    if (this.hasAutoCalcTarget && this.autoCalcTarget.checked) {
      this.applyDefaults()
    }
  }

  // Called when 평/㎡ radio changes
  unitChanged(event) {
    const newUnit = event.target.value
    const oldUnit = this.unitValue

    if (newUnit === oldUnit) return

    // Convert existing min/max values
    const minVal = parseFloat(this.areaMinTarget.value) || 0
    const maxVal = parseFloat(this.areaMaxTarget.value) || 0

    if (newUnit === "sqm" && oldUnit === "pyeong") {
      // 평 → ㎡
      this.areaMinTarget.value = minVal > 0 ? Math.round(minVal * SQM_PER_PYEONG) : ""
      this.areaMaxTarget.value = maxVal > 0 ? Math.round(maxVal * SQM_PER_PYEONG) : ""
      this.areaMinLabelTarget.textContent = "면적 최소 (㎡)"
      this.areaMaxLabelTarget.textContent = "면적 최대 (㎡)"
    } else if (newUnit === "pyeong" && oldUnit === "sqm") {
      // ㎡ → 평
      this.areaMinTarget.value = minVal > 0 ? Math.round(minVal / SQM_PER_PYEONG) : ""
      this.areaMaxTarget.value = maxVal > 0 ? Math.round(maxVal / SQM_PER_PYEONG) : ""
      this.areaMinLabelTarget.textContent = "면적 최소 (평)"
      this.areaMaxLabelTarget.textContent = "면적 최대 (평)"
    }

    this.unitValue = newUnit

    // Re-apply defaults with new unit conversion
    if (this.hasAutoCalcTarget && this.autoCalcTarget.checked) {
      this.applyDefaults()
    }
  }

  // Called when "자동 계산" checkbox changes
  toggleAutoCalc() {
    if (this.autoCalcTarget.checked) {
      this.applyDefaults()
    }
    // When unchecked, user can freely edit values
  }

  // Called when property type or area changes
  propertyTypeChanged() {
    if (this.hasAutoCalcTarget && this.autoCalcTarget.checked) {
      this.applyDefaults()
    }
    this.updateTotal()
  }

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

    // Calculate average area in ㎡ (DB stores ㎡)
    let minVal = parseFloat(this.areaMinTarget.value) || 0
    let maxVal = parseFloat(this.areaMaxTarget.value) || 0

    // Convert to ㎡ if current unit is 평
    if (this.unitValue === "pyeong") {
      minVal = minVal * SQM_PER_PYEONG
      maxVal = maxVal * SQM_PER_PYEONG
    }

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
    }
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
