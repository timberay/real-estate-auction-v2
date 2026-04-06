import { Controller } from "@hotwired/stimulus"

// Converts area values between 평 and ㎡ when unit changes
// 1평 = 3.305785㎡
// DB stores values in the user's chosen unit as-is
export default class extends Controller {
  static targets = ["minInput", "maxInput", "minLabel", "maxLabel"]
  static values = { unit: { type: String, default: "pyeong" } }

  static SQM_PER_PYEONG = 3.305785

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

  updateLabels() {
    const suffix = this.unitValue === "pyeong" ? "평" : "㎡"
    this.minLabelTarget.textContent = `면적 최소 (${suffix})`
    this.maxLabelTarget.textContent = `면적 최대 (${suffix})`
  }

  connect() {
    this.updateLabels()
  }
}
