// app/javascript/controllers/property_filter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["ratingSelect", "form"]

  filter() {
    this.formTarget.requestSubmit()
  }

  search() {
    clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => {
      this.formTarget.requestSubmit()
    }, 300)
  }

  disconnect() {
    clearTimeout(this.searchTimeout)
  }
}
