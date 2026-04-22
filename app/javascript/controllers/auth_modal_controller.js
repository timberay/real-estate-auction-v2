import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  disable(event) {
    const btn = event.currentTarget.querySelector("button") || event.currentTarget
    // Defer disable so the form submission is not cancelled
    requestAnimationFrame(() => {
      btn.dataset.originalText = btn.textContent
      btn.textContent = "로그인 중..."
      btn.disabled = true
    })
  }

  close() {
    const frame = this.element.closest("turbo-frame")
    if (frame) frame.innerHTML = ""
  }
}
