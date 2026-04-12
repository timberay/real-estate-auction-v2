import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit", "fileList"]
  static values = { hasExisting: Boolean }

  connect() {
    this.updateState()
  }

  select() {
    const files = this.inputTarget.files
    this.renderFileList(files)
    this.updateState()
  }

  updateState() {
    const hasFiles = this.inputTarget.files.length > 0 || this.hasExistingValue
    this.submitTarget.disabled = !hasFiles

    if (hasFiles) {
      this.submitTarget.classList.remove("opacity-50", "cursor-not-allowed")
    } else {
      this.submitTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
  }

  renderFileList(files) {
    if (!this.hasFileListTarget) return

    if (files.length === 0) {
      this.fileListTarget.classList.add("hidden")
      this.fileListTarget.innerHTML = ""
      return
    }

    this.fileListTarget.classList.remove("hidden")
    const items = Array.from(files).map(f =>
      `<li class="flex items-center gap-1.5">
        <svg class="w-4 h-4 text-slate-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"/>
        </svg>
        <span class="truncate">${f.name}</span>
        <span class="text-slate-500 flex-shrink-0">(${this.formatSize(f.size)})</span>
      </li>`
    ).join("")

    this.fileListTarget.innerHTML = `<ul class="space-y-1">${items}</ul>`
  }

  formatSize(bytes) {
    if (bytes < 1024) return `${bytes}B`
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(0)}KB`
    return `${(bytes / 1048576).toFixed(1)}MB`
  }
}
