import { Controller } from "@hotwired/stimulus"

const LOGIC_DIMMED = ["text-slate-400", "dark:text-slate-500"]
const LOGIC_NEUTRAL = ["text-slate-500", "dark:text-slate-400"]
const ALL_HIGHLIGHT_CLASSES = ["bg-green-100", "dark:bg-green-900/20", "font-semibold", "text-green-800", "dark:text-green-300", "bg-red-100", "dark:bg-red-900/20", "text-red-800", "dark:text-red-300"]
const ALL_LOGIC_CLASSES = [...ALL_HIGHLIGHT_CLASSES, ...LOGIC_DIMMED, ...LOGIC_NEUTRAL]

const BADGE_AUTO = ["bg-slate-200", "text-slate-600", "dark:bg-slate-700", "dark:text-slate-400"]
const BADGE_OVERRIDDEN = ["bg-amber-100", "text-amber-700", "ring-1", "ring-inset", "ring-amber-600/20", "dark:bg-amber-900/30", "dark:text-amber-300", "dark:ring-amber-400/20"]
const BADGE_MANUAL = ["bg-amber-100", "text-amber-700", "ring-1", "ring-inset", "ring-amber-600/20", "dark:bg-amber-900/30", "dark:text-amber-300", "dark:ring-amber-400/20"]
const ALL_BADGE_CLASSES = [...BADGE_AUTO, ...BADGE_OVERRIDDEN, ...BADGE_MANUAL]

export default class extends Controller {
  static targets = [
    "resolutionSection", "statusLabel", "sourceBadge",
    "editButton", "cancelButton", "editSection",
    "overrideRadio", "overrideFlag", "overrideInput",
    "overrideResolutionSection",
    "logicYes", "logicNo", "logicYesIcon", "logicNoIcon",
    "resolvableRadio", "resolutionNote"
  ]
  static values = {
    resultId: Number, auto: Boolean,
    originalHasRisk: String, originalBadgeText: String, originalBadgeClasses: String,
    yesMeansSafe: Boolean,
    resolutionUrl: String
  }

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

  autosave() {
    if (!this.resolutionUrlValue) return

    const body = new FormData()

    const hasRiskRadio = this.element.querySelector(
      `input[name='resolutions[${this.resultIdValue}][has_risk]']:checked`
    )
    if (hasRiskRadio) body.set("has_risk", hasRiskRadio.value)

    const resolvableRadio = this.resolvableRadioTargets.find(r => r.checked)
    if (resolvableRadio) body.set("resolvable", resolvableRadio.value)

    if (this.hasResolutionNoteTarget) {
      body.set("resolution_note", this.resolutionNoteTarget.value)
    }

    if (!body.has("has_risk") && !body.has("resolvable")) return

    fetch(this.resolutionUrlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || "",
        "Accept": "text/vnd.turbo-stream.html"
      },
      body
    }).then(r => r.ok ? r.text() : Promise.reject(r))
      .then(html => window.Turbo?.renderStreamMessage(html))
      .catch(err => console.error("autosave failed", err))
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
    const yesMeansSafe = this.yesMeansSafeValue

    // Determine which answer is selected based on polarity
    const yesSelected = yesMeansSafe ? !hasRisk : hasRisk
    const safeClasses = ["bg-green-100", "dark:bg-green-900/20", "font-semibold", "text-green-800", "dark:text-green-300"]
    const dangerClasses = ["bg-red-100", "dark:bg-red-900/20", "font-semibold", "text-red-800", "dark:text-red-300"]

    // Reset both rows
    yesEl.classList.remove(...ALL_LOGIC_CLASSES)
    noEl.classList.remove(...ALL_LOGIC_CLASSES)
    yesEl.removeAttribute("data-logic-selected")
    noEl.removeAttribute("data-logic-selected")

    if (yesSelected) {
      // Yes is the selected answer
      const yesColor = yesMeansSafe ? safeClasses : dangerClasses
      yesEl.classList.add(...yesColor)
      yesEl.setAttribute("data-logic-selected", "yes")
      noEl.classList.add(...LOGIC_DIMMED)
      this.logicYesIconTarget.textContent = "✔"
      this.logicNoIconTarget.textContent = "○"
    } else {
      // No is the selected answer
      const noColor = yesMeansSafe ? dangerClasses : safeClasses
      noEl.classList.add(...noColor)
      noEl.setAttribute("data-logic-selected", "no")
      yesEl.classList.add(...LOGIC_DIMMED)
      this.logicNoIconTarget.textContent = "✔"
      this.logicYesIconTarget.textContent = "○"
    }
  }
}
