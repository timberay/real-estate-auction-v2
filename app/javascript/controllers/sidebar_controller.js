import { Controller } from "@hotwired/stimulus"

const LG_BREAKPOINT = 1024

export default class extends Controller {
  static targets = ["sidebar", "content", "backdrop", "toggleIcon"]
  static values = { collapsed: { type: Boolean, default: false } }

  connect() {
    const saved = localStorage.getItem("sidebar-collapsed")
    if (saved !== null) {
      this.collapsedValue = saved === "true"
    }
    this.lgQuery = window.matchMedia(`(min-width: ${LG_BREAKPOINT}px)`)
    this.boundHandleResize = () => this.applyState()
    this.lgQuery.addEventListener("change", this.boundHandleResize)
    this.applyState()
  }

  disconnect() {
    this.lgQuery?.removeEventListener("change", this.boundHandleResize)
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
    const isLargeScreen = this.lgQuery.matches
    const collapsed = isLargeScreen ? this.collapsedValue : true

    // Sidebar width — remove CSS responsive class, JS takes over
    this.sidebarTarget.classList.remove("lg:w-64")
    this.sidebarTarget.classList.toggle("w-16", collapsed)
    this.sidebarTarget.classList.toggle("w-64", !collapsed)

    // Main content margin — remove CSS responsive class, JS takes over
    this.contentTarget.classList.remove("lg:ml-64")
    this.contentTarget.classList.toggle("md:ml-16", collapsed)
    this.contentTarget.classList.toggle("md:ml-64", !collapsed)

    // Hide text labels when collapsed
    this.sidebarTarget.querySelectorAll("[data-sidebar-label]").forEach(el => {
      el.classList.remove("lg:inline")
      el.classList.toggle("hidden", collapsed)
    })

    // Hide group headers when collapsed
    this.sidebarTarget.querySelectorAll("[data-sidebar-group]").forEach(el => {
      el.classList.remove("lg:flex")
      el.classList.toggle("hidden", collapsed)
    })

    // Center icons when collapsed
    this.sidebarTarget.querySelectorAll("[data-sidebar-item]").forEach(el => {
      el.classList.remove("lg:justify-start", "lg:gap-3", "lg:px-4")
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
