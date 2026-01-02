import { Controller } from '@hotwired/stimulus';

/**
 * Scroll Spy Controller
 * Highlights navigation items based on current scroll position
 * Provides smooth scrolling to sections
 */
export default class extends Controller {
  static targets = ['nav', 'link', 'section'];

  static values = {
    offset: { type: Number, default: 100 }, // Offset from top for activation
    activeClass: { type: String, default: 'active' }
  };

  connect() {
    this.handleScroll = this.handleScroll.bind(this);
    window.addEventListener('scroll', this.handleScroll, { passive: true });

    // Initial check
    this.handleScroll();
  }

  disconnect() {
    window.removeEventListener('scroll', this.handleScroll);
  }

  /**
   * Handle scroll event - update active section
   */
  handleScroll() {
    if (!this.hasSectionTarget || !this.hasLinkTarget) {
      return;
    }

    const scrollPosition = window.scrollY + this.offsetValue;
    let currentSection = null;

    // Find the current section
    this.sectionTargets.forEach(section => {
      const sectionTop = section.offsetTop;
      const sectionBottom = sectionTop + section.offsetHeight;

      if (scrollPosition >= sectionTop && scrollPosition < sectionBottom) {
        currentSection = section.id;
      }
    });

    // If no section found, use the first or last based on position
    if (!currentSection && this.sectionTargets.length > 0) {
      const firstSection = this.sectionTargets[0];
      const lastSection = this.sectionTargets[this.sectionTargets.length - 1];

      if (scrollPosition < firstSection.offsetTop) {
        currentSection = firstSection.id;
      } else {
        currentSection = lastSection.id;
      }
    }

    // Update active states
    this.updateActiveLink(currentSection);
  }

  /**
   * Update which link is active
   */
  updateActiveLink(sectionId) {
    this.linkTargets.forEach(link => {
      const href = link.getAttribute('href');
      const isActive = href === `#${sectionId}`;

      if (isActive) {
        link.classList.add(this.activeClassValue);
        link.setAttribute('aria-current', 'true');
      } else {
        link.classList.remove(this.activeClassValue);
        link.removeAttribute('aria-current');
      }
    });
  }

  /**
   * Scroll to a section smoothly
   */
  scrollTo(event) {
    event.preventDefault();

    const href = event.currentTarget.getAttribute('href');

    if (!href || !href.startsWith('#')) {
      return;
    }

    const sectionId = href.slice(1);
    const section = document.getElementById(sectionId);

    if (section) {
      const targetPosition = section.offsetTop - this.offsetValue + 20;

      window.scrollTo({
        top: targetPosition,
        behavior: 'smooth'
      });

      // Update URL hash without jumping
      history.pushState(null, '', href);
    }
  }
}
