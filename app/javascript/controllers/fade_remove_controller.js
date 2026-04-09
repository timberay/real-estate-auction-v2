// app/javascript/controllers/fade_remove_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    requestAnimationFrame(() => {
      this.element.style.transition = "opacity 300ms ease-out, max-height 300ms ease-out"
      this.element.style.opacity = "0"
      this.element.style.maxHeight = "0"
      this.element.style.overflow = "hidden"
      this.element.addEventListener("transitionend", this.remove.bind(this), { once: true })
    })
  }

  remove() {
    this.element.remove()
  }
}
