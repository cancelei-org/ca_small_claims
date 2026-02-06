import { Controller } from '@hotwired/stimulus';

/**
 * Court Finder Controller
 * Handles courthouse search, filtering, and Leaflet map integration
 */
export default class extends Controller {
  static targets = [
    'searchInput',
    'countySelect',
    'map',
    'results',
    'resultCount'
  ];

  static values = {
    markersUrl: String
  };

  connect() {
    this.debounceTimer = null;
    this.map = null;
    this.markers = [];
    this.markerLayer = null;

    // Initialize map after a short delay to ensure the container is ready
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

  /**
   * Initialize Leaflet map with OpenStreetMap tiles
   */
  initializeMap() {
    if (!this.hasMapTarget || typeof L === 'undefined') {
      console.warn('Leaflet not loaded or map target not found');

      return;
    }

    // California center coordinates
    const californiaCenter = [36.7783, -119.4179];
    const defaultZoom = 6;

    // Create map instance
    this.map = L.map(this.mapTarget, {
      center: californiaCenter,
      zoom: defaultZoom,
      scrollWheelZoom: true
    });

    // Add OpenStreetMap tile layer (free, no API key needed)
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 19
    }).addTo(this.map);

    // Create marker layer group
    this.markerLayer = L.layerGroup().addTo(this.map);

