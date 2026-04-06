import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { sourceDocViewed: Boolean }

  connect() {
    this.sourceDocViewedValue = false
  }

  markSourceDocViewed() {
    this.sourceDocViewedValue = true
  }
}
