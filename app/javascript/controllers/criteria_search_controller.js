// app/javascript/controllers/criteria_search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "submitButton", "buttonText", "buttonSpinner",
    "caseInput", "addButton", "addButtonText", "addButtonSpinner"
  ]

  connect() {
    this.handleSubmitStart = this.handleSubmitStart.bind(this)
    this.handleSubmitEnd = this.handleSubmitEnd.bind(this)
    document.addEventListener("turbo:submit-start", this.handleSubmitStart)
    document.addEventListener("turbo:submit-end", this.handleSubmitEnd)
  }

  disconnect() {
    document.removeEventListener("turbo:submit-start", this.handleSubmitStart)
    document.removeEventListener("turbo:submit-end", this.handleSubmitEnd)
  }

  get resultsContainer() {
    return document.getElementById("criteria-search-results")
  }

  handleSubmitStart(event) {
    const form = event.target
    if (!this.element.contains(form) && !this.resultsContainer?.contains(form)) return

    this.element.classList.add("pointer-events-none", "cursor-wait")
    if (this.resultsContainer) {
      this.resultsContainer.classList.add("pointer-events-none", "opacity-60")
    }
  }

  handleSubmitEnd(event) {
    const form = event.target
    if (!this.element.contains(form) && !this.resultsContainer?.contains(form)) return

    this.element.classList.remove("pointer-events-none", "cursor-wait")
    if (this.resultsContainer) {
      this.resultsContainer.classList.remove("pointer-events-none", "opacity-60")
    }
    this.enable()
  }

  // Criteria search form submit
  submit() {
    this.disableAll()
    this.showSpinner("buttonText", "buttonSpinner")
  }

  // Case number form submit — use readOnly instead of disabled so value is submitted
  submitCaseNumber() {
    if (this.hasCaseInputTarget) this.caseInputTarget.readOnly = true
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
    if (this.hasAddButtonTarget) {
      this.addButtonTarget.disabled = true
      this.addButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
    this.showSpinner("addButtonText", "addButtonSpinner")
  }

  enable() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove("opacity-50", "cursor-not-allowed")
    }
    this.hideSpinner("buttonText", "buttonSpinner")
    this.hideSpinner("addButtonText", "addButtonSpinner")
    if (this.hasCaseInputTarget) {
      this.caseInputTarget.disabled = false
      this.caseInputTarget.readOnly = false
    }
    if (this.hasAddButtonTarget) {
      this.addButtonTarget.disabled = false
      this.addButtonTarget.classList.remove("opacity-50", "cursor-not-allowed")
    }
  }

  disableAll() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
    if (this.hasCaseInputTarget) this.caseInputTarget.disabled = true
    if (this.hasAddButtonTarget) {
      this.addButtonTarget.disabled = true
      this.addButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
  }

  showSpinner(textTarget, spinnerTarget) {
    const text = this[`has${this.capitalize(textTarget)}Target`] ? this[`${textTarget}Target`] : null
    const spinner = this[`has${this.capitalize(spinnerTarget)}Target`] ? this[`${spinnerTarget}Target`] : null
    if (text) text.classList.add("hidden")
    if (spinner) spinner.classList.remove("hidden")
  }

  hideSpinner(textTarget, spinnerTarget) {
    const text = this[`has${this.capitalize(textTarget)}Target`] ? this[`${textTarget}Target`] : null
    const spinner = this[`has${this.capitalize(spinnerTarget)}Target`] ? this[`${spinnerTarget}Target`] : null
    if (text) text.classList.remove("hidden")
    if (spinner) spinner.classList.add("hidden")
  }

  capitalize(str) {
    return str.charAt(0).toUpperCase() + str.slice(1)
  }
}
