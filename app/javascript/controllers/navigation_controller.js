import { Controller } from "@hotwired/stimulus"

// Handles browser back button within the wizard
// Intercepts popstate to navigate to previous wizard step instead of browser history
export default class extends Controller {
  static values = {
    step: Number,
    previousUrl: String
  }

  connect() {
    this.boundPopstate = this.handlePopstate.bind(this)
    window.addEventListener("popstate", this.boundPopstate)
    // Push current step to history
    history.pushState({ step: this.stepValue }, "", window.location.href)
  }

  disconnect() {
    window.removeEventListener("popstate", this.boundPopstate)
  }

  handlePopstate(event) {
    if (this.hasPreviousUrlValue && this.previousUrlValue) {
      event.preventDefault()
      window.location.href = this.previousUrlValue
    }
  }
}
