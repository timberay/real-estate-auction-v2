// app/javascript/controllers/resolution_input_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["noteField"]

  toggle(event) {
    const resolvable = event.target.value === "true"
    const noteField = event.target.closest("[data-resolution-input-target='noteField']")
      || this.noteFieldTarget
    if (noteField) {
      noteField.classList.toggle("hidden", !resolvable)
    }
  }
}
