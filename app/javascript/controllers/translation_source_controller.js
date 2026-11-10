import { Controller } from "@hotwired/stimulus"

// Expand the stored preferred translation below the always-visible source.
// CSS animates the accordion; this controller never requests inference.
export default class extends Controller {
  static targets = ["selected", "toggle", "label"]
  static values = { viewSelected: String, hideSelected: String }

  toggle() {
    if (!this.hasSelectedTarget) return

    const expanded = !this.selectedTarget.classList.contains("is-open")
    this.selectedTarget.classList.toggle("is-open", expanded)
    this.selectedTarget.setAttribute("aria-hidden", String(!expanded))
    this.toggleTarget.setAttribute("aria-expanded", String(expanded))
    this.labelTarget.textContent = expanded ? this.hideSelectedValue : this.viewSelectedValue
  }
}
