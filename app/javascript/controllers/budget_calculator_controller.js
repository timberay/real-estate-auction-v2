// app/javascript/controllers/budget_calculator_controller.js
import { Controller } from "@hotwired/stimulus"
import { KOR_EOK_TO_MAN } from "controllers/constants"

// Recalculates max bid amount in real-time as the user edits budget fields.
// Formula: max_bid_amount = (available_cash - total_reserves) / (1 - loan_ratio)
//
// Also handles three coupled UI behaviors:
//   - LTV slider syncs the hidden loan_ratio field and the % display.
//   - Property type changes re-render the loan policy radios with that
//     type's policies, preserving the user's 1금융 / 2금융 selection by name.
//   - Region changes flip every policy's LTV between non-regulated and
//     regulated rates (서울특별시 = regulated).
export default class extends Controller {
  static targets = ["display", "loanPolicyList", "loanRatioSlider", "loanRatioDisplay", "loanRatioHidden"]
  static values = {
    loanPoliciesByType: { type: Object, default: {} },
    regulatedRegions: { type: Array, default: [] }
  }

  connect() {
    this.calculate()
  }

  applyPolicy(event) {
    const ratio = parseFloat(event.target.dataset.loanRatio)
    if (Number.isFinite(ratio)) this.setLoanRatio(ratio)
    this.calculate()
  }

  slideLoanRatio() {
    const percent = parseInt(this.loanRatioSliderTarget.value, 10)
    if (Number.isFinite(percent)) this.setLoanRatio(percent / 100)
    this.calculate()
  }

  // Re-render loan policy radios for the newly-selected property type.
  // Preserves the user's 1금융 / 2금융 selection by matching policy_name.
  propertyTypeChanged(event) {
    if (!this.hasLoanPolicyListTarget) return

    const newTypeId = String(event.target.value)
    const policies = this.loanPoliciesByTypeValue[newTypeId] || []
    const previousName = this.currentSelectedPolicyName()

    this.renderPolicies(policies, previousName)

    const selected = policies.find(p => p.policy_name === previousName) || policies[0]
    if (selected) this.setLoanRatio(this.policyRatio(selected))
    this.calculate()
  }

  // Re-render the radio labels (LTV %) and reset slider to the current
  // policy's region-appropriate ratio when the user picks a new region.
  regionChanged() {
    if (!this.hasLoanPolicyListTarget) return

    const propertyTypeSelect = this.element.querySelector("select[name='budget_setting[property_type_id]']")
    const typeId = String(propertyTypeSelect?.value || "")
    const policies = this.loanPoliciesByTypeValue[typeId] || []
    const previousName = this.currentSelectedPolicyName()

    this.renderPolicies(policies, previousName)

    const selected = policies.find(p => p.policy_name === previousName) || policies[0]
    if (selected) this.setLoanRatio(this.policyRatio(selected))
    this.calculate()
  }

  renderPolicies(policies, selectedName) {
    this.loanPolicyListTarget.innerHTML = policies.map(p => this.policyRadioHTML(p, selectedName)).join("")
  }

  policyRadioHTML(policy, selectedName) {
    const ratio = this.policyRatio(policy)
    const checked = policy.policy_name === selectedName ? "checked" : ""
    const ltv = Math.round(ratio * 100)
    return `
      <label class="flex items-center gap-3 p-3 border border-slate-200 dark:border-slate-700 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-700/50 cursor-pointer transition-colors">
        <input type="radio"
               name="budget_setting[loan_policy_id]"
               id="budget_setting_loan_policy_id_${policy.id}"
               value="${policy.id}"
               class="text-blue-600"
               data-action="change->budget-calculator#applyPolicy"
               data-loan-ratio="${ratio}"
               ${checked}>
        <div>
          <span class="font-medium text-slate-900 dark:text-slate-100">${policy.policy_name}</span>
          <span class="text-sm text-slate-500 dark:text-slate-400 ml-2">LTV ${ltv}%</span>
        </div>
      </label>
    `
  }

  // Returns the region-appropriate ratio for a policy based on the currently
  // selected region. Falls back to the non-regulated rate if the region select
  // is missing or its value isn't in the regulated list.
  policyRatio(policy) {
    const regionSelect = this.element.querySelector("select[name='budget_setting[region]']")
    const region = regionSelect?.value
    const regulated = region && this.regulatedRegionsValue.includes(region)
    const ratio = regulated ? policy.regulated_loan_ratio : policy.loan_ratio
    return Number.isFinite(ratio) ? ratio : policy.loan_ratio
  }

  currentSelectedPolicyName() {
    if (!this.hasLoanPolicyListTarget) return null
    const checked = this.loanPolicyListTarget.querySelector("input[type='radio']:checked")
    if (!checked) return null
    const label = checked.closest("label")?.querySelector("span.font-medium")
    return label?.textContent?.trim() || null
  }

  setLoanRatio(ratio) {
    const clamped = Math.min(Math.max(ratio, 0), 1)
    if (this.hasLoanRatioHiddenTarget) this.loanRatioHiddenTarget.value = clamped
    if (this.hasLoanRatioSliderTarget) this.loanRatioSliderTarget.value = Math.round(clamped * 100)
    if (this.hasLoanRatioDisplayTarget) this.loanRatioDisplayTarget.textContent = `${Math.round(clamped * 100)}%`
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
    const hidden = this.element.querySelector(`input[type='hidden'][name*='[${name}]']`)
    if (hidden && hidden.value) return parseFloat(hidden.value) || 0

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

    const eok = Math.floor(manwon / KOR_EOK_TO_MAN)
    const remainder = manwon % KOR_EOK_TO_MAN

    if (eok >= 1 && remainder > 0) {
      this.displayTarget.textContent = `${eok}억 ${remainder.toLocaleString("ko-KR")}만원`
    } else if (eok >= 1) {
      this.displayTarget.textContent = `${eok}억`
    } else {
      this.displayTarget.textContent = `${manwon.toLocaleString("ko-KR")}만원`
    }
  }
}
