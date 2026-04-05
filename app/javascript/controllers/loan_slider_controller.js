import { Controller } from "@hotwired/stimulus"

// Handles loan ratio slider + failed rounds slider with real-time previews.
// Both share the same maxBid calculation so they live in one controller.
export default class extends Controller {
  static targets = [
    "slider", "ratioDisplay", "maxBidPreview", "hiddenRatio",
    "roundsSlider", "roundsDisplay", "limitPreview"
  ]
  static values = {
    availableCash: Number,
    totalReserves: Number
  }

  connect() {
    this.updateAll()
  }

  selectPolicy(event) {
    const ratio = parseFloat(event.target.dataset.loanRatio)
    this.sliderTarget.value = Math.round(ratio * 100)
    this.updateAll()
  }

  slide() {
    this.updateAll()
  }

  slideRounds() {
    this.updateAll()
  }

  updateAll() {
    const ratio = parseInt(this.sliderTarget.value, 10) / 100
    this.ratioDisplayTarget.textContent = `${Math.round(ratio * 100)}%`
    this.hiddenRatioTarget.value = ratio

    const netCash = this.availableCashValue - this.totalReservesValue
    if (netCash <= 0 || ratio >= 1) {
      this.maxBidPreviewTarget.textContent = "계산 불가"
      if (this.hasLimitPreviewTarget) {
        this.limitPreviewTarget.textContent = "계산 불가"
      }
      return
    }

    const maxBid = Math.floor(netCash / (1 - ratio))
    this.maxBidPreviewTarget.textContent = `${maxBid.toLocaleString("ko-KR")}만원`

    // Failed rounds calculation
    if (this.hasRoundsSliderTarget) {
      const rounds = parseInt(this.roundsSliderTarget.value, 10)
      this.roundsDisplayTarget.textContent = `${rounds}회차`

      if (rounds === 0) {
        this.limitPreviewTarget.textContent = `${maxBid.toLocaleString("ko-KR")}만원`
      } else {
        const factor = Math.pow(0.8, rounds)
        const limit = Math.floor(maxBid / factor)
        this.limitPreviewTarget.textContent = `${limit.toLocaleString("ko-KR")}만원`
      }
    }
  }
}
