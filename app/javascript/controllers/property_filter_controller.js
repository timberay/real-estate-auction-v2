// app/javascript/controllers/property_filter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["ratingSelect", "form"]

  safeOnly() {
    this.ratingSelectTarget.value = "safe"
    this.formTarget.requestSubmit()
  }

  filter() {
    this.formTarget.requestSubmit()
  }

  clearFilter() {
    this.ratingSelectTarget.value = ""
    this.formTarget.requestSubmit()
  }
}
