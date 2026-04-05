import { Controller } from "@hotwired/stimulus"

// Formats numeric inputs with comma separators (e.g., 30,000)
// Usage: <input data-controller="number-format" data-action="input->number-format#format">
export default class extends Controller {
  format(event) {
    const input = event.target
    const raw = input.value.replace(/,/g, "").replace(/[^0-9]/g, "")
    if (raw === "") {
      input.value = ""
      return
    }
    const number = parseInt(raw, 10)
    input.value = number.toLocaleString("ko-KR")
    // Store raw value in a data attribute for form submission
    input.dataset.rawValue = number
  }

  // Get the raw numeric value for form submission
  getRawValue(input) {
    return parseInt(input.value.replace(/,/g, ""), 10) || 0
  }
}
