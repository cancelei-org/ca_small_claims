import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['card', 'link', 'code'];

  connect() {
    this.checkActivity();
  }

  checkActivity() {
    const activityJson = localStorage.getItem('last_form_activity');

    if (!activityJson) {
      return;
    }

    try {
      const activity = JSON.parse(activityJson);
      const now = Date.now();
      const hoursSince = (now - activity.timestamp) / (1000 * 60 * 60);

      // Show if within 24 hours and not currently on the same page
      if (hoursSince < 24 && window.location.pathname !== activity.path) {
        this.show(activity);
      }
    } catch (e) {
      console.error('Error parsing activity log', e);
    }
  }

  show(activity) {
    this.linkTarget.href = activity.path;
    this.codeTarget.textContent = activity.step
      ? `${activity.code} · Step ${activity.step}`
      : activity.code;

    // Slide in animation
    this.cardTarget.classList.remove(
      'translate-x-full',
      'translate-y-full',
      'opacity-0'
    );
  }

  dismiss() {
    this.cardTarget.classList.add('translate-x-full', 'opacity-0');
    // Optional: Clear activity or mark as dismissed?
    // localStorage.removeItem('last_form_activity');
  }
}
