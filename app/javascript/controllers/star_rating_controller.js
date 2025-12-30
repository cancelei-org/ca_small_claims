import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['input', 'star', 'label'];
  static values = {
    rating: { type: Number, default: 0 }
  };

  connect() {
    this.updateDisplay();
  }

  select(event) {
    const rating = parseInt(event.currentTarget.dataset.rating);

    this.ratingValue = rating;
    this.inputTarget.value = rating;
    this.updateDisplay();
  }

  hover(event) {
    const rating = parseInt(event.currentTarget.dataset.rating);

    this.highlightStars(rating);
  }

  leave() {
    this.updateDisplay();
  }

  updateDisplay() {
    this.highlightStars(this.ratingValue);
    this.updateLabel();
  }

  highlightStars(rating) {
    this.starTargets.forEach((star, index) => {
      const starRating = index + 1;

      if (starRating <= rating) {
        star.classList.add('text-warning');
        star.classList.remove('text-base-300');
      } else {
        star.classList.remove('text-warning');
        star.classList.add('text-base-300');
      }
    });
  }

  updateLabel() {
    if (!this.hasLabelTarget) {
      return;
    }

    const labels = {
      0: 'Select a rating',
      1: 'Very Poor',
      2: 'Poor',
      3: 'Average',
      4: 'Good',
      5: 'Excellent'
    };

    this.labelTarget.textContent = labels[this.ratingValue] || labels[0];
  }
}
