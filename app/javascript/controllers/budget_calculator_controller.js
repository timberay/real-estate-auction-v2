// app/javascript/controllers/budget_calculator_controller.js
import { Controller } from "@hotwired/stimulus"

// Recalculates max bid amount in real-time as the user edits budget fields.
// Formula: max_bid_amount = (available_cash - total_reserves) / (1 - loan_ratio)
//
// Usage: Wrap the entire budget form with data-controller="budget-calculator"
//        Mark the display target: data-budget-calculator-target="display"
export default class extends Controller {
  static targets = ["display"]

  connect() {
    this.calculate()
  }

  applyPolicy(event) {
    const loanRatio = event.target.dataset.loanRatio
    const loanRatioInput = this.element.querySelector("input[name*='[loan_ratio]']")
    if (loanRatioInput && loanRatio) {
      loanRatioInput.value = loanRatio
    }
    this.calculate()
  }

  calculate() {
    const availableCash = this.fieldValue("available_cash")
    const reserves = this.totalReserves()
    const loanRatio = this.floatFieldValue("loan_ratio")

    const netCash = availableCash - reserves
    if (netCash <= 0 || loanRatio >= 1) {
      this.updateDisplay(null)
      return
    }

    const maxBid = Math.floor(netCash / (1 - loanRatio))
    this.updateDisplay(maxBid)
  }

  // Read integer value from hidden field (for number-format controller) or input directly
  fieldValue(name) {
    const hidden = this.element.querySelector(`input[type='hidden'][name*='[${name}]']`)
    if (hidden && hidden.value) return parseInt(hidden.value, 10) || 0

    const input = this.element.querySelector(`input[name*='[${name}]']`)
    if (input) return parseInt(input.value, 10) || 0

    return 0
  }

  floatFieldValue(name) {
    const input = this.element.querySelector(`input[name*='[${name}]']`)
    if (input) return parseFloat(input.value) || 0
    return 0
  }

  totalReserves() {
    const fields = ["repair_cost", "acquisition_tax", "scrivener_fee", "moving_cost", "maintenance_fee"]
    return fields.reduce((sum, name) => sum + this.fieldValue(name), 0)
  }

  updateDisplay(manwon) {
    if (!this.hasDisplayTarget) return

    if (!manwon || manwon <= 0) {
      this.displayTarget.textContent = "—"
      return
    }

    const eok = Math.floor(manwon / 10000)
    const remainder = manwon % 10000

    if (eok >= 1 && remainder > 0) {
      this.displayTarget.textContent = `${eok}억 ${remainder.toLocaleString("ko-KR")}만원`
    } else if (eok >= 1) {
      this.displayTarget.textContent = `${eok}억`
    } else {
      this.displayTarget.textContent = `${manwon.toLocaleString("ko-KR")}만원`
    }
  }
}
