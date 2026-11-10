import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["select"]
  static values = { errorMessage: String }

  connect() {
    this.savedValue = this.selectTarget.value
  }

  async change() {
    const select = this.selectTarget
    const next = select.value
    const isTheme = select.name === "ui_theme"
    if (next === this.savedValue) return

    // Theme changes are immediate and do not navigate or redraw the workspace.
    if (isTheme) document.documentElement.dataset.theme = next
    const payload = new URLSearchParams(new FormData(this.element))
    select.disabled = true

    try {
      const csrf = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch(this.element.action, {
        method: "PATCH",
        credentials: "same-origin",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
          "X-CSRF-Token": csrf || ""
        },
        body: payload
      })
      if (!response.ok) throw new Error(`Preference save failed: ${response.status}`)

      this.savedValue = next
      if (!isTheme) {
        // Translations are rendered on the server. Turbo Drive refreshes the
        // currently viewed page without a full document reload or HTTP redirect.
        // Rails receives the newly signed locale cookie on this GET.
        this.preserveFormDraftsDuringNavigation()
        Turbo.visit(window.location.pathname + window.location.search, { action: "replace" })
      }
    } catch (error) {
      select.value = this.savedValue
      if (isTheme) document.documentElement.dataset.theme = this.savedValue
      this.showError(this.hasErrorMessageValue ? this.errorMessageValue : "Unable to save preference")
      console.error(error)
    } finally {
      select.disabled = false
    }
  }

  preserveFormDraftsDuringNavigation() {
    // The locale needs a server-rendered translation, but input drafts should
    // survive Turbo's in-place rendering. Never store passwords or tokens.
    const selector = '#app-main form input:not([type="hidden"]):not([type="password"]):not([type="file"]), #app-main form textarea, #app-main form select'
    const draft = Array.from(document.querySelectorAll(selector)).map((field) => ({
      name: field.name, type: field.type, value: field.value,
      checked: field.checked
    }))

    if (!draft.length) return

    const restore = (event) => {
      const destination = event.detail?.newBody
      if (!destination) return
      const inputs = Array.from(destination.querySelectorAll(selector))
      inputs.forEach((field, i) => {
        const previous = draft[i]
        if (!previous || previous.name !== field.name || previous.type !== field.type) return
        if (field.type === "checkbox" || field.type === "radio") field.checked = previous.checked
        else field.value = previous.value
      })
    }
    document.addEventListener("turbo:before-render", restore)
    document.addEventListener("turbo:load", () => {
      document.removeEventListener("turbo:before-render", restore)
    }, { once: true })
  }

  showError(message) {
    const notice = document.createElement("div")
    notice.setAttribute("role", "alert")
    notice.className = "app-flash app-flash-error"
    notice.textContent = message
    const main = document.getElementById("app-main")
    if (main) main.prepend(notice)
  }
}
