import { Controller } from "@hotwired/stimulus"

const LOGIC_YES_ACTIVE = ["bg-green-50", "dark:bg-green-900/20", "font-semibold", "text-green-800", "dark:text-green-300"]
const LOGIC_NO_ACTIVE = ["bg-red-50", "dark:bg-red-900/20", "font-semibold", "text-red-800", "dark:text-red-300"]
const LOGIC_DIMMED = ["text-slate-400", "dark:text-slate-500"]
const ALL_LOGIC_CLASSES = [...LOGIC_YES_ACTIVE, ...LOGIC_NO_ACTIVE, ...LOGIC_DIMMED]

const BADGE_AUTO = ["bg-blue-100", "text-blue-700", "dark:bg-blue-900/30", "dark:text-blue-300"]
const BADGE_OVERRIDDEN = ["bg-amber-100", "text-amber-700", "dark:bg-amber-900/30", "dark:text-amber-300"]
const BADGE_MANUAL = ["bg-slate-100", "text-slate-600", "dark:bg-slate-700", "dark:text-slate-300"]
const ALL_BADGE_CLASSES = [...BADGE_AUTO, ...BADGE_OVERRIDDEN, ...BADGE_MANUAL]

export default class extends Controller {
  static targets = [
    "resolutionSection", "statusLabel", "sourceBadge",
    "editButton", "cancelButton", "editSection",
    "overrideRadio", "overrideFlag", "overrideInput",
    "overrideResolutionSection",
    "logicYes", "logicNo", "logicYesIcon", "logicNoIcon"
  ]
  static values = { resultId: Number, auto: Boolean, originalHasRisk: String, originalBadgeText: String, originalBadgeClasses: String }

  enterEditMode() {
    this.editButtonTarget.classList.add("hidden")
    this.cancelButtonTarget.classList.remove("hidden")
    this.editSectionTarget.classList.remove("hidden")
    this.#setBadge("수정됨", BADGE_OVERRIDDEN)

    // Enable all override inputs so they submit with the form
    this.overrideRadioTargets.forEach(r => r.disabled = false)
    this.overrideFlagTarget.disabled = false
    this.overrideInputTargets.forEach(i => i.disabled = false)

    // Sync radio buttons with the currently highlighted value
    this.#syncRadiosToOriginal()
  }

  cancelEditMode() {
    this.editButtonTarget.classList.remove("hidden")
    this.cancelButtonTarget.classList.add("hidden")
    this.editSectionTarget.classList.add("hidden")
    this.#setBadge(this.originalBadgeTextValue, this.originalBadgeClassesValue.split(" "))

    // Disable and reset override inputs so they don't submit
    this.overrideRadioTargets.forEach(r => r.disabled = true)
    this.overrideFlagTarget.disabled = true
    this.overrideInputTargets.forEach(i => i.disabled = true)

    // Hide resolution subsection
    if (this.hasOverrideResolutionSectionTarget) {
      this.overrideResolutionSectionTarget.classList.add("hidden")
    }

    // Restore logic highlight and radio buttons to original value
    if (this.originalHasRiskValue !== "") {
      this.#updateLogicHighlight(this.originalHasRiskValue === "true")
    }
    this.#syncRadiosToOriginal()
  }

  toggleManualRisk(event) {
    const hasRisk = event.target.value === "true"

    // Update logic highlight to reflect the new selection
    this.#updateLogicHighlight(hasRisk)

    // Handle manual input section (existing behavior)
    if (this.hasResolutionSectionTarget) {
      if (hasRisk) {
        this.resolutionSectionTarget.classList.remove("hidden")
      } else {
        this.resolutionSectionTarget.classList.add("hidden")
        this.resolutionSectionTarget.querySelectorAll("input[type='radio']").forEach(r => r.checked = false)
        this.resolutionSectionTarget.querySelectorAll("input[type='text']").forEach(t => t.value = "")
      }
    }

    // Handle override resolution section (edit mode for AUTO items)
    if (this.hasOverrideResolutionSectionTarget) {
      if (hasRisk) {
        this.overrideResolutionSectionTarget.classList.remove("hidden")
      } else {
        this.overrideResolutionSectionTarget.classList.add("hidden")
        this.overrideResolutionSectionTarget.querySelectorAll("input[type='radio']").forEach(r => r.checked = false)
        this.overrideResolutionSectionTarget.querySelectorAll("input[type='text']").forEach(t => t.value = "")
      }
    }
  }

  #setBadge(text, classes) {
    const badge = this.sourceBadgeTarget
    badge.classList.remove(...ALL_BADGE_CLASSES)
    badge.classList.add(...classes)
    badge.textContent = text
  }

  #syncRadiosToOriginal() {
    const originalHasRisk = this.originalHasRiskValue
    // Set has_risk radio buttons to match the original value
    this.editSectionTarget.querySelectorAll("input[type='radio'][name*='[has_risk]']").forEach(r => {
      r.checked = (r.value === originalHasRisk)
    })
    // Show/hide override resolution section based on original value
    if (this.hasOverrideResolutionSectionTarget) {
      if (originalHasRisk === "true") {
        this.overrideResolutionSectionTarget.classList.remove("hidden")
      } else {
        this.overrideResolutionSectionTarget.classList.add("hidden")
      }
    }
    // Reset resolvable radios and note when not risky
    if (originalHasRisk !== "true" && this.hasOverrideResolutionSectionTarget) {
      this.overrideResolutionSectionTarget.querySelectorAll("input[type='radio']").forEach(r => r.checked = false)
      this.overrideResolutionSectionTarget.querySelectorAll("input[type='text']").forEach(t => t.value = "")
    }
  }

  #updateLogicHighlight(hasRisk) {
    if (!this.hasLogicYesTarget || !this.hasLogicNoTarget) return

    const yesEl = this.logicYesTarget
    const noEl = this.logicNoTarget

    // Reset both rows
    yesEl.classList.remove(...ALL_LOGIC_CLASSES)
    noEl.classList.remove(...ALL_LOGIC_CLASSES)
    yesEl.removeAttribute("data-logic-selected")
    noEl.removeAttribute("data-logic-selected")

    if (hasRisk) {
      // No selected (risk) — highlight No row, dim Yes row
      noEl.classList.add(...LOGIC_NO_ACTIVE)
      noEl.setAttribute("data-logic-selected", "no")
      yesEl.classList.add(...LOGIC_DIMMED)
      this.logicNoIconTarget.textContent = "✔"
      this.logicYesIconTarget.textContent = "○"
    } else {
      // Yes selected (safe) — highlight Yes row, dim No row
      yesEl.classList.add(...LOGIC_YES_ACTIVE)
      yesEl.setAttribute("data-logic-selected", "yes")
      noEl.classList.add(...LOGIC_DIMMED)
      this.logicYesIconTarget.textContent = "✔"
      this.logicNoIconTarget.textContent = "○"
    }
  }
}
