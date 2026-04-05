import { Controller } from "@hotwired/stimulus"

// Formats text inputs with comma separators for 만원 amounts (e.g., 30,000)
// Stores raw integer in a hidden field for form submission.
//
// Usage:
//   <div data-controller="number-format">
//     <input type="text" data-number-format-target="display"
//            data-action="input->number-format#format"
//            inputmode="numeric" placeholder="30,000">
//     <input type="hidden" data-number-format-target="hidden" name="budget_setting[available_cash]">
//   </div>
export default class extends Controller {
  static targets = ["display", "hidden"]
  static values = {
    initial: { type: Number, default: 0 }
  }

  connect() {
    if (this.initialValue > 0) {
      this.displayTarget.value = this.initialValue.toLocaleString("ko-KR")
      this.hiddenTarget.value = this.initialValue
    } else if (this.hiddenTarget.value) {
      const num = parseInt(this.hiddenTarget.value, 10)
      if (num > 0) {
        this.displayTarget.value = num.toLocaleString("ko-KR")
      }
    }
  }

  format() {
    const raw = this.displayTarget.value.replace(/,/g, "").replace(/[^0-9]/g, "")
    if (raw === "") {
      this.displayTarget.value = ""
      this.hiddenTarget.value = ""
      return
    }
    const number = parseInt(raw, 10)
    this.displayTarget.value = number.toLocaleString("ko-KR")
    this.hiddenTarget.value = number
  }
}
