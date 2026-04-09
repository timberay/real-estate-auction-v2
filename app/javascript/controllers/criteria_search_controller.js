// app/javascript/controllers/criteria_search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["caseInput", "addButton", "resultsContainer",
                     "searchButton", "searchButtonText", "searchButtonSpinner"]

  startSearch() {
    if (this.hasSearchButtonTarget) {
      this.searchButtonTarget.disabled = true
      this.searchButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
    if (this.hasSearchButtonTextTarget) this.searchButtonTextTarget.classList.add("hidden")
    if (this.hasSearchButtonSpinnerTarget) this.searchButtonSpinnerTarget.classList.remove("hidden")
    if (this.hasCaseInputTarget) this.caseInputTarget.disabled = true
    if (this.hasAddButtonTarget) this.addButtonTarget.disabled = true
  }

  enable() {
    this.closeDebug()
    if (this.hasCaseInputTarget) this.caseInputTarget.disabled = false
    if (this.hasAddButtonTarget) this.addButtonTarget.disabled = false
  }

  closeResults() {
    if (this.hasResultsContainerTarget) {
      this.resultsContainerTarget.innerHTML = ""
    }
  }

  closeDebug() {
    const popup = document.getElementById("criteria-debug-popup")
    if (popup) popup.innerHTML = ""
  }

  stopPropagation(event) {
    event.stopPropagation()
  }
}
