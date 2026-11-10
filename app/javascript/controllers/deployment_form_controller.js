import { Controller } from "@hotwired/stimulus"

// The active deployment is a saved configuration, not the model's enabled flag.
// Only permit a new version when the selected connection or identifier changes.
export default class extends Controller {
  static targets = ["connection", "identifier", "submit"]
  static values = {
    hasActive: Boolean,
    activeConnection: String,
    activeIdentifier: String,
    activateLabel: String,
    updateLabel: String,
    currentLabel: String
  }

  connect() {
    this.refresh()
  }

  refresh() {
    const connectionId = this.connectionTarget.value
    const identifier = this.identifierTarget.value.trim()
    const unchanged = this.hasActiveValue &&
      connectionId === this.activeConnectionValue &&
      identifier === this.activeIdentifierValue

    this.submitTarget.disabled = !connectionId || !identifier || unchanged
    this.submitTarget.value = unchanged
      ? this.currentLabelValue
      : (this.hasActiveValue ? this.updateLabelValue : this.activateLabelValue)
  }
}
