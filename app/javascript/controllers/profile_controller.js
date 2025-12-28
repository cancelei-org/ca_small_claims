import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    debounceDelay: { type: Number, default: 1000 }
  }

  connect() {
    this.debounceTimer = null
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  save() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    // Show saving indicator
    this.updateStatus("Saving...", "saving")

    this.debounceTimer = setTimeout(() => {
      this.performSave()
    }, this.debounceDelayValue)
  }

  performSave() {
    const form = this.element
    const formData = new FormData(form)

    fetch(this.urlValue, {
      method: "PATCH",
      body: formData,
      headers: {
        "Accept": "text/vnd.turbo-stream.html"
      }
    })
      .then(response => {
        if (response.ok) {
          return response.text()
        }
        throw new Error("Save failed")
      })
      .then(html => {
        Turbo.renderStreamMessage(html)
      })
      .catch(error => {
        console.error("Profile save error:", error)
        this.updateStatus("Failed to save", "error")
      })
  }

  updateStatus(message, status) {
    const statusEl = document.getElementById("profile-status")
    if (statusEl) {
      let badgeClass = "badge-info"
      let icon = '<span class="loading loading-spinner loading-xs"></span>'

      if (status === "success") {
        badgeClass = "badge-success"
        icon = '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-3 h-3"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" /></svg>'
      } else if (status === "error") {
        badgeClass = "badge-error"
        icon = '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-3 h-3"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>'
      }

      statusEl.innerHTML = `<div class="badge ${badgeClass} gap-1">${icon} ${message}</div>`
    }
  }
}
