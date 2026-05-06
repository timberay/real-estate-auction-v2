import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "autoTab", "manualTab", "autoPanel", "manualPanel",
    "jsonInput", "submitButton", "fileName", "fileNameText",
    "copyButton", "copyIcon", "checkIcon",
    "fileMethodTab", "pasteMethodTab", "fileInputPanel", "pasteInputPanel",
    "jsonTextInput", "pasteSubmitButton"
  ]
  static values = { promptUrl: String }

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
    this.#updatePageTitle(this.autoTabTarget.textContent.trim())
  }

  showManual() {
    this.manualPanelTarget.classList.remove("hidden")
    this.autoPanelTarget.classList.add("hidden")
    this.manualTabTarget.classList.add("border-blue-500", "text-blue-600", "dark:text-blue-400")
    this.manualTabTarget.classList.remove("border-transparent", "text-slate-500")
    this.autoTabTarget.classList.remove("border-blue-500", "text-blue-600", "dark:text-blue-400")
    this.autoTabTarget.classList.add("border-transparent", "text-slate-500")
    this.#updatePageTitle(this.manualTabTarget.textContent.trim())
  }

  #updatePageTitle(title) {
    const el = document.getElementById("page-title")
    if (el) el.textContent = title
  }

  // --- Input method toggle ---

  showFileInput() {
    this.fileInputPanelTarget.classList.remove("hidden")
    this.pasteInputPanelTarget.classList.add("hidden")
    this.#activateMethodTab(this.fileMethodTabTarget)
    this.#deactivateMethodTab(this.pasteMethodTabTarget)
  }

  showPasteInput() {
    this.pasteInputPanelTarget.classList.remove("hidden")
    this.fileInputPanelTarget.classList.add("hidden")
    this.#activateMethodTab(this.pasteMethodTabTarget)
    this.#deactivateMethodTab(this.fileMethodTabTarget)
  }

  // --- File input ---

  selectJson() {
    const file = this.jsonInputTarget.files[0]
    if (file) {
      this.fileNameTextTarget.textContent = `${file.name} (${this.formatSize(file.size)})`
      this.#enableButton(this.submitButtonTarget)
    } else {
      this.fileNameTextTarget.textContent = "선택된 파일 없음"
      this.#disableButton(this.submitButtonTarget)
    }
  }

  triggerFileSelect() {
    this.jsonInputTarget.click()
  }

  // --- Paste input ---

  checkPasteInput() {
    if (this.jsonTextInputTarget.value.trim().length > 0) {
      this.#enableButton(this.pasteSubmitButtonTarget)
    } else {
      this.#disableButton(this.pasteSubmitButtonTarget)
    }
  }

  // --- Submit ---

  submitManual() {
    const button = this.fileInputPanelTarget.classList.contains("hidden")
      ? this.pasteSubmitButtonTarget
      : this.submitButtonTarget

    this.#disableButton(button)
    const textNode = Array.from(button.childNodes).find(n => n.nodeType === Node.TEXT_NODE && n.textContent.trim())
    if (textNode) textNode.textContent = " 저장 중..."
  }

  // --- Prompt copy ---

  async copyPrompt() {
    const button = this.copyButtonTarget
    button.disabled = true

    try {
      const response = await fetch(this.promptUrlValue)
      const data = await response.json()
      await navigator.clipboard.writeText(data.prompt)

      this.copyIconTarget.classList.add("hidden")
      this.checkIconTarget.classList.remove("hidden")
      button.querySelector("span").textContent = "복사 완료"

      setTimeout(() => {
        this.copyIconTarget.classList.remove("hidden")
        this.checkIconTarget.classList.add("hidden")
        button.querySelector("span").textContent = "프롬프트 복사"
        button.disabled = false
      }, 2000)
    } catch {
      button.disabled = false
    }
  }

  // --- Helpers ---

  formatSize(bytes) {
    if (bytes < 1024) return `${bytes}B`
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(0)}KB`
    return `${(bytes / 1048576).toFixed(1)}MB`
  }

  #activateMethodTab(tab) {
    tab.classList.add("border-blue-500", "text-blue-600", "dark:text-blue-400")
    tab.classList.remove("border-transparent", "text-slate-500", "hover:border-slate-300", "hover:text-slate-700", "dark:text-slate-400", "dark:hover:text-slate-300")
  }

  #deactivateMethodTab(tab) {
    tab.classList.remove("border-blue-500", "text-blue-600", "dark:text-blue-400")
    tab.classList.add("border-transparent", "text-slate-500", "hover:border-slate-300", "hover:text-slate-700", "dark:text-slate-400", "dark:hover:text-slate-300")
  }

  #enableButton(button) {
    button.disabled = false
    button.classList.remove("opacity-50", "cursor-not-allowed")
  }

  #disableButton(button) {
    button.disabled = true
    button.classList.add("opacity-50", "cursor-not-allowed")
  }
}
