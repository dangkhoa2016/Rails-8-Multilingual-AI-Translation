import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Action Cable notifications are only wake-up signals: the authenticated GET
// reads the current PostgreSQL snapshot, never the billable inference API.
export default class extends Controller {
  static targets = ["signal"]
  static values = { url: String, finished: Boolean, interval: { type: Number, default: 5000 } }

  connect() {
    this.connected = true
    this.stopped = this.finishedValue
    this.inFlight = false
    this.progressVersion = null
    this.timer = null
    this.abortController = null
    this.requestTimeout = null
    this.visibilityHandler = () => {
      if (!document.hidden) this.schedule(0)
    }
    document.addEventListener("visibilitychange", this.visibilityHandler)
    if (!this.stopped) this.schedule(1200)
  }

  disconnect() {
    this.connected = false
    clearTimeout(this.timer)
    this.abortController?.abort()
    clearTimeout(this.requestTimeout)
    document.removeEventListener("visibilitychange", this.visibilityHandler)
  }

  signalTargetConnected() {
    // Fires for a Turbo Stream replacement from the worker (and on initial
    // target initialization, before connect). No provider POST is issued.
    if (this.connected && !this.stopped) this.schedule(100)
  }

  schedule(delay) {
    if (!this.connected || this.stopped) return
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.refresh(), delay)
  }

  async refresh() {
    if (!this.connected || this.stopped) return
    if (this.inFlight || document.hidden) {
      this.schedule(this.intervalValue)
      return
    }

    this.inFlight = true
    this.abortController = new AbortController()
    this.requestTimeout = setTimeout(() => this.abortController?.abort(), 12000)
    try {
      const headers = { Accept: "text/vnd.turbo-stream.html" }
      if (this.progressVersion) headers["X-Progress-Version"] = this.progressVersion
      const response = await fetch(this.urlValue, {
        method: "GET",
        credentials: "same-origin",
        headers,
        signal: this.abortController.signal
      })

      // Never inject HTML from a redirected login page as a Turbo Stream.
      if (response.redirected || [401, 403].includes(response.status)) {
        this.stopped = true
        return
      }
      if (response.status === 204) {
        this.stopped = response.headers.get("X-Translation-Terminal") === "true"
      } else if (response.ok && response.headers.get("Content-Type")?.includes("text/vnd.turbo-stream.html")) {
        this.progressVersion = response.headers.get("X-Progress-Version")
        Turbo.renderStreamMessage(await response.text())
        this.stopped = response.headers.get("X-Translation-Terminal") === "true"
      }
    } catch (error) {
      if (error.name !== "AbortError") {
        // Network errors recover on the next bounded polling interval.
        this.progressVersion = null
      }
    } finally {
      clearTimeout(this.requestTimeout)
      this.requestTimeout = null
      this.inFlight = false
      this.abortController = null
      this.schedule(this.intervalValue)
    }
  }
}