    // Load initial markers
    this.loadMarkers();
  }

  /**
   * Load courthouse markers from the API
   */
  async loadMarkers(county = null) {
    if (!this.hasMarkersUrlValue) {
      return;
    }

    try {
      let url = this.markersUrlValue;

      if (county) {
        url += `?county=${encodeURIComponent(county)}`;
      }

      const response = await fetch(url);
      const courthouses = await response.json();

      this.updateMarkers(courthouses);
    } catch (error) {
      console.error('Failed to load courthouse markers:', error);
    }
  }

  /**
   * Update map markers with courthouse data
   */
  updateMarkers(courthouses) {
    if (!this.markerLayer) {
      return;
    }

    // Clear existing markers
    this.markerLayer.clearLayers();
    this.markers = [];

    // Custom marker icon
    const courtIcon = L.divIcon({
      className: 'courthouse-marker',
      html: `
        <div class="bg-primary text-primary-content rounded-full w-8 h-8 flex items-center justify-center shadow-lg border-2 border-white">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-4 h-4">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0 0 12 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75Z" />
          </svg>
        </div>
      `,
      iconSize: [32, 32],
      iconAnchor: [16, 32],
      popupAnchor: [0, -32]
    });

    // Add markers for each courthouse
    courthouses.forEach(courthouse => {
      if (!courthouse.latitude || !courthouse.longitude) {
        return;
      }

      const marker = L.marker([courthouse.latitude, courthouse.longitude], {
        icon: courtIcon
      });

      // Create popup content
      const popupContent = `
        <div class="p-2 min-w-[200px]">
          <h3 class="font-semibold text-sm mb-1">${courthouse.name}</h3>
          <p class="text-xs text-gray-600 mb-2">${courthouse.county} County</p>
          <p class="text-xs mb-1">${courthouse.address}</p>
          ${courthouse.phone ? `<p class="text-xs mb-2"><a href="tel:${courthouse.phone.replace(/[^\d]/gu, '')}" class="text-blue-600">${courthouse.phone}</a></p>` : ''}
          <div class="flex gap-2 mt-2">
            <a href="https://maps.google.com/maps?daddr=${encodeURIComponent(courthouse.address)}"
               target="_blank"
               class="text-xs bg-blue-500 text-white px-2 py-1 rounded hover:bg-blue-600">
              Directions
            </a>
            <a href="/courthouses/${courthouse.id}"
               class="text-xs bg-gray-500 text-white px-2 py-1 rounded hover:bg-gray-600">
              Details
            </a>
          </div>
        </div>
      `;

      marker.bindPopup(popupContent);
      marker.courthouseId = courthouse.id;
      marker.addTo(this.markerLayer);
      this.markers.push(marker);
    });

    // Fit map bounds to show all markers
    if (this.markers.length > 0) {
      const group = L.featureGroup(this.markers);

      this.map.fitBounds(group.getBounds().pad(0.1));
    }
  }

  /**
   * Debounced search handler
   */
  debounceSearch() {
    clearTimeout(this.debounceTimer);
    this.debounceTimer = setTimeout(() => {
      this.search();
    }, 300);
  }

  /**
   * Perform search via Turbo
   */
  search() {
    const searchValue = this.hasSearchInputTarget
      ? this.searchInputTarget.value
      : '';

    if (this.hasCountySelectTarget) {
      this.countySelectTarget.value = '';
    }

    this.fetchResults({ search: searchValue });
  }

  /**
   * Filter by county
   */
  filterByCounty(event) {
    const county = event.target.value;

    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = '';
    }

    this.fetchResults({ county });
    this.loadMarkers(county);
  }

  /**
   * Quick search from popular buttons
   */
  quickSearch(event) {
    const searchValue =
      event.target.dataset.search || event.currentTarget.dataset.search;

    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = searchValue;
    }

    if (this.hasCountySelectTarget) {
      this.countySelectTarget.value = '';
    }

    this.fetchResults({ search: searchValue });
  }

  /**
   * Clear search and show all
   */
  clearSearch() {
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = '';
    }

    if (this.hasCountySelectTarget) {
      this.countySelectTarget.value = '';
    }

    this.fetchResults({});
    this.loadMarkers();
  }

  /**
   * Fetch results via Turbo Stream
   */
  async fetchResults(params) {
    const url = new URL(window.location.href);

    // Clear existing params
    url.searchParams.delete('search');
    url.searchParams.delete('county');
    url.searchParams.delete('city');
    url.searchParams.delete('zip');

    // Add new params
    Object.entries(params).forEach(([key, value]) => {
      if (value) {
        url.searchParams.set(key, value);
      }
    });

    try {
      const response = await fetch(url, {
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'Turbo-Frame': 'courthouse-results'
        }
      });

      if (response.ok) {
        const html = await response.text();

        Turbo.renderStreamMessage(html);

        // Update URL without reload
        window.history.replaceState({}, '', url);

        // Update markers based on results
        this.updateMarkersFromResults();
      }
    } catch (error) {
      console.error('Failed to fetch results:', error);
    }
  }

  /**
   * Update markers based on visible results
   */
  updateMarkersFromResults() {
    if (!this.hasResultsTarget || !this.markerLayer) {
      return;
    }

    const resultCards = this.resultsTarget.querySelectorAll(
      '[data-courthouse-id]'
    );
    const visibleIds = Array.from(resultCards).map(card =>
      parseInt(card.dataset.courthouseId)
    );

    // Filter markers to only show visible courthouses
    this.markers.forEach(marker => {
      if (visibleIds.includes(marker.courthouseId)) {
        if (!this.markerLayer.hasLayer(marker)) {
          marker.addTo(this.markerLayer);
        }
      } else {
        this.markerLayer.removeLayer(marker);
      }
    });

    // Fit bounds to visible markers
    const visibleMarkers = this.markers.filter(m =>
      this.markerLayer.hasLayer(m)
    );

    if (visibleMarkers.length > 0) {
      const group = L.featureGroup(visibleMarkers);

      this.map.fitBounds(group.getBounds().pad(0.1));
    }

    // Update result count
    if (this.hasResultCountTarget) {
      this.resultCountTarget.textContent = visibleIds.length;
    }
  }

  /**
   * Focus on a specific marker when clicking a result card
   */
  focusMarker(event) {
    event.preventDefault();
    event.stopPropagation();

    const target = event.currentTarget;
    const lat = parseFloat(target.dataset.latitude);
    const lng = parseFloat(target.dataset.longitude);

    if (!isNaN(lat) && !isNaN(lng) && this.map) {
      this.map.setView([lat, lng], 14);

      // Find and open the marker popup
      const courthouseId = parseInt(target.dataset.courthouseId);
      const marker = this.markers.find(m => m.courthouseId === courthouseId);

      if (marker) {
        marker.openPopup();
      }

      // Scroll map into view on mobile
      if (window.innerWidth < 1024) {
        this.mapTarget.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    }
  }
}
