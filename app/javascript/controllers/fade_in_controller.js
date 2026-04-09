// app/javascript/controllers/fade_in_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.style.opacity = "0"
    this.element.style.transition = "opacity 300ms ease-in"
    requestAnimationFrame(() => {
      this.element.style.opacity = "1"
    })
  }
}
