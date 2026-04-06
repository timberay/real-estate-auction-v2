import { Controller } from "@hotwired/stimulus"

// Converts area values between 평 and ㎡ for display
// 1평 = 3.305785㎡
// DB always stores values in ㎡. This controller converts for display only.
export default class extends Controller {
  static targets = ["minInput", "maxInput", "minLabel", "maxLabel", "form"]
  static values = { unit: { type: String, default: "pyeong" } }

  static SQM_PER_PYEONG = 3.305785

  connect() {
    this.updateLabels()

    // Convert DB values (always ㎡) to display unit on page load
    if (this.unitValue === "pyeong") {
      this.sqmToPyeong(this.minInputTarget)
      this.sqmToPyeong(this.maxInputTarget)
    }

    // Before form submit, convert display values back to ㎡ for storage
    const form = this.element.closest("form")
    if (form) {
      this.boundConvertToSqm = this.convertToSqmBeforeSubmit.bind(this)
      form.addEventListener("submit", this.boundConvertToSqm)
    }
  }

  disconnect() {
    const form = this.element.closest("form")
    if (form && this.boundConvertToSqm) {
      form.removeEventListener("submit", this.boundConvertToSqm)
    }
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

  sqmToPyeong(input) {
    const value = parseFloat(input.value)
    if (isNaN(value) || value === 0) return
    input.value = Math.round(value / 3.305785)
  }

  pyeongToSqm(input) {
    const value = parseFloat(input.value)
    if (isNaN(value) || value === 0) return
    input.value = Math.round(value * 3.305785)
  }

  convertToSqmBeforeSubmit() {
    // If displaying in pyeong, convert back to ㎡ before the form submits
    if (this.unitValue === "pyeong") {
      this.pyeongToSqm(this.minInputTarget)
      this.pyeongToSqm(this.maxInputTarget)
    }
  }

  updateLabels() {
    const suffix = this.unitValue === "pyeong" ? "평" : "㎡"
    this.minLabelTarget.textContent = `면적 최소 (${suffix})`
    this.maxLabelTarget.textContent = `면적 최대 (${suffix})`
  }
}
