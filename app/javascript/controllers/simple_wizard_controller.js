import { Controller } from "@hotwired/stimulus"

/**
 * SimpleWizardController - Clean, Typeform-style wizard
 *
 * Replaces the complex 918-line wizard_controller.js with a focused,
 * maintainable implementation that handles one question at a time.
 */
export default class extends Controller {
  static targets = [
    "screen",           // Individual question screens
    "progress",         // Progress bar
    "counter",          // Question counter (e.g., "5 / 23")
    "sectionBadge",     // Current section name
    "continueBtn",      // Continue button
    "backBtn",          // Back button
    "sectionRoadmap"    // Section progress indicators
  ]

  static values = {
    currentIndex: { type: Number, default: 0 },
    totalQuestions: Number,
    formCode: String,
    questionFlow: Array  // Question flow configuration from schema
  }

  connect() {
    console.log("SimpleWizard connected", {
      totalQuestions: this.totalQuestionsValue,
      formCode: this.formCodeValue
    })

    // Initialize progress from localStorage
    this.restoreProgress()

    // Show first question
    this.showCurrentScreen()

    // Set up keyboard shortcuts
    this.setupKeyboardShortcuts()

    // Auto-focus on input
    this.focusCurrentInput()
  }

  disconnect() {
    // Clean up keyboard listeners
    document.removeEventListener("keydown", this.handleKeydown)
  }

  // ============================================================================
  // NAVIGATION
  // ============================================================================

  next(event) {
    event?.preventDefault()

    // Validate current field before advancing
    if (!this.canAdvance()) {
      this.showValidationError()
      return
    }

    // Advance to next question
    if (this.currentIndexValue < this.totalQuestionsValue - 1) {
      this.currentIndexValue++
      this.showCurrentScreen()
      this.updateProgress()
      this.persistProgress()
      this.focusCurrentInput()
    } else {
      // Reached the end - submit form
      this.finish()
    }
  }

  previous(event) {
    event?.preventDefault()

    if (this.currentIndexValue > 0) {
      this.currentIndexValue--
      this.showCurrentScreen()
      this.updateProgress()
      this.persistProgress()
      this.focusCurrentInput()
    }
  }

  goTo(index) {
    if (index >= 0 && index < this.totalQuestionsValue) {
      this.currentIndexValue = index
      this.showCurrentScreen()
      this.updateProgress()
      this.persistProgress()
      this.focusCurrentInput()
    }
  }

  finish() {
    // Show completion message and redirect to preview/download
    const formPath = `/forms/${this.formCodeValue}`
    window.location.href = `${formPath}/preview`
  }

  // ============================================================================
  // SCREEN DISPLAY
  // ============================================================================

  showCurrentScreen() {
    // Hide all screens
    this.screenTargets.forEach((screen, index) => {
      if (index === this.currentIndexValue) {
        screen.classList.remove("hidden")
        screen.classList.add("wizard-screen-active")

        // Simple fade-in animation
        screen.style.animation = "fadeIn 0.3s ease-in-out"
      } else {
        screen.classList.add("hidden")
        screen.classList.remove("wizard-screen-active")
      }
    })

    // Update section badge
    this.updateSectionBadge()

    // Update navigation buttons
    this.updateNavigationButtons()

    // Update continue button state
    this.updateContinueButton()
  }

  // ============================================================================
  // PROGRESS TRACKING
  // ============================================================================

