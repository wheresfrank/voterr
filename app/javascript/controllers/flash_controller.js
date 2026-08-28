import { Controller } from "@hotwired/stimulus"

// Auto-dismisses flash messages a few seconds after they appear,
// with a fade-out. Also dismissible via the close button.
const DISMISS_AFTER_MS = 4000

export default class extends Controller {
  connect() {
    this.timeout = setTimeout(() => this.dismiss(), DISMISS_AFTER_MS)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    clearTimeout(this.timeout)
    if (this.leaving) return
    this.leaving = true

    this.element.classList.add("app-flash--leaving")
    this.element.addEventListener("transitionend", () => this.element.remove(), { once: true })
    // Fallback in case transitionend never fires (e.g. reduced motion)
    setTimeout(() => this.element.remove(), 500)
  }
}