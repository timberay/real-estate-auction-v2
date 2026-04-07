import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["resolutionSection", "statusLabel"]
  static values = { resultId: Number }

  toggleManualRisk(event) {
    const hasRisk = event.target.value === "true"

    if (hasRisk) {
      this.resolutionSectionTarget.classList.remove("hidden")
    } else {
      this.resolutionSectionTarget.classList.add("hidden")
      this.resolutionSectionTarget.querySelectorAll("input[type='radio']").forEach(r => r.checked = false)
      this.resolutionSectionTarget.querySelectorAll("input[type='text']").forEach(t => t.value = "")
    }
  }
}
