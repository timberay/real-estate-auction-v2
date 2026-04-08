import { Controller } from "@hotwired/stimulus"

// Handles loan ratio slider + failed rounds slider with real-time previews.
// Both share the same maxBid calculation so they live in one controller.
export default class extends Controller {
  static targets = [
    "slider", "ratioDisplay", "maxBidPreview", "hiddenRatio",
    "roundsSlider", "roundsDisplay", "limitPreview",
    "roundBreakdown"
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
      this.renderRoundBreakdown(0, 0)
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

      this.renderRoundBreakdown(maxBid, rounds)
    }
  }

  renderRoundBreakdown(maxBid, rounds) {
    if (!this.hasRoundBreakdownTarget) return

    if (maxBid <= 0) {
      this.roundBreakdownTarget.innerHTML = ""
      return
    }

    const factor = Math.pow(0.8, rounds)
    const appraisalPrice = rounds === 0 ? maxBid : Math.floor(maxBid / factor)

    const headerText = rounds === 0 ? "신건 기준" : `유찰 ${rounds}회차 기준`

    let rowsHtml = ""

    const appraisalHighlight = rounds === 0
    rowsHtml += this.#breakdownRow("감정가", appraisalPrice, appraisalHighlight)

    for (let r = 1; r <= rounds; r++) {
      const minBid = Math.floor(appraisalPrice * Math.pow(0.8, r))
      const isLast = r === rounds
      rowsHtml += this.#breakdownRow(`${r}회 유찰 → 최저가`, minBid, isLast)
    }

    this.roundBreakdownTarget.innerHTML = `
      <div class="p-4 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg">
        <p class="text-xs text-slate-500 dark:text-slate-400 mb-2">${headerText}</p>
        <div class="space-y-1.5">${rowsHtml}</div>
      </div>
    `
  }

  #breakdownRow(label, amount, highlighted) {
    const valueClass = highlighted
      ? "text-sm font-bold tabular-nums text-blue-600 dark:text-blue-400"
      : "text-sm tabular-nums text-slate-600 dark:text-slate-300"
    const labelClass = highlighted
      ? "text-sm text-blue-600 dark:text-blue-400 font-medium"
      : "text-sm text-slate-500 dark:text-slate-400"

    return `
      <div class="flex justify-between items-center">
        <span class="${labelClass}">${label}</span>
        <span class="${valueClass}">${amount.toLocaleString("ko-KR")}만원</span>
      </div>
    `
  }
}
