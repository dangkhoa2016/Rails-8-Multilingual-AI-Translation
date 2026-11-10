import { Controller } from "@hotwired/stimulus"

// Input validation is mirrored server-side before any provider job is queued.
// Lengths count Unicode code points (matching Ruby String#length), not UTF-16 units.
export default class extends Controller {
  static targets = ["checkbox", "selectAll", "count", "source", "sourceLanguage", "targetLanguage",
    "characterCount", "wordCount", "lengthNotice", "warning", "approval", "glossary"]
  static values = {
    countMessage: String, confirmMessage: String, invalidMessage: String,
    characterMessage: String, wordMessage: String,
    appLimit: Number, appLimitMessage: String, modelLimitMessage: String,
    glossaryUnsupportedMessage: String
  }

  connect() {
    this.update()
  }

  update() {
    const available = this.checkboxTargets.filter((checkbox) => !checkbox.disabled)
    const selectedCount = available.filter((checkbox) => checkbox.checked).length
    const maxSelectable = Math.min(4, available.length)
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.disabled = maxSelectable === 0
      this.selectAllTarget.checked = maxSelectable > 0 && selectedCount === maxSelectable
      this.selectAllTarget.indeterminate = selectedCount > 0 && selectedCount !== maxSelectable
    }
    const count = this.checkboxTargets.filter((checkbox) => checkbox.checked).length
    if (this.hasCountTarget) this.countTarget.textContent = count
    if (this.hasWarningTarget) {
      this.warningTarget.textContent = this.countMessageValue.replace("__COUNT__", String(count))
    }
    this.updateText()
  }

  toggleAll() {
    if (!this.hasSelectAllTarget) return
    const select = this.selectAllTarget.checked
    let remaining = 4
    this.checkboxTargets.forEach((checkbox) => {
      if (checkbox.disabled) return
      checkbox.checked = select && remaining-- > 0
    })
    this.update()
  }

  sourceLength() {
    return this.hasSourceTarget ? Array.from(this.sourceTarget.value).length : 0
  }

  incompatibleModels(characters) {
    return this.checkboxTargets.filter((checkbox) => {
      const limit = Number(checkbox.dataset.maxSourceLength)
      return checkbox.checked && !checkbox.disabled && limit > 0 && characters > limit
    })
  }

  lengthError(characters) {
    if (this.hasAppLimitValue && characters > this.appLimitValue) {
      return this.appLimitMessageValue.replace("__LIMIT__", String(this.appLimitValue))
    }
    const incompatible = this.incompatibleModels(characters)
    if (!incompatible.length) return ""
    const names = incompatible.map((checkbox) =>
      `${checkbox.dataset.modelName} (${checkbox.dataset.maxSourceLength})`).join(", ")
    return this.modelLimitMessageValue.replace("__MODELS__", names)
  }

  glossaryError() {
    if (!this.hasGlossaryTarget || !this.glossaryTarget.checked) return ""
    const unsupported = this.checkboxTargets.filter((checkbox) =>
      checkbox.checked && !checkbox.disabled && checkbox.dataset.adapterKey !== "openai_chat_completions"
    )
    if (!unsupported.length) return ""
    return this.glossaryUnsupportedMessageValue.replace("__MODELS__",
      unsupported.map((checkbox) => checkbox.dataset.modelName).join(", "))
  }

  updateText() {
    if (!this.hasSourceTarget) return
    const characters = this.sourceLength()
    const trimmed = this.sourceTarget.value.trim()
    const words = trimmed ? (trimmed.match(/\S+/gu) || []).length : 0
    if (this.hasCharacterCountTarget) {
      this.characterCountTarget.textContent = this.characterMessageValue.replace("__COUNT__", String(characters))
    }
    if (this.hasWordCountTarget) {
      this.wordCountTarget.textContent = this.wordMessageValue.replace("__COUNT__", String(words))
    }
    const lengthError = this.lengthError(characters)
    const error = lengthError || this.glossaryError()
    if (this.hasLengthNoticeTarget) {
      this.lengthNoticeTarget.hidden = !error
      this.lengthNoticeTarget.textContent = error
    }
    if (lengthError) this.sourceTarget.setAttribute("aria-invalid", "true")
    else this.sourceTarget.removeAttribute("aria-invalid")
    const incompatible = this.incompatibleModels(characters)
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.closest(".studio-model-card")?.classList.toggle("is-over-limit", incompatible.includes(checkbox))
    })
    return !error
  }

  swapLanguages() {
    if (!this.hasSourceLanguageTarget || !this.hasTargetLanguageTarget) return
    const source = this.sourceLanguageTarget.value
    this.sourceLanguageTarget.value = this.targetLanguageTarget.value
    this.targetLanguageTarget.value = source
    this.sourceLanguageTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.targetLanguageTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  confirm(event) {
    const count = this.checkboxTargets.filter((checkbox) => checkbox.checked).length
    if (count < 1 || count > 4) {
      this.approvalTarget.value = "0"
      event.preventDefault()
      window.alert(this.invalidMessageValue)
      return
    }
    if (!this.updateText()) {
      this.approvalTarget.value = "0"
      event.preventDefault()
      if (this.hasLengthNoticeTarget) {
        this.lengthNoticeTarget.scrollIntoView({ block: "center" })
        this.lengthNoticeTarget.focus()
      }
      return
    }
    if (!window.confirm(this.confirmMessageValue.replace("__COUNT__", String(count)))) {
      this.approvalTarget.value = "0"
      event.preventDefault()
    } else {
      this.approvalTarget.value = "1"
    }
  }
}
