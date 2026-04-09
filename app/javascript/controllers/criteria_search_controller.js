// app/javascript/controllers/criteria_search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton", "buttonText", "buttonSpinner", "caseInput", "addButton", "resultsContainer"]

  submit() {
    this.disable()
  }

  closeResults() {
    if (this.hasResultsContainerTarget) {
      this.resultsContainerTarget.innerHTML = ""
    }
  }

  disable() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
    if (this.hasButtonTextTarget) this.buttonTextTarget.classList.add("hidden")
    if (this.hasButtonSpinnerTarget) this.buttonSpinnerTarget.classList.remove("hidden")
    if (this.hasCaseInputTarget) this.caseInputTarget.disabled = true
    if (this.hasAddButtonTarget) this.addButtonTarget.disabled = true
  }

  enable() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove("opacity-50", "cursor-not-allowed")
    }
    if (this.hasButtonTextTarget) this.buttonTextTarget.classList.remove("hidden")
    if (this.hasButtonSpinnerTarget) this.buttonSpinnerTarget.classList.add("hidden")
    if (this.hasCaseInputTarget) this.caseInputTarget.disabled = false
    if (this.hasAddButtonTarget) this.addButtonTarget.disabled = false
  }
}
