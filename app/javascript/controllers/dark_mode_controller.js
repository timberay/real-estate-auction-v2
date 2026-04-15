import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sunIcon", "moonIcon"]

  connect() {
    this.updateIcons()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    const isDark = document.documentElement.classList.contains("dark")
    this.setDarkMode(!isDark)
    localStorage.setItem("dark-mode", !isDark)
    this.updateIcons()
  }

  setDarkMode(enabled) {
    document.documentElement.classList.toggle("dark", enabled)
  }

  updateIcons() {
    const isDark = document.documentElement.classList.contains("dark")
    if (this.hasSunIconTarget && this.hasMoonIconTarget) {
      this.sunIconTarget.classList.toggle("hidden", isDark)
      this.moonIconTarget.classList.toggle("hidden", !isDark)
    }
  }
}
