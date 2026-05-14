import { Controller } from "@hotwired/stimulus"

// Sortable rows on the compare board. Clicking a row's sort button reorders
// the property columns by that row's `data-sort-value`, toggling asc → desc
// → original order.
//
// Wiring (in compare view):
//   <table data-controller="comparison-sort">
//     <thead><tr> ... <th data-column-index="0"> ... </tr></thead>
//     <tbody>
//       <tr data-sort-key="appraisal_price">
//         <td>...<button data-action="click->comparison-sort#sort">정렬</button></td>
//         <td data-column-index="0" data-sort-value="800000000">8억</td>
//         ...
export default class extends Controller {
  connect() {
    this.sortKey = null
    this.sortDirection = null
  }

  sort(event) {
    const row = event.currentTarget.closest("tr[data-sort-key]")
    if (!row) return
    const key = row.dataset.sortKey

    if (this.sortKey === key) {
      this.sortDirection = this.sortDirection === "asc" ? "desc" : null
      if (this.sortDirection === null) this.sortKey = null
    } else {
      this.sortKey = key
      this.sortDirection = "asc"
    }

    this.#applySort()
  }

  #applySort() {
    let newOrder

    if (this.sortKey === null) {
      // Restore original order by data-column-index
      const sampleRow = this.element.querySelector("thead tr")
      newOrder = Array.from(sampleRow.querySelectorAll("[data-column-index]"))
        .map(c => parseInt(c.dataset.columnIndex, 10))
        .sort((a, b) => a - b)
    } else {
      const activeRow = this.element.querySelector(`tr[data-sort-key='${this.sortKey}']`)
      const cells = Array.from(activeRow.querySelectorAll("td[data-column-index]"))
      const pairs = cells.map(c => ({
        index: parseInt(c.dataset.columnIndex, 10),
        value: parseFloat(c.dataset.sortValue) || 0,
        originalPos: parseInt(c.dataset.columnIndex, 10)
      }))
      pairs.sort((a, b) => {
        const diff = this.sortDirection === "asc" ? a.value - b.value : b.value - a.value
        return diff !== 0 ? diff : a.originalPos - b.originalPos
      })
      newOrder = pairs.map(p => p.index)
    }

    this.#reorderColumns(newOrder)
    this.#updateIndicators()
  }

  #reorderColumns(newOrder) {
    const rows = this.element.querySelectorAll("thead tr, tbody tr")
    rows.forEach(row => {
      const dataCells = Array.from(row.querySelectorAll("[data-column-index]"))
      const byIndex = new Map(dataCells.map(c => [ parseInt(c.dataset.columnIndex, 10), c ]))
      newOrder.forEach(idx => {
        const cell = byIndex.get(idx)
        if (cell) row.appendChild(cell)
      })
    })
  }

  #updateIndicators() {
    this.element.querySelectorAll("[data-sort-indicator]").forEach(el => {
      el.textContent = "↕"
    })
    if (!this.sortKey) return
    const activeRow = this.element.querySelector(`tr[data-sort-key='${this.sortKey}']`)
    const indicator = activeRow?.querySelector("[data-sort-indicator]")
    if (indicator) indicator.textContent = this.sortDirection === "asc" ? "↑" : "↓"
  }
}
