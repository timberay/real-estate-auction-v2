import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }
  static targets = ["feedback"]

  connect() {
    this.previousValue = this.element.value
  }

  save() {
    const region = this.element.value
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": token,
        "Accept": "application/json"
      },
      body: JSON.stringify({ budget_setting: { region } })
    }).then(response => {
      if (response.ok) {
        this.previousValue = region
        this.showFeedback()
      } else {
        this.element.value = this.previousValue
      }
    }).catch(() => {
      this.element.value = this.previousValue
    })
  }

  showFeedback() {
    if (!this.hasFeedbackTarget) return

    this.feedbackTarget.textContent = "✓ 저장됨"
    this.feedbackTarget.classList.remove("opacity-0")
    this.feedbackTarget.classList.add("opacity-100")

    setTimeout(() => {
      this.feedbackTarget.classList.remove("opacity-100")
      this.feedbackTarget.classList.add("opacity-0")
    }, 1500)
  }
}
