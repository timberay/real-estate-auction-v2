import { Controller } from "@hotwired/stimulus"

// Toggles between 평 and ㎡ display
// 1평 = 3.305785㎡
export default class extends Controller {
  static targets = ["display", "unitInput"]
  static values = {
    sqm: Number,
    unit: { type: String, default: "pyeong" }
  }

  static SQM_PER_PYEONG = 3.305785

  toggle(event) {
    this.unitValue = event.target.value
    this.updateDisplay()
  }

  updateDisplay() {
    this.displayTargets.forEach(el => {
      const sqm = parseFloat(el.dataset.sqmValue)
      if (this.unitValue === "pyeong") {
        el.textContent = `${Math.round(sqm / 3.305785)}평`
      } else {
        el.textContent = `${sqm}㎡`
      }
    })
  }
}
