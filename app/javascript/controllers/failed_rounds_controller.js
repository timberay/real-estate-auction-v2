import { Controller } from "@hotwired/stimulus"

// Handles failed auction rounds slider with appraisal limit preview
export default class extends Controller {
  static targets = ["slider", "roundsDisplay", "limitPreview"]
  static values = {
    maxBid: Number
  }

  connect() {
    this.updatePreview()
  }

  slide() {
    this.updatePreview()
  }

  updateMaxBid(maxBid) {
    this.maxBidValue = maxBid
    this.updatePreview()
  }

  updatePreview() {
    const rounds = parseInt(this.sliderTarget.value, 10)
    this.roundsDisplayTarget.textContent = `${rounds}회차`

    if (rounds === 0) {
      this.limitPreviewTarget.textContent = `${this.maxBidValue.toLocaleString("ko-KR")}만원`
    } else {
      const factor = Math.pow(0.8, rounds)
      const limit = Math.floor(this.maxBidValue / factor)
      this.limitPreviewTarget.textContent = `${limit.toLocaleString("ko-KR")}만원`
    }
  }
}
