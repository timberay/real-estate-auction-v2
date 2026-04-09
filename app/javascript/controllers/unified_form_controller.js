// app/javascript/controllers/unified_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton", "progress"]
  static values = { total: Number }

  connect() {
    this.validate()
  }

  validate() {
    const manualCards = this.element.querySelectorAll(
      "[data-inspection-item-auto-value='false']"
    )
    const total = this.totalValue
    let completedManual = 0
    let allManualValid = true

    manualCards.forEach(card => {
      const hasRiskRadios = card.querySelectorAll("input[name*='[has_risk]']:not(:disabled)")
      const hasRiskChecked = Array.from(hasRiskRadios).some(r => r.checked)

      if (!hasRiskChecked) {
        allManualValid = false
        return
      }

      completedManual++

      const selectedValue = Array.from(hasRiskRadios).find(r => r.checked)?.value
      if (selectedValue === "true") {
        const resolvableRadios = card.querySelectorAll("input[name*='[resolvable]']:not(:disabled)")
        const resolvableChecked = Array.from(resolvableRadios).some(r => r.checked)
        if (!resolvableChecked) {
          allManualValid = false
        }
      }
    })

    const autoCount = total - manualCards.length
    const completed = autoCount + completedManual

    if (this.hasProgressTarget) {
      this.progressTarget.textContent = `${completed}/${total}`
    }

    const btn = this.submitButtonTarget
    btn.disabled = !allManualValid

    if (allManualValid) {
      btn.classList.remove("opacity-50", "cursor-not-allowed")
      btn.classList.add("hover:bg-blue-700", "dark:hover:bg-blue-400")
    } else {
      btn.classList.add("opacity-50", "cursor-not-allowed")
      btn.classList.remove("hover:bg-blue-700", "dark:hover:bg-blue-400")
    }
  }
}
