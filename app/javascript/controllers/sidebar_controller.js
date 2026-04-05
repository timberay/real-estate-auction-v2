import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "content", "backdrop", "toggleIcon"]
  static values = { collapsed: { type: Boolean, default: false } }

  connect() {
    const saved = localStorage.getItem("sidebar-collapsed")
    if (saved !== null) {
      this.collapsedValue = saved === "true"
    }
    this.applyState()
  }

  toggle() {
    this.collapsedValue = !this.collapsedValue
    localStorage.setItem("sidebar-collapsed", this.collapsedValue)
    this.applyState()
  }

  toggleMobile() {
    this.sidebarTarget.classList.toggle("hidden")
    this.backdropTarget.classList.toggle("hidden")
    document.body.classList.toggle("overflow-hidden")
  }

  close() {
    this.sidebarTarget.classList.add("hidden")
    this.backdropTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  applyState() {
    if (this.collapsedValue) {
      this.sidebarTarget.classList.add("w-16")
      this.sidebarTarget.classList.remove("w-64")
      this.contentTarget.classList.add("md:ml-16")
      this.contentTarget.classList.remove("lg:ml-64")
    } else {
      this.sidebarTarget.classList.remove("w-16")
      this.sidebarTarget.classList.add("w-64")
      this.contentTarget.classList.remove("md:ml-16")
      this.contentTarget.classList.add("lg:ml-64")
    }

    if (this.hasToggleIconTarget) {
      this.toggleIconTarget.classList.toggle("rotate-180", !this.collapsedValue)
    }
  }
}
