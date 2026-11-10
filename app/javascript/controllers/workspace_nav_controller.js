import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "backdrop", "mobileToggle", "compactToggle"]

  connect() {
    this.onKeydown = (event) => {
      if (event.key === "Escape") this.closeMobile()
    }
    this.onMediaChange = (event) => {
      if (!event.matches) this.closeMobile()
    }
    document.addEventListener("keydown", this.onKeydown)
    this.mobileMedia = window.matchMedia("(max-width: 1180px)")
    this.mobileMedia.addEventListener("change", this.onMediaChange)
    try {
      if (window.localStorage.getItem("translation_sidebar_compact") === "1") {
        this.element.classList.add("nav-compact")
      }
    } catch (_) {
      // Browser privacy modes may disable local storage.
    }
    this.updateCompactToggle()
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    this.mobileMedia?.removeEventListener("change", this.onMediaChange)
    this.closeMobile()
  }

  toggleMobile() {
    this.element.classList.contains("nav-mobile-open") ? this.closeMobile() : this.openMobile()
  }

  openMobile() {
    this.element.classList.add("nav-mobile-open")
    this.mobileToggleTargets.forEach((button) => button.setAttribute("aria-expanded", "true"))
    this.sidebarTarget.querySelector(".app-nav-close")?.focus()
  }

  closeMobile() {
    this.element.classList.remove("nav-mobile-open")
    this.mobileToggleTargets.forEach((button) => button.setAttribute("aria-expanded", "false"))
  }

  toggleCompact() {
    this.element.classList.toggle("nav-compact")
    const compact = this.element.classList.contains("nav-compact")
    try {
      window.localStorage.setItem("translation_sidebar_compact", compact ? "1" : "0")
    } catch (_) {
      // The UI remains functional if browser storage is unavailable.
    }
    this.updateCompactToggle()
  }

  updateCompactToggle() {
    const expanded = !this.element.classList.contains("nav-compact")
    this.compactToggleTargets.forEach((button) => button.setAttribute("aria-expanded", String(expanded)))
  }
}
