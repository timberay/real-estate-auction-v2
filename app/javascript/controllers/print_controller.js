import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  trigger(event) {
    event.preventDefault()
    window.print()
  }
}