  updateProgress() {
    const percentage = ((this.currentIndexValue + 1) / this.totalQuestionsValue) * 100

    // Update progress bar
    if (this.hasProgressTarget) {
      this.progressTarget.value = percentage
      this.progressTarget.setAttribute("aria-valuenow", Math.round(percentage))
    }

    // Update counter
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${this.currentIndexValue + 1} → ${this.totalQuestionsValue}`
    }

    // Update section roadmap if available
    this.updateSectionRoadmap()
  }

  updateSectionBadge() {
    if (!this.hasQuestionFlowValue || !this.hasSectionBadgeTarget) return

    const currentScreen = this.screenTargets[this.currentIndexValue]
    const sectionName = currentScreen?.dataset.section

    if (sectionName) {
      this.sectionBadgeTarget.textContent = sectionName
      this.sectionBadgeTarget.classList.remove("hidden")
    } else {
      this.sectionBadgeTarget.classList.add("hidden")
    }
  }

  updateSectionRoadmap() {
    if (!this.hasSectionRoadmapTarget) return

    const currentScreen = this.screenTargets[this.currentIndexValue]
    const currentSection = currentScreen?.dataset.section

    // Update roadmap steps (completed/active/upcoming)
    const roadmapSteps = this.sectionRoadmapTarget.querySelectorAll(".section-step")

    roadmapSteps.forEach(step => {
      const stepSection = step.dataset.section

      if (stepSection === currentSection) {
        step.classList.add("active")
        step.classList.remove("completed")
      } else {
        step.classList.remove("active")
        // Mark as completed if before current section
        const stepIndex = Array.from(roadmapSteps).indexOf(step)
        const currentStepIndex = Array.from(roadmapSteps).findIndex(s => s.dataset.section === currentSection)

        if (stepIndex < currentStepIndex) {
          step.classList.add("completed")
        } else {
          step.classList.remove("completed")
        }
      }
    })
  }

  updateNavigationButtons() {
    // Show/hide back button
    if (this.hasBackBtnTarget) {
      if (this.currentIndexValue === 0) {
        this.backBtnTarget.classList.add("invisible")
      } else {
        this.backBtnTarget.classList.remove("invisible")
      }
    }

    // Update continue button text
    if (this.hasContinueBtnTarget) {
      const isLastQuestion = this.currentIndexValue === this.totalQuestionsValue - 1
      this.continueBtnTarget.textContent = isLastQuestion ? "Complete Form →" : "Continue →"
    }
  }

  updateContinueButton() {
    if (!this.hasContinueBtnTarget) return

    const canContinue = this.canAdvance()
    this.continueBtnTarget.disabled = !canContinue

    if (canContinue) {
      this.continueBtnTarget.classList.remove("btn-disabled")
    } else {
      this.continueBtnTarget.classList.add("btn-disabled")
    }
  }

  // ============================================================================
  // VALIDATION
  // ============================================================================

  canAdvance() {
    const currentScreen = this.screenTargets[this.currentIndexValue]
    if (!currentScreen) return false

    // Find required input in current screen
    const requiredInput = currentScreen.querySelector("[required]")
    if (!requiredInput) return true  // No required fields, can advance

    // Check if input has value
    if (requiredInput.type === "checkbox" || requiredInput.type === "radio") {
      return requiredInput.checked || currentScreen.querySelector("input:checked")
    } else {
      return requiredInput.value.trim() !== ""
    }
  }

  showValidationError() {
    const currentScreen = this.screenTargets[this.currentIndexValue]
    const errorContainer = currentScreen?.querySelector(".validation-error")

    if (errorContainer) {
      errorContainer.classList.remove("hidden")
      errorContainer.textContent = "This field is required. Please provide an answer to continue."

      // Hide after 3 seconds
      setTimeout(() => {
        errorContainer.classList.add("hidden")
      }, 3000)
    }
  }

  // ============================================================================
  // INPUT HANDLING
  // ============================================================================

  fieldChanged(event) {
    // Update continue button state when field changes
    this.updateContinueButton()

    // Auto-advance on selection (for radio/select)
    if (event.target.type === "radio" || event.target.tagName === "SELECT") {
      // Small delay to let user see selection
      setTimeout(() => {
        if (this.canAdvance()) {
          this.next()
        }
      }, 300)
    }
  }

  focusCurrentInput() {
    const currentScreen = this.screenTargets[this.currentIndexValue]
    if (!currentScreen) return

    const input = currentScreen.querySelector("input:not([type='hidden']), textarea, select")
    if (input) {
      // Delay to ensure screen is visible
      setTimeout(() => {
        input.focus()
      }, 350)
    }
  }

  // ============================================================================
  // KEYBOARD SHORTCUTS
  // ============================================================================

  setupKeyboardShortcuts() {
    this.handleKeydown = (event) => {
      // Enter = next (if not in textarea)
      if (event.key === "Enter" && event.target.tagName !== "TEXTAREA") {
        event.preventDefault()
        this.next()
      }

      // Escape = previous
      if (event.key === "Escape") {
        event.preventDefault()
        this.previous()
      }

      // Arrow keys (with Cmd/Ctrl for safety)
      if ((event.metaKey || event.ctrlKey) && event.key === "ArrowRight") {
        event.preventDefault()
        this.next()
      }

      if ((event.metaKey || event.ctrlKey) && event.key === "ArrowLeft") {
        event.preventDefault()
        this.previous()
      }
    }

    document.addEventListener("keydown", this.handleKeydown)
  }

  // ============================================================================
  // PERSISTENCE
  // ============================================================================

  persistProgress() {
    const storageKey = `wizard_progress_${this.formCodeValue}`
    const progressData = {
      currentIndex: this.currentIndexValue,
      timestamp: Date.now()
    }

    try {
      localStorage.setItem(storageKey, JSON.stringify(progressData))
    } catch (error) {
      console.warn("Failed to persist wizard progress:", error)
    }
  }

  restoreProgress() {
    const storageKey = `wizard_progress_${this.formCodeValue}`

    try {
      const saved = localStorage.getItem(storageKey)
      if (saved) {
        const { currentIndex, timestamp } = JSON.parse(saved)

        // Only restore if less than 24 hours old
        const age = Date.now() - timestamp
        if (age < 24 * 60 * 60 * 1000) {
          this.currentIndexValue = currentIndex
        }
      }
    } catch (error) {
      console.warn("Failed to restore wizard progress:", error)
    }
  }
}
