import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["propertySelect", "pdfInput", "submitBtn"]

  togglePdf() {
    const enabled = this.propertySelectTarget.value !== ""
    this.pdfInputTarget.disabled = !enabled
    this.submitBtnTarget.disabled = !enabled
  }
}
