import { Controller } from "@hotwired/stimulus"

/**
 * PDF Drawer Controller
 * Handles the mobile/tablet PDF preview drawer slide-in panel
 */
export default class extends Controller {
  static targets = ["drawer", "backdrop", "panel"]

  connect() {
    // Close drawer on escape key
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
    this.enableBodyScroll()
  }

  open() {
    if (this.hasDrawerTarget) {
      this.drawerTarget.classList.add("open")
    }
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove("hidden")
      // Trigger reflow for transition
      void this.backdropTarget.offsetWidth
      this.backdropTarget.classList.add("open")
    }
    this.disableBodyScroll()

    // Dispatch event for PDF preview controller to refresh
    this.dispatch("opened")
  }

  close() {
    if (this.hasDrawerTarget) {
      this.drawerTarget.classList.remove("open")
    }
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove("open")
      // Wait for transition before hiding
      setTimeout(() => {
        if (!this.backdropTarget.classList.contains("open")) {
          this.backdropTarget.classList.add("hidden")
        }
      }, 300)
    }
    this.enableBodyScroll()

    this.dispatch("closed")
  }

  toggle() {
    if (this.hasDrawerTarget && this.drawerTarget.classList.contains("open")) {
      this.close()
    } else {
      this.open()
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  disableBodyScroll() {
    document.body.style.overflow = "hidden"
  }

  enableBodyScroll() {
    document.body.style.overflow = ""
  }
}
