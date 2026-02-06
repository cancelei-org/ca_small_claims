import { Controller } from '@hotwired/stimulus';

// Calculates last service date based on hearing date and service type
export default class extends Controller {
  static targets = ['hearingDate', 'serviceType', 'resultDate', 'daysLabel'];

  connect() {
    this.update();
  }

  update() {
    const hearing = this.hearingDateTarget.value;
    const offset = parseInt(this.serviceTypeTarget.value || '0');

    if (!hearing) {
      this.resultDateTarget.textContent = 'Select a hearing date';
      this.daysLabelTarget.textContent = '';

      return;
    }

    const hearingDate = new Date(hearing);
    const deadline = new Date(hearingDate);

    deadline.setDate(deadline.getDate() - offset);

    this.resultDateTarget.textContent = deadline.toLocaleDateString(undefined, {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      year: 'numeric'
    });
    this.daysLabelTarget.textContent = `${offset} days before the hearing`;
  }
}
