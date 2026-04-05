import { Controller } from "@hotwired/stimulus"

// Handles loan ratio slider with real-time max bid preview
export default class extends Controller {
  static targets = ["slider", "ratioDisplay", "maxBidPreview", "hiddenRatio"]
  static values = {
    availableCash: Number,
    totalReserves: Number
  }

  connect() {
    this.updatePreview()
  }

  selectPolicy(event) {
    const ratio = parseFloat(event.target.dataset.loanRatio)
    this.sliderTarget.value = Math.round(ratio * 100)
    this.updatePreview()
  }

  slide() {
    this.updatePreview()
  }

  updatePreview() {
    const ratio = parseInt(this.sliderTarget.value, 10) / 100
    this.ratioDisplayTarget.textContent = `${Math.round(ratio * 100)}%`
    this.hiddenRatioTarget.value = ratio

    const netCash = this.availableCashValue - this.totalReservesValue
    if (netCash <= 0 || ratio >= 1) {
      this.maxBidPreviewTarget.textContent = "계산 불가"
      return
    }
    const maxBid = Math.floor(netCash / (1 - ratio))
    this.maxBidPreviewTarget.textContent = `${maxBid.toLocaleString("ko-KR")}만원`
  }
}
