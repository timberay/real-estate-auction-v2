// app/javascript/controllers/overflow_menu_controller.js
//
// Disclosure pattern for a small menu attached to a trigger button.
// - toggle: flip the menu's hidden state and aria-expanded
// - closeIfOutside: close when a click happens outside this controller's scope
// - closeOnEscape: close when Esc is pressed and return focus to the trigger
//
// Usage:
//   <div data-controller="overflow-menu"
//        data-action="keydown@window->overflow-menu#closeOnEscape">
//     <button type="button"
//             data-action="overflow-menu#toggle click@window->overflow-menu#closeIfOutside"
//             data-overflow-menu-target="trigger"
//             aria-haspopup="true" aria-expanded="false">⋯</button>
//     <div data-overflow-menu-target="menu" hidden>...</div>
//   </div>
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "trigger"]

  toggle(event) {
    event?.preventDefault?.()
    const willOpen = this.menuTarget.hidden
    this.menuTarget.hidden = !willOpen
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", String(willOpen))
    }
  }

  closeIfOutside(event) {
    if (this.menuTarget.hidden) return
    if (this.element.contains(event.target)) return
    this.menuTarget.hidden = true
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", "false")
    }
  }

  closeOnEscape(event) {
    if (event.key !== "Escape") return
    if (this.menuTarget.hidden) return
    this.menuTarget.hidden = true
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", "false")
      this.triggerTarget.focus()
    }
  }
}
