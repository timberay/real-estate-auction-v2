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
        this.reEvaluateDescendants(el)
      } else {
        el.classList.add("hidden")
        this.hideDescendants(el.dataset.itemCode)
      }
    })
  }

  hideDescendants(parentCode) {
    this.element.querySelectorAll(`[data-depends-on-code="${parentCode}"]`).forEach(el => {
      el.classList.add("hidden")
      this.hideDescendants(el.dataset.itemCode)
    })
  }

  reEvaluateDescendants(el) {
    const childCode = el.dataset.itemCode
    if (!childCode) return

    const checked = el.querySelector('input[type="radio"]:checked')
    if (!checked) return

    const childHasRisk = checked.value === "true"
    this.element.querySelectorAll(`[data-depends-on-code="${childCode}"]`).forEach(grandchild => {
      const showWhenRisk = grandchild.dataset.dependsOnShowWhenRisk === "true"
      if (childHasRisk === showWhenRisk) {
        grandchild.classList.remove("hidden")
        this.reEvaluateDescendants(grandchild)
      } else {
        grandchild.classList.add("hidden")
        this.hideDescendants(grandchild.dataset.itemCode)
      }
    })
  }
}
