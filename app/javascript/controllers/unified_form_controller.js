// app/javascript/controllers/unified_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progress"]

  connect() {
    this.validate()
  }

  validate() {
    const allCards = this.element.querySelectorAll("[data-inspection-item-auto-value]")
    let completed = 0
    let total = 0

    allCards.forEach(card => {
      if (card.closest(".hidden")) return

      total++

      const isAuto = card.dataset.inspectionItemAutoValue === "true"
      if (isAuto) {
        completed++
        return
      }

      const hasRiskRadios = card.querySelectorAll("input[name*='[has_risk]']:not(:disabled)")
      const hasRiskChecked = Array.from(hasRiskRadios).some(r => r.checked)
      if (hasRiskChecked) {
        completed++
      }
    })

    if (this.hasProgressTarget) {
      this.progressTarget.textContent = `${completed}/${total}`
    }
  }
}
