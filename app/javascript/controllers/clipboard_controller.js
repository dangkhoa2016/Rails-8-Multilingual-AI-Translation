import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = ["content", "expandLabel", "copyLabel"]
  static values = { expand: String, collapse: String, copy: String, copied: String, failed: String }
  expand(event) {
    const collapsed = this.contentTarget.classList.toggle("max-h-48")
    this.contentTarget.classList.toggle("overflow-hidden", collapsed)
    this.expandLabelTarget.textContent = collapsed ? this.expandValue : this.collapseValue
  }
  async copy(event) {
    try {
      await navigator.clipboard.writeText(this.contentTarget.textContent)
      this.copyLabelTarget.textContent = this.copiedValue
    } catch (_) { this.copyLabelTarget.textContent = this.failedValue }
  }
}
