import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "categoryButton", "results"]
  static values = {
    url: String,
    debounceDelay: { type: Number, default: 300 }
  }

  connect() {
    this.debounceTimer = null
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  search() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    this.debounceTimer = setTimeout(() => {
      this.performSearch()
    }, this.debounceDelayValue)
  }

  selectCategory(event) {
    event.preventDefault()

    // Update active state on category buttons
    this.categoryButtonTargets.forEach(btn => {
      btn.classList.remove("btn-primary")
      btn.classList.add("btn-outline")
    })

    const clickedButton = event.currentTarget
    if (clickedButton.dataset.category) {
      clickedButton.classList.remove("btn-outline")
      clickedButton.classList.add("btn-primary")
    }

    this.performSearch()
  }

  clearCategory(event) {
    event.preventDefault()

    // Reset all category buttons
    this.categoryButtonTargets.forEach(btn => {
      btn.classList.remove("btn-primary")
      btn.classList.add("btn-outline")
    })

    this.performSearch()
  }

  performSearch() {
    const searchValue = this.hasSearchInputTarget ? this.searchInputTarget.value : ""
    const activeCategory = this.categoryButtonTargets.find(btn =>
      btn.classList.contains("btn-primary")
    )
    const categoryValue = activeCategory ? activeCategory.dataset.category : ""

    const url = new URL(this.urlValue, window.location.origin)
    if (searchValue) url.searchParams.set("search", searchValue)
    if (categoryValue) url.searchParams.set("category", categoryValue)

    fetch(url, {
      headers: {
        "Accept": "text/vnd.turbo-stream.html"
      }
    })
      .then(response => response.text())
      .then(html => {
        Turbo.renderStreamMessage(html)
      })
  }
}
