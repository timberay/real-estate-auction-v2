// app/javascript/controllers/unified_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progress"]
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

    manualCards.forEach(card => {
      const hasRiskRadios = card.querySelectorAll("input[name*='[has_risk]']:not(:disabled)")
      const hasRiskChecked = Array.from(hasRiskRadios).some(r => r.checked)

      if (hasRiskChecked) {
        completedManual++
      }
    })

    const autoCount = total - manualCards.length
    const completed = autoCount + completedManual

    if (this.hasProgressTarget) {
      this.progressTarget.textContent = `${completed}/${total}`
    }
  }
}
