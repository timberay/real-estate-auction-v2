import { Controller } from "@hotwired/stimulus"

// Converts area display between 평 and ㎡
// 1평 = 3.305785㎡
// DB always stores values in ㎡. This controller converts for display only.
// Server handles conversion on save (convert_area_to_sqm_if_needed).
export default class extends Controller {
  static targets = ["minInput", "maxInput", "minLabel", "maxLabel"]
  static values = { unit: { type: String, default: "sqm" } }

  connect() {
    // DB values are in ㎡. Convert to pyeong for display if needed.
    if (this.unitValue === "pyeong") {
      this.convertForDisplay(this.minInputTarget, "sqmToPyeong")
      this.convertForDisplay(this.maxInputTarget, "sqmToPyeong")
    }
    this.updateLabels()
  }

  toggle(event) {
    const newUnit = event.target.value
    if (newUnit === this.unitValue) return

    const oldUnit = this.unitValue
    this.unitValue = newUnit

    this.convertInput(this.minInputTarget, oldUnit, newUnit)
    this.convertInput(this.maxInputTarget, oldUnit, newUnit)
    this.updateLabels()
  }

  convertInput(input, fromUnit, toUnit) {
    const value = parseFloat(input.value)
    if (isNaN(value) || value === 0) return

    if (fromUnit === "pyeong" && toUnit === "sqm") {
      input.value = Math.round(value * 3.305785)
    } else if (fromUnit === "sqm" && toUnit === "pyeong") {
      input.value = Math.round(value / 3.305785)
    }
  }

  convertForDisplay(input, direction) {
    const value = parseFloat(input.value)
    if (isNaN(value) || value === 0) return

    if (direction === "sqmToPyeong") {
      input.value = Math.round(value / 3.305785)
    }
  }

  updateLabels() {
    const suffix = this.unitValue === "pyeong" ? "평" : "㎡"
    this.minLabelTarget.textContent = `면적 최소 (${suffix})`
    this.maxLabelTarget.textContent = `면적 최대 (${suffix})`
  }
}
