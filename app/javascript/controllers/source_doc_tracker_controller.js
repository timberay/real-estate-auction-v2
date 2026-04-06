import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { viewed: { type: Boolean, default: false } }

  switchTab(event) {
    const docType = event.currentTarget.dataset.docType
    this.viewedValue = true

    this.tabTargets.forEach(tab => {
      if (tab.dataset.docType === docType) {
        tab.classList.add("border-blue-600", "text-blue-600", "dark:border-blue-400", "dark:text-blue-400")
        tab.classList.remove("border-transparent", "text-slate-500", "dark:text-slate-400")
      } else {
        tab.classList.remove("border-blue-600", "text-blue-600", "dark:border-blue-400", "dark:text-blue-400")
        tab.classList.add("border-transparent", "text-slate-500", "dark:text-slate-400")
      }
    })

    this.panelTargets.forEach(panel => {
      if (panel.dataset.docType === docType) {
        panel.classList.remove("hidden")
      } else {
        panel.classList.add("hidden")
      }
    })
  }
}
