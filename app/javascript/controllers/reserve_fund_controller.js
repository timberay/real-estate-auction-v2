import { Controller } from "@hotwired/stimulus"

// Handles "기본값 사용" toggle and reserve fund total calculation
// Targets: useDefaults, propertyType, areaRange, repairCost, acquisitionTax, scrivenerFee, movingCost, maintenanceFee, total
export default class extends Controller {
  static targets = [
    "useDefaults", "propertyType", "areaRange",
    "repairCost", "acquisitionTax", "scrivenerFee",
    "movingCost", "maintenanceFee", "total"
  ]
  static values = {
    defaults: Object // JSON of reserve_fund_defaults keyed by property_type_id
  }

  connect() {
    this.updateTotal()
  }

  toggleDefaults() {
    if (this.useDefaultsTarget.checked) {
      this.applyDefaults()
    }
  }

  applyDefaults() {
    const propertyTypeId = this.propertyTypeTarget.value
    const areaRange = this.areaRangeTarget.value
    const defaults = this.defaultsValue[propertyTypeId]

    if (!defaults) return

    const match = defaults.find(d =>
      parseInt(areaRange) >= d.area_range_min && parseInt(areaRange) <= d.area_range_max
    )

    if (match) {
      this.repairCostTarget.value = match.repair_cost.toLocaleString("ko-KR")
      this.acquisitionTaxTarget.value = Math.round(match.acquisition_tax_rate * 10000).toLocaleString("ko-KR")
      this.scrivenerFeeTarget.value = match.scrivener_fee.toLocaleString("ko-KR")
      this.movingCostTarget.value = match.moving_cost.toLocaleString("ko-KR")
      this.maintenanceFeeTarget.value = match.maintenance_fee.toLocaleString("ko-KR")
      this.updateTotal()
    }
  }

  propertyTypeChanged() {
    if (this.useDefaultsTarget.checked) {
      this.applyDefaults()
    }
    this.updateTotal()
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
      return sum + (parseInt(field.value.replace(/,/g, ""), 10) || 0)
    }, 0)

    this.totalTarget.textContent = total.toLocaleString("ko-KR")
  }
}
