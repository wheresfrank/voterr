import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["burger", "menu"]

  connect() {
  }

  toggleMenu() {
    const isOpen = this.menuTarget.classList.toggle("is-active")
    this.burgerTarget.classList.toggle("is-active", isOpen)
    this.burgerTarget.setAttribute("aria-expanded", isOpen.toString())
  }
}
