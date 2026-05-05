import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "questionFrame",
    "propertyTab", "manualTab", "propertyPanel", "manualPanel"
  ]

  scrollToQuestion() {
    if (this.hasQuestionFrameTarget) {
      this.questionFrameTarget.scrollIntoView({ behavior: "smooth", block: "start" })
    }
  }

  showProperty() {
    this.propertyPanelTarget.classList.remove("hidden")
    this.manualPanelTarget.classList.add("hidden")
    this.#activate(this.propertyTabTarget)
    this.#deactivate(this.manualTabTarget)
  }

  showManual() {
    this.manualPanelTarget.classList.remove("hidden")
    this.propertyPanelTarget.classList.add("hidden")
    this.#activate(this.manualTabTarget)
    this.#deactivate(this.propertyTabTarget)
  }

  #activate(tab) {
    tab.classList.add("border-blue-500", "text-blue-600", "dark:text-blue-400")
    tab.classList.remove("border-transparent", "text-slate-500", "hover:border-slate-300", "hover:text-slate-700", "dark:text-slate-400", "dark:hover:text-slate-300")
  }

  #deactivate(tab) {
    tab.classList.remove("border-blue-500", "text-blue-600", "dark:text-blue-400")
    tab.classList.add("border-transparent", "text-slate-500", "hover:border-slate-300", "hover:text-slate-700", "dark:text-slate-400", "dark:hover:text-slate-300")
  }
}
