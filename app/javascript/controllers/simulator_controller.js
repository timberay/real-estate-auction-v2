import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["questionFrame"]

  connect() {
    // Simulator state managed server-side via session/DB
    // This controller handles client-side UX enhancements
  }

  scrollToQuestion() {
    if (this.hasQuestionFrameTarget) {
      this.questionFrameTarget.scrollIntoView({ behavior: "smooth", block: "start" })
    }
  }
}
