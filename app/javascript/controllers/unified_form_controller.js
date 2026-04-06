// app/javascript/controllers/unified_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton"]

  connect() {
    this.validate()
  }

  validate() {
    const manualCards = this.element.querySelectorAll("[data-resolution-input-source-value='manual']")
    let allValid = true

    manualCards.forEach(card => {
      const hasRiskRadios = card.querySelectorAll("input[name*='[has_risk]']")
      const hasRiskChecked = Array.from(hasRiskRadios).some(r => r.checked)

      if (!hasRiskChecked) {
        allValid = false
        return
      }

      const selectedYes = Array.from(hasRiskRadios).find(r => r.checked)?.value === "true"
      if (selectedYes) {
        const resolvableRadios = card.querySelectorAll("input[name*='[resolvable]']")
        const resolvableChecked = Array.from(resolvableRadios).some(r => r.checked)
        if (!resolvableChecked) {
          allValid = false
        }
      }
    })

    this.submitButtonTarget.disabled = !allValid
  }
}
