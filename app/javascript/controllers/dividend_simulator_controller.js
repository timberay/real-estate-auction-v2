import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bidInput", "hiddenBid"]

  connect() {
    this.formatDisplay()
  }

  formatInput() {
    const manwon = this.parseToManwon(this.bidInputTarget.value)
    this.bidInputTarget.value = this.formatManwon(manwon)
    this.hiddenBidTarget.value = manwon || ""
  }

  formatDisplay() {
    const raw = this.bidInputTarget.value
    if (raw && !isNaN(Number(raw))) {
      this.bidInputTarget.value = this.formatManwon(Number(raw))
    }
  }

  parseToManwon(input) {
    if (!input) return null
    let str = input.replace(/[\s,]/g, "")

    let total = 0

    const eokMatch = str.match(/(\d+)억/)
    if (eokMatch) {
      total += parseInt(eokMatch[1], 10) * 10000
      str = str.replace(/\d+억/, "")
    }

    const cheonMatch = str.match(/(\d+)천/)
    if (cheonMatch) {
      total += parseInt(cheonMatch[1], 10) * 1000
      str = str.replace(/\d+천/, "")
    }

    str = str.replace(/만원|만/, "")

    const remaining = str.replace(/[^0-9]/g, "")
    if (remaining) {
      total += parseInt(remaining, 10)
    }

    return total > 0 ? total : null
  }

  formatManwon(manwon) {
    if (!manwon || manwon === 0) return ""

    if (manwon >= 10000) {
      const eok = Math.floor(manwon / 10000)
      const remainder = manwon % 10000
      if (remainder === 0) return `${eok}억원`
      return `${eok}억 ${remainder.toLocaleString()}만원`
    }

    return `${manwon.toLocaleString()}만원`
  }
}
