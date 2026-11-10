import { Controller } from "@hotwired/stimulus"

// Read-only comparison of already rendered results.
// DOM nodes are created with textContent; provider text is never interpreted as HTML.
export default class extends Controller {
  static targets = ["results", "content", "twoButton", "fourButton", "diffButton"]

  connect() {
    this.columnMode = "two"
    this.diffEnabled = false
    this.originals = new WeakMap()
    this.refresh()
  }

  resultsTargetConnected() {
    if (this.originals) this.refresh()
  }

  contentTargetConnected() {
    if (this.originals && this.diffEnabled) this.refreshDifferences()
  }

  twoColumns() {
    this.columnMode = "two"
    this.refresh()
  }

  fourColumns() {
    this.columnMode = "four"
    this.refresh()
  }

  toggleDifferences() {
    this.diffEnabled = !this.diffEnabled
    this.refresh()
  }

  refresh() {
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.toggle("is-four-column", this.columnMode === "four")
    }
    if (this.hasTwoButtonTarget) {
      this.twoButtonTarget.setAttribute("aria-pressed", String(this.columnMode === "two"))
      this.twoButtonTarget.classList.toggle("is-active", this.columnMode === "two")
    }
    if (this.hasFourButtonTarget) {
      this.fourButtonTarget.setAttribute("aria-pressed", String(this.columnMode === "four"))
      this.fourButtonTarget.classList.toggle("is-active", this.columnMode === "four")
    }
    const available = this.completedContent().length > 1
    if (!available) this.diffEnabled = false
    if (this.hasDiffButtonTarget) {
      this.diffButtonTarget.disabled = !available
      this.diffButtonTarget.setAttribute("aria-pressed", String(this.diffEnabled))
      this.diffButtonTarget.classList.toggle("is-active", this.diffEnabled)
    }
    this.refreshDifferences()
  }

  completedContent() {
    return this.contentTargets.filter((pre) =>
      pre.closest("article")?.dataset.translationCompareCompleted === "true"
    )
  }

  originalText(pre) {
    if (!this.originals.has(pre)) this.originals.set(pre, pre.textContent)
    return this.originals.get(pre)
  }

  refreshDifferences() {
    if (!this.originals) return
    const complete = this.completedContent()
    const reference = complete.find((pre) =>
      pre.closest("article")?.dataset.translationComparePreferred === "true"
    ) || complete[0]
    const referenceLines = reference ? this.originalText(reference).split("\n") : []

    for (const pre of this.contentTargets) {
      const original = this.originalText(pre)
      const isCompleted = complete.includes(pre)
      const isReference = pre === reference
      if (!this.diffEnabled || !isCompleted || isReference) {
        pre.replaceChildren(document.createTextNode(original))
        pre.classList.remove("has-differences")
        continue
      }
      const fragment = document.createDocumentFragment()
      const lines = original.split("\n")
      lines.forEach((line, index) => {
        if (line !== referenceLines[index]) {
          const marked = document.createElement("span")
          marked.className = "translation-diff-line"
          marked.textContent = line
          fragment.appendChild(marked)
        } else {
          fragment.appendChild(document.createTextNode(line))
        }
        if (index < lines.length - 1) fragment.appendChild(document.createTextNode("\n"))
      })
      pre.replaceChildren(fragment)
      pre.classList.add("has-differences")
    }
  }
}
