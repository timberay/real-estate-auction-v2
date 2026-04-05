// app/javascript/controllers/manual_input_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton", "radioGroup"]

  connect() {
    this.validate()
  }

  validate() {
    const groups = this.radioGroupTargets
    const allAnswered = groups.every(group => {
      return group.querySelector("input[type='radio']:checked") !== null
    })
    this.submitButtonTarget.disabled = !allAnswered
  }
}
