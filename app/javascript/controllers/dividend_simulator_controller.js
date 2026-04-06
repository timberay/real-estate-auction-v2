import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bidInput"]

  formatInput() {
    const input = this.bidInputTarget
    const raw = input.value.replace(/[^0-9]/g, "")
    input.value = raw ? Number(raw).toLocaleString() : ""
  }
}
