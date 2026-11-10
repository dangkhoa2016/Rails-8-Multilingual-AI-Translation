import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "dialog", "connection", "warning", "message", "loading",
    "result", "resultTitle", "status", "checkedAt", "catalogInfo",
    "modelsSection", "models", "start", "close", "dismiss", "reauth"
  ]

  static values = {
    intro: String, ready: String, loading: String, success: String, error: String,
    count: String, more: String, noCatalog: String, session: String,
    rateLimit: String, unexpected: String, timeout: String
  }

  connect() {
    this.pending = false
  }

  disconnect() {
    this.abortController?.abort()
    if (this.hasDialogTarget && this.dialogTarget.open) this.dialogTarget.close()
  }

  open(event) {
    event.preventDefault()
    if (this.pending) return

    this.form = event.currentTarget.form
    if (!this.form) return

    this.connectionId = String(event.params.id)
    const name = String(event.params.name || "")
    this.connectionTarget.textContent = this.introValue.replace("__NAME__", name)
    this.messageTarget.textContent = this.readyValue
    this.warningTarget.hidden = false
    this.loadingTarget.hidden = true
    this.resultTarget.hidden = true
    this.reauthTarget.hidden = true
    this.modelsSectionTarget.hidden = true
    this.modelsTarget.replaceChildren()
    this.catalogInfoTarget.textContent = ""
    this.startTarget.hidden = false
    this.startTarget.disabled = false
    this.closeTarget.disabled = false
    this.dismissTarget.disabled = false
    this.dialogTarget.showModal()
  }

  async start(event) {
    event.preventDefault()
    if (this.pending || !this.form) return

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    if (!csrfToken) {
      this.finish(false, this.unexpectedValue)
      return
    }

    this.pending = true
    this.warningTarget.hidden = true
    this.loadingTarget.hidden = false
    this.resultTarget.hidden = true
    this.messageTarget.textContent = this.loadingValue
    this.startTarget.disabled = true
    this.closeTarget.disabled = true
    this.dismissTarget.disabled = true

    this.abortController = new AbortController()
    const timeout = window.setTimeout(() => this.abortController.abort(), 45000)

    try {
      const response = await fetch(this.form.action, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken,
          "X-Requested-With": "XMLHttpRequest"
        },
        signal: this.abortController.signal
      })

      if (response.redirected || response.status === 401 || response.status === 403) {
        this.reauthTarget.hidden = false
        this.finish(false, this.sessionValue)
        return
      }
      if (response.status === 429) {
        this.finish(false, this.rateLimitValue)
        return
      }

      if (!response.headers.get("content-type")?.includes("application/json")) {
        this.finish(false, this.unexpectedValue)
        return
      }

      const data = await response.json()
      if (typeof data.ok !== "boolean") {
        this.finish(false, this.unexpectedValue)
        return
      }

      this.finish(response.ok && data.ok, String(data.message || this.unexpectedValue), data)
    } catch (error) {
      this.finish(false, error.name === "AbortError" ? this.timeoutValue : this.unexpectedValue)
    } finally {
      window.clearTimeout(timeout)
      this.abortController = null
      this.pending = false
      this.closeTarget.disabled = false
      this.dismissTarget.disabled = false
      this.startTarget.disabled = true
    }
  }

  finish(success, message, data = null) {
    this.loadingTarget.hidden = true
    this.warningTarget.hidden = true
    this.resultTarget.hidden = false
    this.startTarget.hidden = true
    this.resultTitleTarget.textContent = success ? this.successValue : this.errorValue
    this.messageTarget.textContent = message
    this.resultTarget.dataset.outcome = success ? "success" : "error"

    this.statusTarget.textContent = data?.status || "—"
    this.checkedAtTarget.textContent = data?.checked_at_label || "—"

    const count = data?.model_count
    this.catalogInfoTarget.textContent = count === null || count === undefined
      ? (success ? this.noCatalogValue : "")
      : this.countValue.replace("__COUNT__", String(count))

    this.modelsTarget.replaceChildren()
    const models = Array.isArray(data?.models) ? data.models : []
    for (const model of models) {
      if (typeof model !== "string") continue
      const item = document.createElement("li")
      item.className = "app-probe-model-item"
      item.textContent = model
      this.modelsTarget.append(item)
    }
    this.modelsSectionTarget.hidden = this.modelsTarget.childElementCount === 0

    // Update the settings row immediately without a full-page reload.
    if (data?.status && data?.checked_at_label && this.connectionId) {
      const row = this.element.querySelector('[data-probe-status-id="' + this.connectionId + '"]')
      if (row) row.textContent = data.status
      const time = this.element.querySelector('[data-probe-time-id="' + this.connectionId + '"]')
      if (time) time.textContent = data.checked_at_label
    }
  }

  close() {
    if (!this.pending && this.dialogTarget.open) this.dialogTarget.close()
  }

  cancel(event) {
    if (this.pending) event.preventDefault()
  }
}
