import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="file-upload"
export default class extends Controller {
  static targets = ["input", "filename", "preview", "placeholder"]

  connect() {
    this.updateDisplay()
  }

  update(event) {
    this.updateDisplay()
  }

  updateDisplay() {
    if (this.inputTarget.files && this.inputTarget.files.length > 0) {
      const file = this.inputTarget.files[0]
      this.filenameTarget.textContent = file.name
      this.placeholderTarget.classList.add("hidden")
      this.previewTarget.classList.remove("hidden")
    } else {
      this.placeholderTarget.classList.remove("hidden")
      this.previewTarget.classList.add("hidden")
    }
  }

  // Handle drag and drop visual feedback
  dragover(event) {
    event.preventDefault()
    this.element.classList.add("border-primary-500", "bg-primary-50")
  }

  dragleave(event) {
    event.preventDefault()
    this.element.classList.remove("border-primary-500", "bg-primary-50")
  }

  drop(event) {
    event.preventDefault()
    this.element.classList.remove("border-primary-500", "bg-primary-50")
    
    if (event.dataTransfer.files && event.dataTransfer.files.length > 0) {
      this.inputTarget.files = event.dataTransfer.files
      this.updateDisplay()
    }
  }
}
