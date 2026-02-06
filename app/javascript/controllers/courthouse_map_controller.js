import { Controller } from '@hotwired/stimulus';

/**
 * Courthouse Map Controller
 * Simple controller for single courthouse detail page map
 */
export default class extends Controller {
  static targets = ['map'];
  static values = {
    courthouse: Object
  };

  connect() {
    requestAnimationFrame(() => {
      this.initializeMap();
    });
  }

  disconnect() {
    if (this.map) {
      this.map.remove();
      this.map = null;
    }
  }

  initializeMap() {
    if (!this.hasMapTarget || typeof L === 'undefined') {
      console.warn('Leaflet not loaded or map target not found');

      return;
    }

    if (!this.hasCourthouseValue) {
      console.warn('No courthouse data provided');

      return;
    }

    const courthouse = this.courthouseValue;

    if (!courthouse.latitude || !courthouse.longitude) {
      console.warn('Courthouse has no coordinates');

      return;
    }

    // Create map centered on courthouse
    this.map = L.map(this.mapTarget, {
      center: [courthouse.latitude, courthouse.longitude],
      zoom: 15,
      scrollWheelZoom: false
    });

    // Add OpenStreetMap tile layer
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      maxZoom: 19
    }).addTo(this.map);

    // Custom marker icon
    const courtIcon = L.divIcon({
      className: 'courthouse-marker',
      html: `
        <div class="bg-primary text-primary-content rounded-full w-10 h-10 flex items-center justify-center shadow-lg border-2 border-white">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-5 h-5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0 0 12 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75Z" />
          </svg>
        </div>
      `,
      iconSize: [40, 40],
      iconAnchor: [20, 40],
      popupAnchor: [0, -40]
    });

    // Add marker
    const marker = L.marker([courthouse.latitude, courthouse.longitude], {
      icon: courtIcon
    }).addTo(this.map);

    // Add popup
    marker
      .bindPopup(
        `
      <div class="p-2">
        <h3 class="font-semibold text-sm">${courthouse.name}</h3>
        <p class="text-xs">${courthouse.address}</p>
      </div>
    `
      )
      .openPopup();

    // Enable scroll zoom on click
    this.map.on('click', () => {
      this.map.scrollWheelZoom.enable();
    });

    // Disable scroll zoom when leaving map
    this.map.on('mouseout', () => {
      this.map.scrollWheelZoom.disable();
    });
  }
}
