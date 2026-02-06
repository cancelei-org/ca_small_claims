import { Controller } from '@hotwired/stimulus';

// Mobile-friendly pull-to-refresh for lists without requiring native browser refresh.
export default class extends Controller {
  static targets = ['indicator', 'label', 'icon'];
  static values = {
    threshold: { type: Number, default: 80 },
    maxPull: { type: Number, default: 140 }
  };

  connect() {
    this.handleTouchStart = this.onTouchStart.bind(this);
    this.handleTouchMove = this.onTouchMove.bind(this);
    this.handleTouchEnd = this.onTouchEnd.bind(this);

    this.element.addEventListener('touchstart', this.handleTouchStart, {
      passive: true
    });
    this.element.addEventListener('touchmove', this.handleTouchMove, {
      passive: false
    });
    this.element.addEventListener('touchend', this.handleTouchEnd, {
      passive: true
    });

    this.reset();
  }

  disconnect() {
    this.element.removeEventListener('touchstart', this.handleTouchStart);
    this.element.removeEventListener('touchmove', this.handleTouchMove);
    this.element.removeEventListener('touchend', this.handleTouchEnd);
  }

  onTouchStart(event) {
    if (window.scrollY > 0) {
      this.reset();

      return;
    }

    const [touch] = event.touches;

    this.startY = touch.clientY;
    this.isPulling = true;
  }

  onTouchMove(event) {
    if (!this.isPulling) {
      return;
    }

    const [touch] = event.touches;
    const deltaY = touch.clientY - this.startY;

    if (deltaY <= 0) {
      this.reset();

      return;
    }

    // Prevent native overscroll
    event.preventDefault();

    const pullDistance = Math.min(deltaY, this.maxPullValue);
    const progress = Math.min(1, pullDistance / this.thresholdValue);

    this.showIndicator(pullDistance, progress);
  }

  onTouchEnd() {
    if (!this.isPulling) {
      return;
    }

    this.isPulling = false;

    if (this.pullDistance >= this.thresholdValue) {
      this.triggerRefresh();
    } else {
      this.resetIndicator();
    }
  }

  showIndicator(distance, progress) {
    this.pullDistance = distance;
    this.indicatorTarget.classList.remove('opacity-0', '-translate-y-6');
    this.indicatorTarget.style.transform = `translateY(${distance / 3}px)`;
    this.iconTarget.style.transform = `rotate(${progress * 180}deg)`;

    if (progress >= 1) {
      this.labelTarget.textContent = 'Release to refresh';
    } else {
      const percent = Math.round(progress * 100);

      this.labelTarget.textContent = `Pull to refresh (${percent}%)`;
    }
  }

  triggerRefresh() {
    this.labelTarget.textContent = 'Refreshing...';
    this.iconTarget.classList.add('animate-spin', 'opacity-80');
    this.indicatorTarget.style.transform = 'translateY(16px)';

    // Use Turbo if available for a smooth reload
    setTimeout(() => {
      if (window.Turbo?.visit) {
        window.Turbo.visit(window.location.href);
      } else {
        window.location.reload();
      }
    }, 150);
  }

  resetIndicator() {
    this.indicatorTarget.classList.add('opacity-0', '-translate-y-6');
    this.indicatorTarget.style.transform = '';
    this.iconTarget.classList.remove('animate-spin');
    this.iconTarget.style.transform = '';
    this.labelTarget.textContent = 'Pull to refresh';
  }

  reset() {
    this.pullDistance = 0;
    this.isPulling = false;
    this.resetIndicator();
  }
}
