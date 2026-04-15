import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle(event) {
    const card = event.target.closest("[data-item-code]")
    if (!card) return

    const parentCode = card.dataset.itemCode
    const parentHasRisk = event.target.value === "true"

    this.element.querySelectorAll(`[data-depends-on-code="${parentCode}"]`).forEach(el => {
      const showWhenRisk = el.dataset.dependsOnShowWhenRisk === "true"
      if (parentHasRisk === showWhenRisk) {
        el.classList.remove("hidden")
      } else {
        el.classList.add("hidden")
      }
    })
  }
}
