// app/javascript/controllers/property_filter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["ratingSelect", "form", "searchButton", "loading"]

  filter() {
    this.showLoading()
    this.formTarget.requestSubmit()
  }

  showLoading() {
    if (this.hasSearchButtonTarget) this.searchButtonTarget.classList.add("hidden")
    if (this.hasLoadingTarget) this.loadingTarget.classList.remove("hidden")
    if (this.hasLoadingTarget) this.loadingTarget.classList.add("inline-flex")
  }
}
