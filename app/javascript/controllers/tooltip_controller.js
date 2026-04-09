import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { content: String }

  connect() {
    this.tooltipElement = null
  }

  show() {
    if (this.tooltipElement) return

    this.tooltipElement = document.createElement("div")
    this.tooltipElement.className =
      "absolute z-10 px-2.5 py-1.5 text-sm font-medium text-white bg-slate-800 rounded-md shadow-sm dark:bg-slate-600 whitespace-nowrap pointer-events-none"
    this.tooltipElement.textContent = this.contentValue

    this.element.appendChild(this.tooltipElement)

    this.tooltipElement.style.bottom = "100%"
    this.tooltipElement.style.left = "50%"
    this.tooltipElement.style.transform = "translateX(-50%)"
    this.tooltipElement.style.marginBottom = "6px"
  }

  hide() {
    if (this.tooltipElement) {
      this.tooltipElement.remove()
      this.tooltipElement = null
    }
  }

  disconnect() {
    this.hide()
  }
}
