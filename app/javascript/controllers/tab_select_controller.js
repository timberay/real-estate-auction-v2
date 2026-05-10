import { Controller } from "@hotwired/stimulus"

// Mobile fallback for the inspection tab nav: a <select> whose options carry
// the destination URL. On change we just navigate to the chosen value.
export default class extends Controller {
  navigate(event) {
    const url = event.target.value
    if (url) {
      window.location.href = url
    }
  }
}
