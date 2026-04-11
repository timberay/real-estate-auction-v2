import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    reviewed: { type: Boolean, default: false }
  }

  markReviewed() {
    if (this.reviewedValue) return

    this.reviewedValue = true
    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
        "Content-Type": "application/json"
      }
    })
  }

  confirmNavigation(event) {
    if (this.reviewedValue) return

    if (!confirm("원본 서류(매각물건명세서, 등기부등본)를 확인하셨나요?")) {
      event.preventDefault()
    }
  }
}
