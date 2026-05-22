import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdown", "label", "checkbox", "button"]

  connect() {
    this.updateLabel()
    this._outsideClick = this._handleOutsideClick.bind(this)
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  disconnect() {
    if (this._outsideClick) {
      document.removeEventListener("click", this._outsideClick)
    }
  }

  toggle(event) {
    event.stopPropagation()
    this.dropdownTarget.classList.contains("hidden") ? this._open() : this._close()
  }

  updateLabel() {
    if (!this.hasLabelTarget) return
    const checked = this.checkboxTargets.filter(c => c.checked)
    if (checked.length === 0) {
      this.labelTarget.textContent = "All locations"
    } else if (checked.length === 1) {
      this.labelTarget.textContent = checked[0].value
    } else {
      this.labelTarget.textContent = `${checked.length} locations`
    }
  }

  _open() {
    this.dropdownTarget.classList.remove("hidden")
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "true")
    document.addEventListener("click", this._outsideClick)
  }

  _close() {
    this.dropdownTarget.classList.add("hidden")
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this._outsideClick)
  }

  _handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this._close()
    }
  }
}
