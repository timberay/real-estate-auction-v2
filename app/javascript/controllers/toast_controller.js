import { Controller } from "@hotwired/stimulus"
import { ANIMATION_DURATION_MS, TOAST_DEFAULT_DURATION_MS } from "controllers/constants"

export default class extends Controller {
  static values = { duration: { type: Number, default: TOAST_DEFAULT_DURATION_MS } }

  connect() {
    if (this.durationValue > 0) {
      this.timeout = setTimeout(() => this.dismiss(), this.durationValue)
    }
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.classList.add("opacity-0", "translate-x-full", "transition-all", "duration-300")
    setTimeout(() => this.element.remove(), ANIMATION_DURATION_MS)
  }
}
