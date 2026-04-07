import { Controller } from "@hotwired/stimulus"

// Dynamically computes the correct `top` value for a sticky element
// by summing ancestor padding-tops (e.g., navbar offset + main padding).
// Adapts automatically when layout padding changes across breakpoints.
export default class extends Controller {
  connect() {
    this.computeTop()
    this.resizeObserver = new ResizeObserver(() => this.computeTop())
    this.resizeObserver.observe(document.documentElement)
  }

  disconnect() {
    this.resizeObserver?.disconnect()
  }

  computeTop() {
    let top = 0
    let el = this.element.parentElement

    while (el && el !== document.documentElement) {
      top += parseFloat(getComputedStyle(el).paddingTop) || 0
      el = el.parentElement
    }

    this.element.style.top = `0px`
    this.element.style.paddingTop = `${top}px`
    this.element.style.marginTop = `-${top}px`
  }
}
