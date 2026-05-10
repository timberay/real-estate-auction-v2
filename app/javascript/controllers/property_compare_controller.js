import { Controller } from "@hotwired/stimulus"

const SESSION_KEY = "property_compare_ids"
const MAX_SELECT = 10

export default class extends Controller {
  static targets = ["checkbox", "actionBar", "count", "compareButton"]

  connect() {
    this.selectedIds = this.#loadFromSession()
    this.#syncCheckboxes()
    this.#updateActionBar()
  }

  toggle(event) {
    const id = event.currentTarget.dataset.propertyId
    if (event.currentTarget.checked) {
      if (this.selectedIds.size >= MAX_SELECT) {
        event.currentTarget.checked = false
        return
      }
      this.selectedIds.add(id)
    } else {
      this.selectedIds.delete(id)
    }
    this.#saveToSession()
    this.#updateActionBar()
  }

  clear() {
    this.selectedIds.clear()
    this.#saveToSession()
    this.#syncCheckboxes()
    this.#updateActionBar()
  }

  submit() {
    if (this.selectedIds.size < 2) return
    const ids = Array.from(this.selectedIds).join(",")
    window.location.href = `/properties/compare?ids=${ids}`
  }

  #loadFromSession() {
    try {
      const raw = sessionStorage.getItem(SESSION_KEY)
      return raw ? new Set(JSON.parse(raw)) : new Set()
    } catch {
      return new Set()
    }
  }

  #saveToSession() {
    sessionStorage.setItem(SESSION_KEY, JSON.stringify(Array.from(this.selectedIds)))
  }

  #syncCheckboxes() {
    this.checkboxTargets.forEach(cb => {
      cb.checked = this.selectedIds.has(cb.dataset.propertyId)
    })
  }

  #updateActionBar() {
    const count = this.selectedIds.size
    if (this.hasCountTarget) {
      this.countTarget.textContent = `선택한 ${count}건`
    }
    if (this.hasCompareButtonTarget) {
      this.compareButtonTarget.disabled = count < 2
    }
    if (this.hasActionBarTarget) {
      if (count === 0) {
        this.actionBarTarget.classList.add("hidden")
      } else {
        this.actionBarTarget.classList.remove("hidden")
      }
    }
  }
}
