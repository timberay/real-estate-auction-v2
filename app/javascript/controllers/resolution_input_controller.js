// app/javascript/controllers/resolution_input_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["resolutionSection", "statusLabel"]
  static values = { resultId: Number, source: String }

  // Card style class sets keyed by state
  static cardStyles = {
    gray: "border-slate-300 bg-slate-50 dark:border-slate-600 dark:bg-slate-800/50",
    green: "border-green-300 bg-green-50 dark:border-green-600 dark:bg-green-900/20",
    yellow: "border-yellow-300 bg-yellow-50 dark:border-yellow-600 dark:bg-yellow-900/20",
    red: "border-red-300 bg-red-50 dark:border-red-600 dark:bg-red-900/20"
  }

  toggleManualRisk(event) {
    const hasRisk = event.target.value === "true"

    if (hasRisk) {
      this.showResolutionSection()
      this.setCardStyle("yellow")
      this.updateStatus("위험 확인", "text-yellow-700 dark:text-yellow-400")
    } else {
      this.hideResolutionSection()
      this.setCardStyle("green")
      this.updateStatus("안전", "text-green-700 dark:text-green-400")
    }

    this.dispatchValidation()
  }

  showResolutionSection() {
    if (!this.hasResolutionSectionTarget) return
    this.resolutionSectionTarget.classList.remove("hidden")
  }

  hideResolutionSection() {
    if (!this.hasResolutionSectionTarget) return
    this.resolutionSectionTarget.classList.add("hidden")
    // Clear resolvable and note when hiding
    this.resolutionSectionTarget.querySelectorAll("input[type='radio']").forEach(r => r.checked = false)
    this.resolutionSectionTarget.querySelectorAll("input[type='text']").forEach(t => t.value = "")
  }

  setCardStyle(style) {
    const card = this.element
    // Remove all card style classes
    Object.values(this.constructor.cardStyles).forEach(classes => {
      classes.split(" ").forEach(c => card.classList.remove(c))
    })
    // Add new style classes
    this.constructor.cardStyles[style].split(" ").forEach(c => card.classList.add(c))
  }

  updateStatus(text, colorClasses) {
    if (!this.hasStatusLabelTarget) return
    this.statusLabelTarget.textContent = text
    // Remove all possible status color classes
    this.statusLabelTarget.className = this.statusLabelTarget.className
      .replace(/text-\S+/g, "")
      .trim()
    colorClasses.split(" ").forEach(c => this.statusLabelTarget.classList.add(c))
    // Re-add base classes
    this.statusLabelTarget.classList.add("ml-2", "shrink-0", "text-xs", "font-semibold")
  }

  dispatchValidation() {
    this.dispatch("changed", { bubbles: true })
  }
}
