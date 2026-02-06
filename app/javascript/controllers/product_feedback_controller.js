import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["titleInput", "titleCount", "descInput", "descCount"]

  connect() {
    this.updateTitleCount()
    this.updateDescCount()
  }

  updateTitleCount() {
    if (this.hasTitleInputTarget && this.hasTitleCountTarget) {
      this.titleCountTarget.textContent = this.titleInputTarget.value.length
    }
  }

  updateDescCount() {
    if (this.hasDescInputTarget && this.hasDescCountTarget) {
      this.descCountTarget.textContent = this.descInputTarget.value.length
    }
  }

  updateCategory(event) {
    // Visual feedback handled by CSS, but could add additional logic here
  }

  validateAttachments(event) {
    const files = event.target.files
    const maxSize = 5 * 1024 * 1024 // 5MB
    const maxFiles = 5
    const allowedTypes = ['image/png', 'image/jpeg', 'image/gif', 'image/webp']

    if (files.length > maxFiles) {
      alert(`You can only upload up to ${maxFiles} files.`)
      event.target.value = ''
      return
    }

    for (const file of files) {
      if (!allowedTypes.includes(file.type)) {
        alert(`${file.name} is not a supported file type. Please upload PNG, JPEG, GIF, or WebP images.`)
        event.target.value = ''
        return
      }

      if (file.size > maxSize) {
        alert(`${file.name} is too large. Maximum file size is 5MB.`)
        event.target.value = ''
        return
      }
    }
  }
}
