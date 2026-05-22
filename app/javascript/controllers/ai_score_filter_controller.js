import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  clean(event) {
    this.element.querySelectorAll("input, select").forEach(el => {
      if (!el.value) el.disabled = true
    })
  }
}
