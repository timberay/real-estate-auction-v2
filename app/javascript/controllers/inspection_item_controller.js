import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "resolutionSection", "statusLabel", "sourceBadge",
    "editButton", "cancelButton", "editSection",
    "overrideRadio", "overrideFlag", "overrideInput",
    "overrideResolutionSection"
  ]
  static values = { resultId: Number, auto: Boolean }

  enterEditMode() {
    this.editButtonTarget.classList.add("hidden")
    this.cancelButtonTarget.classList.remove("hidden")
    this.editSectionTarget.classList.remove("hidden")
    this.sourceBadgeTarget.textContent = "수정됨"

    // Enable all override inputs so they submit with the form
    this.overrideRadioTargets.forEach(r => r.disabled = false)
    this.overrideFlagTarget.disabled = false
    this.overrideInputTargets.forEach(i => i.disabled = false)
  }

  cancelEditMode() {
    this.editButtonTarget.classList.remove("hidden")
    this.cancelButtonTarget.classList.add("hidden")
    this.editSectionTarget.classList.add("hidden")
    this.sourceBadgeTarget.textContent = "AUTO"

    // Disable and reset override inputs so they don't submit
    this.overrideRadioTargets.forEach(r => r.disabled = true)
    this.overrideFlagTarget.disabled = true
    this.overrideInputTargets.forEach(i => i.disabled = true)

    // Hide resolution subsection
    if (this.hasOverrideResolutionSectionTarget) {
      this.overrideResolutionSectionTarget.classList.add("hidden")
    }
  }

  toggleManualRisk(event) {
    const hasRisk = event.target.value === "true"

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
}
