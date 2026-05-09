import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { definition: String }

  show(event) {
    event.preventDefault()
    if (window.glossaryPopover) window.glossaryPopover.remove()
    const popover = document.createElement("div")
    popover.className = "fixed inset-x-4 bottom-4 sm:absolute sm:inset-auto sm:mt-2 z-50 max-w-sm rounded-lg bg-zinc-800 dark:bg-zinc-700 p-3 text-sm text-white shadow-lg"
    popover.innerHTML = `<div class="font-semibold mb-1">${this.element.textContent}</div><div>${this.definitionValue}</div><button class="mt-2 text-xs underline" type="button">닫기</button>`
    popover.querySelector("button").addEventListener("click", () => popover.remove())
    document.body.appendChild(popover)
    window.glossaryPopover = popover
  }
}
