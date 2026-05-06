import { Controller } from "@hotwired/stimulus"
import { KOR_EOK_TO_MAN, KOR_CHEON_TO_MAN } from "controllers/constants"

// Formats 만원 amounts with Korean 억 notation for readability.
// Accepts various Korean input formats and normalizes to 만원 integer.
//
// Display: 12000 → "1억 2,000"
// Input parsing: "1억 2000", "1억2천", "12000", "1억" → 12000
// DB storage: always raw integer in 만원
//
// Usage:
//   <div data-controller="number-format">
//     <input type="text" data-number-format-target="display"
//            data-action="input->number-format#format blur->number-format#formatDisplay"
//            placeholder="1억 2,000">
//     <input type="hidden" data-number-format-target="hidden" name="budget_setting[available_cash]">
//   </div>
export default class extends Controller {
  static targets = ["display", "hidden"]
  static values = {
    initial: { type: Number, default: 0 }
  }

  connect() {
    if (this.initialValue > 0) {
      this.displayTarget.value = this.formatEok(this.initialValue)
      this.hiddenTarget.value = this.initialValue
    } else if (this.hiddenTarget.value) {
      const num = parseInt(this.hiddenTarget.value, 10)
      if (num > 0) {
        this.displayTarget.value = this.formatEok(num)
        this.hiddenTarget.value = num
      }
    }
  }

  // Called on every input keystroke — parse Korean input and update hidden field
  format() {
    const manwon = this.parseKoreanAmount(this.displayTarget.value)
    this.hiddenTarget.value = manwon > 0 ? manwon : ""
  }

  // Called on blur — reformat display to clean 억 notation
  formatDisplay() {
    const manwon = this.parseKoreanAmount(this.displayTarget.value)
    if (manwon > 0) {
      this.displayTarget.value = this.formatEok(manwon)
      this.hiddenTarget.value = manwon
    } else {
      this.displayTarget.value = ""
      this.hiddenTarget.value = ""
    }
  }

  // Parse Korean currency text to 만원 integer
  // Handles: "1억 2000", "1억2천", "12000", "1억", "5000", "1,2000"
  parseKoreanAmount(text) {
    if (!text || text.trim() === "") return 0

    let str = text.replace(/,/g, "").replace(/\s+/g, "").replace(/만원?/g, "")

    // Handle 억 notation
    const eokMatch = str.match(/(\d+)억(.*)/)
    if (eokMatch) {
      const eok = parseInt(eokMatch[1], 10) * KOR_EOK_TO_MAN
      let remainder = 0
      const rest = eokMatch[2]

      if (rest) {
        // Handle 천 (thousands): "2천" → 2000
        const cheonMatch = rest.match(/(\d+)천/)
        if (cheonMatch) {
          remainder = parseInt(cheonMatch[1], 10) * KOR_CHEON_TO_MAN
        } else {
          // Plain number after 억
          const digits = rest.replace(/[^0-9]/g, "")
          if (digits) remainder = parseInt(digits, 10)
        }
      }
      return eok + remainder
    }

    // Handle 천 without 억: "5천" → 5000
    const cheonOnly = str.match(/(\d+)천/)
    if (cheonOnly) {
      return parseInt(cheonOnly[1], 10) * KOR_CHEON_TO_MAN
    }

    // Plain number
    const digits = str.replace(/[^0-9]/g, "")
    return digits ? parseInt(digits, 10) : 0
  }

  // Format 만원 integer to Korean 억 display
  formatEok(manwon) {
    if (!manwon || manwon <= 0) return ""

    const eok = Math.floor(manwon / KOR_EOK_TO_MAN)
    const remainder = manwon % KOR_EOK_TO_MAN

    if (eok >= 1 && remainder > 0) {
      return `${eok}억 ${remainder.toLocaleString("ko-KR")}`
    } else if (eok >= 1) {
      return `${eok}억`
    }
    return manwon.toLocaleString("ko-KR")
  }
}
