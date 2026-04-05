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
    const collapsed = this.collapsedValue

    // Sidebar width
    this.sidebarTarget.classList.toggle("w-16", collapsed)
    this.sidebarTarget.classList.toggle("w-64", !collapsed)

    // Main content margin
    this.contentTarget.classList.toggle("md:ml-16", collapsed)
    this.contentTarget.classList.toggle("lg:ml-64", !collapsed)

    // Hide text labels and group titles when collapsed
    this.sidebarTarget.querySelectorAll("[data-sidebar-label]").forEach(el => {
      el.classList.toggle("hidden", collapsed)
    })

    // Hide group headers when collapsed
    this.sidebarTarget.querySelectorAll("[data-sidebar-group]").forEach(el => {
      el.classList.toggle("hidden", collapsed)
    })

    // Center icons when collapsed
    this.sidebarTarget.querySelectorAll("[data-sidebar-item]").forEach(el => {
      el.classList.toggle("justify-center", collapsed)
      el.classList.toggle("px-4", !collapsed)
      el.classList.toggle("gap-3", !collapsed)
    })

    // Toggle icon direction
    if (this.hasToggleIconTarget) {
      this.toggleIconTarget.classList.toggle("rotate-180", collapsed)
    }
  }
}
