import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["autoTab", "manualTab", "autoPanel", "manualPanel", "jsonInput", "submitButton", "fileName"]

  connect() {
    const params = new URLSearchParams(window.location.search)
    if (params.get("tab") === "manual") {
      this.showManual()
    } else {
      this.showAuto()
    }
  }

  showAuto() {
    this.autoPanelTarget.classList.remove("hidden")
    this.manualPanelTarget.classList.add("hidden")
    this.autoTabTarget.classList.add("border-blue-500", "text-blue-600", "dark:text-blue-400")
    this.autoTabTarget.classList.remove("border-transparent", "text-slate-500")
    this.manualTabTarget.classList.remove("border-blue-500", "text-blue-600", "dark:text-blue-400")
    this.manualTabTarget.classList.add("border-transparent", "text-slate-500")
  }

  showManual() {
    this.manualPanelTarget.classList.remove("hidden")
    this.autoPanelTarget.classList.add("hidden")
    this.manualTabTarget.classList.add("border-blue-500", "text-blue-600", "dark:text-blue-400")
    this.manualTabTarget.classList.remove("border-transparent", "text-slate-500")
    this.autoTabTarget.classList.remove("border-blue-500", "text-blue-600", "dark:text-blue-400")
    this.autoTabTarget.classList.add("border-transparent", "text-slate-500")
  }

  selectJson() {
    const file = this.jsonInputTarget.files[0]
    if (file) {
      this.fileNameTarget.textContent = `${file.name} (${this.formatSize(file.size)})`
      this.fileNameTarget.classList.remove("hidden")
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove("opacity-50", "cursor-not-allowed")
    } else {
      this.fileNameTarget.classList.add("hidden")
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
  }

  submitManual() {
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    this.submitButtonTarget.value = "저장 중..."
  }

  formatSize(bytes) {
    if (bytes < 1024) return `${bytes}B`
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(0)}KB`
    return `${(bytes / 1048576).toFixed(1)}MB`
  }
}
