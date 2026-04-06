import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step"]

  navigate(event) {
    const step = event.currentTarget
    const status = step.dataset.stepStatus

    if (status === "pending") {
      event.preventDefault()
      event.stopPropagation()
      this.showWarning(step)
      return
    }

    // Update active state visually for completed steps
    if (status === "completed") {
      this.updateActiveStep(step)
    }
  }

  showWarning(clickedStep) {
    const frame = document.getElementById("tab_content")
    if (!frame) return

    const key = clickedStep.dataset.stepKey
    const labels = { checklist: "체크리스트", report: "권리 분석", rating: "등급 산정" }

    // Find the previous step's label
    const steps = ["checklist", "report", "rating"]
    const clickedIndex = steps.indexOf(key)
    const previousKey = steps[clickedIndex - 1]
    const previousLabel = labels[previousKey] || "이전 단계"

    frame.innerHTML = `
      <div class="bg-slate-800 border border-amber-700 rounded-lg p-6 text-center">
        <p class="text-amber-500 font-medium mb-1">이전 단계를 먼저 완료해주세요</p>
        <p class="text-slate-400 text-sm">"${previousLabel}" 단계를 완료한 후 진행할 수 있습니다.</p>
      </div>
    `
  }

  updateActiveStep(clickedStep) {
    this.stepTargets.forEach(step => {
      const isClicked = step === clickedStep
      const status = step.dataset.stepStatus

      if (isClicked) {
        step.dataset.stepStatus = "active"
        step.classList.remove("bg-blue-900/50", "text-blue-300", "bg-slate-800", "text-slate-500")
        step.classList.add("bg-blue-600", "text-white", "font-semibold")
      } else if (status === "active") {
        step.dataset.stepStatus = "completed"
        step.classList.remove("bg-blue-600", "text-white", "font-semibold")
        step.classList.add("bg-blue-900/50", "text-blue-300")
      }
    })
  }
}
