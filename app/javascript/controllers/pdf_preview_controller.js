import { Controller } from '@hotwired/stimulus';
import { DEBOUNCE_DELAYS, createDebouncedHandler } from 'utilities/debounce';
import { STATUS_TYPES } from 'utils/status_indicator';

export default class extends Controller {
  static targets = [
    'canvas',
    'viewer',
    'loading',
    'error',
    'autoRefreshToggle',
    'statusText',
    'refreshIcon',
    'pageNumber',
    'pageCount',
    'prevButton',
    'nextButton',
    'xrayButton',
    // Mobile overlay targets
    'zoomDisplay',
    'mobilePageNumber',
    'mobilePageCount',
    'mobilePrevButton',
    'mobileNextButton',
    'pinchHint'
  ];

  static values = {
    url: String,
    debounceDelay: { type: Number, default: DEBOUNCE_DELAYS.FAST },
    autoRefresh: { type: Boolean, default: true },
    fieldMappings: Object,
    xrayMode: Boolean,
    minScale: { type: Number, default: 0.5 },
    maxScale: { type: Number, default: 3.0 }
  };

  static STATUS_MESSAGES = {
    [STATUS_TYPES.IDLE]: 'Up to date',
    [STATUS_TYPES.LOADING]: 'Loading...',
    [STATUS_TYPES.UPDATING]: 'Updating...',
    [STATUS_TYPES.QUEUED]: 'Update queued',
    [STATUS_TYPES.ERROR]: 'Error',
    paused: 'Auto-refresh paused'
  };

  connect() {
    this.pdfDoc = null;
    this.pageNum = 1;
    this.pageRendering = false;
    this.pageNumPending = null;
    this.scale = 1.5;
    this.ctx = this.canvasTarget.getContext('2d');
    this.highlightedFieldName = null;

    this.isLoading = false;
    this.pendingRefresh = false;

    // Touch gesture state for pinch-to-zoom
    this.initialPinchDistance = null;
    this.initialScale = this.scale;
    this.isTouching = false;

    this.debouncedRefresh = createDebouncedHandler(() => this.performRefresh());

    this.handleFormSaved = this.handleFormSaved.bind(this);
    this.handleHighlight = this.handleHighlight.bind(this);
    this.handleClearHighlight = this.handleClearHighlight.bind(this);

    document.addEventListener('form:saved', this.handleFormSaved);
    document.addEventListener('form:highlight-field', this.handleHighlight);
    document.addEventListener(
      'form:clear-highlight',
      this.handleClearHighlight
    );

    // Bind touch handlers for pinch-to-zoom
    this.bindTouchGestures();

    this.loadPreview();
  }

  disconnect() {
    this.debouncedRefresh.cancel();
    document.removeEventListener('form:saved', this.handleFormSaved);
    document.removeEventListener('form:highlight-field', this.handleHighlight);
    document.removeEventListener(
      'form:clear-highlight',
      this.handleClearHighlight
    );
    this.unbindTouchGestures();
  }

  // ==========================================
  // Touch Gesture Handling for Mobile
  // ==========================================

  /**
   * Bind touch event handlers for pinch-to-zoom
   */
  bindTouchGestures() {
    if (!this.hasViewerTarget) {
      return;
    }

    this._handleTouchStart = this.handleTouchStart.bind(this);
    this._handleTouchMove = this.handleTouchMove.bind(this);
    this._handleTouchEnd = this.handleTouchEnd.bind(this);

    this.viewerTarget.addEventListener('touchstart', this._handleTouchStart, {
      passive: false
    });
    this.viewerTarget.addEventListener('touchmove', this._handleTouchMove, {
      passive: false
    });
    this.viewerTarget.addEventListener('touchend', this._handleTouchEnd, {
      passive: true
    });
  }

  /**
   * Unbind touch event handlers
   */
  unbindTouchGestures() {
    if (!this.hasViewerTarget) {
      return;
    }

    this.viewerTarget.removeEventListener('touchstart', this._handleTouchStart);
    this.viewerTarget.removeEventListener('touchmove', this._handleTouchMove);
    this.viewerTarget.removeEventListener('touchend', this._handleTouchEnd);
  }

  /**
   * Handle touch start - detect pinch gesture initiation
   */
  handleTouchStart(event) {
    if (event.touches.length === 2) {
      // Pinch gesture starting
      event.preventDefault();
      this.isTouching = true;
      this.initialPinchDistance = this.getPinchDistance(event.touches);
      this.initialScale = this.scale;
    }
  }

  /**
   * Handle touch move - process pinch-to-zoom
   */
  handleTouchMove(event) {
    if (event.touches.length === 2 && this.isTouching) {
      event.preventDefault();

      const currentDistance = this.getPinchDistance(event.touches);
      const scaleFactor = currentDistance / this.initialPinchDistance;
      let newScale = this.initialScale * scaleFactor;

      // Clamp scale to min/max values
      newScale = Math.max(
        this.minScaleValue,
        Math.min(this.maxScaleValue, newScale)
      );

      if (Math.abs(newScale - this.scale) > 0.01) {
        this.scale = newScale;
        // Don't re-render on every move - wait for touch end
      }
    }
  }

  /**
   * Handle touch end - complete zoom gesture
   */
  handleTouchEnd(event) {
    if (this.isTouching && event.touches.length < 2) {
      this.isTouching = false;
      this.initialPinchDistance = null;

      // Re-render at new scale
      if (this.pdfDoc) {
        this.queueRenderPage(this.pageNum);
      }

      // Update zoom display and hide hint
      this.updateZoomDisplay();
      this.hidePinchHint();

      // Provide haptic feedback
      this.triggerHapticFeedback();
    }
  }

  /**
   * Calculate distance between two touch points
   */
  getPinchDistance(touches) {
    const dx = touches[0].clientX - touches[1].clientX;
    const dy = touches[0].clientY - touches[1].clientY;

    return Math.sqrt(dx * dx + dy * dy);
  }

  /**
   * Trigger haptic feedback on supported devices
   */
  triggerHapticFeedback() {
    if ('vibrate' in navigator) {
      navigator.vibrate(10);
    }
  }

  /**
   * Zoom in by 25%
   */
  zoomIn() {
    const newScale = Math.min(this.maxScaleValue, this.scale * 1.25);

    if (newScale !== this.scale) {
      this.scale = newScale;
      this.queueRenderPage(this.pageNum);
      this.updateZoomDisplay();
      this.triggerHapticFeedback();
    }
  }

  /**
   * Zoom out by 25%
   */
  zoomOut() {
    const newScale = Math.max(this.minScaleValue, this.scale / 1.25);

    if (newScale !== this.scale) {
      this.scale = newScale;
      this.queueRenderPage(this.pageNum);
      this.updateZoomDisplay();
      this.triggerHapticFeedback();
    }
  }

  /**
   * Reset zoom to default
   */
  resetZoom() {
    this.scale = 1.5;
    this.queueRenderPage(this.pageNum);
    this.updateZoomDisplay();
    this.triggerHapticFeedback();
  }

  /**
   * Get current zoom percentage
   */
  getZoomPercentage() {
    return Math.round((this.scale * 100) / 1.5);
  }

  /**
   * Update zoom display on mobile overlay
   */
  updateZoomDisplay() {
    if (this.hasZoomDisplayTarget) {
      this.zoomDisplayTarget.textContent = `${this.getZoomPercentage()}%`;
    }
  }

  /**
   * Update mobile page number display
   */
  updateMobilePageDisplay() {
    if (this.hasMobilePageNumberTarget) {
      this.mobilePageNumberTarget.textContent = this.pageNum;
    }
    if (this.hasMobilePageCountTarget && this.pdfDoc) {
      this.mobilePageCountTarget.textContent = this.pdfDoc.numPages;
    }
    if (this.hasMobilePrevButtonTarget) {
      this.mobilePrevButtonTarget.disabled = this.pageNum <= 1;
    }
    if (this.hasMobileNextButtonTarget && this.pdfDoc) {
      this.mobileNextButtonTarget.disabled =
        this.pageNum >= this.pdfDoc.numPages;
    }
  }

  /**
   * Hide the pinch-to-zoom hint after first zoom
   */
  hidePinchHint() {
    if (this.hasPinchHintTarget && !this._pinchHintHidden) {
      this._pinchHintHidden = true;
      this.pinchHintTarget.classList.add('opacity-0');
      setTimeout(() => {
        this.pinchHintTarget.classList.add('hidden');
      }, 500);
    }
  }

  handleHighlight(event) {
    const { fieldName } = event.detail;

    this.highlightField(fieldName);
  }

  handleClearHighlight() {
    this.highlightedFieldName = null;
    this.renderPage(this.pageNum);
  }

  xrayModeValueChanged() {
    if (this.hasXrayButtonTarget) {
      this.xrayButtonTarget.classList.toggle('btn-active', this.xrayModeValue);
      this.xrayButtonTarget.classList.toggle(
        'text-primary',
        this.xrayModeValue
      );
    }
    if (this.pdfDoc) {
      this.renderPage(this.pageNum);
    }
  }

  toggleXray() {
    this.xrayModeValue = !this.xrayModeValue;
    // The value changed callback should handle the rest
  }

  highlightField(fieldName) {
    const mapping = this.fieldMappingsValue[fieldName];

    if (!mapping) {
      return;
    }

    this.highlightedFieldName = fieldName;

    // Switch page if necessary
    if (mapping.page && mapping.page !== this.pageNum) {
      this.pageNum = mapping.page;
      this.renderPage(this.pageNum);
    } else {
      // Re-render current page to show highlight
      this.renderPage(this.pageNum);
    }
  }

  handleFormSaved(_event) {
    if (!this.autoRefreshValue) {
      return;
    }
    if (this.isLoading) {
      this.pendingRefresh = true;
      this.updateStatus(STATUS_TYPES.QUEUED);

      return;
    }
    this.triggerDebouncedRefresh();
  }

  triggerDebouncedRefresh() {
    this.updateStatus(STATUS_TYPES.UPDATING);
    this.showLoading();
    this.debouncedRefresh.call(this.debounceDelayValue);
  }

  refresh() {
    this.debouncedRefresh.cancel();
    this.performRefresh();
  }

  performRefresh() {
    this.loadPreview();
  }

  async loadPreview() {
    if (!this.hasCanvasTarget) {
      return;
    }

    this.isLoading = true;
    this.showLoading();
    this.hideError();
    this.updateStatus(STATUS_TYPES.LOADING);
    this.animateRefreshIcon(true);

    const url = new URL(this.urlValue, window.location.origin);

    url.searchParams.set('t', Date.now());

    try {
      const pdfjsLib = window.pdfjsLib;
      const loadingTask = pdfjsLib.getDocument(url.toString());

      this.pdfDoc = await loadingTask.promise;

      this.pageCountTarget.textContent = this.pdfDoc.numPages;
      this.updateNavButtons();
      this.renderPage(this.pageNum);

      this.isLoading = false;
      this.updateStatus(STATUS_TYPES.IDLE);
      this.animateRefreshIcon(false);
      this.hideLoading();

      if (this.pendingRefresh) {
        this.pendingRefresh = false;
        setTimeout(() => this.triggerDebouncedRefresh(), 100);
      }
    } catch (error) {
      console.error('PDF loading error:', error);
      this.handleError();
    }
  }

  async renderPage(num) {
    if (!this.pdfDoc) {
      return;
    }
    this.pageRendering = true;
    const page = await this.pdfDoc.getPage(num);

    const viewport = page.getViewport({ scale: this.scale });

    this.canvasTarget.height = viewport.height;
    this.canvasTarget.width = viewport.width;

    const renderContext = {
      canvasContext: this.ctx,
      viewport
    };

    const renderTask = page.render(renderContext);

    try {
      await renderTask.promise;
      this.pageRendering = false;

      // Draw highlights after page render completes
      this.drawHighlights(page, viewport);

      if (this.pageNumPending !== null) {
        this.renderPage(this.pageNumPending);
        this.pageNumPending = null;
      }
    } catch (e) {
      console.error('Render error:', e);
    }

    this.pageNumberTarget.textContent = num;
    this.updateNavButtons();
  }

  drawHighlights(page, viewport) {
    if (this.xrayModeValue) {
      // Draw all fields on this page
      Object.entries(this.fieldMappingsValue).forEach(([name, mapping]) => {
        if (mapping.page === this.pageNum) {
          this.drawFieldHighlight(
            mapping.rect,
            viewport,
            name === this.highlightedFieldName
          );
        }
      });
    } else if (this.highlightedFieldName) {
      // Draw only the specifically highlighted field
      const mapping = this.fieldMappingsValue[this.highlightedFieldName];

      if (mapping && mapping.page === this.pageNum) {
        this.drawFieldHighlight(mapping.rect, viewport, true);
      }
    }
  }

  drawFieldHighlight(rect, viewport, isActive) {
    // rect is [x1, y1, x2, y2] in PDF points (origin bottom-left)
    // We need to convert to canvas pixels (origin top-left)

    // pdfjs viewport.convertToViewportRectangle handles this
    const [x1, y1, x2, y2] = viewport.convertToViewportRectangle(rect);

    const x = Math.min(x1, x2);
    const y = Math.min(y1, y2);
    const width = Math.abs(x2 - x1);
    const height = Math.abs(y2 - y1);

    this.ctx.save();

    if (isActive) {
      this.ctx.fillStyle = 'rgba(37, 99, 235, 0.3)'; // Primary with opacity
      this.ctx.strokeStyle = 'rgba(37, 99, 235, 0.8)';
      this.ctx.lineWidth = 2;
    } else {
      this.ctx.fillStyle = 'rgba(245, 158, 11, 0.1)'; // Amber/Accent with low opacity
      this.ctx.strokeStyle = 'rgba(245, 158, 11, 0.4)';
      this.ctx.lineWidth = 1;
    }

    this.ctx.fillRect(x, y, width, height);
    this.ctx.strokeRect(x, y, width, height);

    this.ctx.restore();

    if (isActive) {
      // Scroll into view if needed
      this.viewerTarget.scrollTo({
        top: y - 50,
        behavior: 'smooth'
      });
    }
  }

  updateNavButtons() {
    if (!this.pdfDoc) {
      return;
    }
    this.prevButtonTarget.disabled = this.pageNum <= 1;
    this.nextButtonTarget.disabled = this.pageNum >= this.pdfDoc.numPages;
    // Update mobile overlay
    this.updateMobilePageDisplay();
  }

  previousPage() {
    if (this.pageNum <= 1) {
      return;
    }
    this.pageNum--;
    this.queueRenderPage(this.pageNum);
  }

  nextPage() {
    if (!this.pdfDoc || this.pageNum >= this.pdfDoc.numPages) {
      return;
    }
    this.pageNum++;
    this.queueRenderPage(this.pageNum);
  }

  queueRenderPage(num) {
    if (this.pageRendering) {
      this.pageNumPending = num;
    } else {
      this.renderPage(num);
    }
  }

  handleError() {
    this.isLoading = false;
    this.pendingRefresh = false;
    this.hideLoading();
    this.showError();
    this.updateStatus(STATUS_TYPES.ERROR);
    this.animateRefreshIcon(false);
  }

  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove('hidden');
    }
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add('hidden');
    }
  }

  showError() {
    if (this.hasErrorTarget) {
      this.errorTarget.classList.remove('hidden');
    }
  }

  hideError() {
    if (this.hasErrorTarget) {
      this.errorTarget.classList.add('hidden');
    }
  }

  updateStatus(status) {
    if (!this.hasStatusTextTarget) {
      return;
    }
    const message = this.constructor.STATUS_MESSAGES[status] || status;

    this.statusTextTarget.textContent = message;
    // Use Tailwind color classes with WCAG AA compliant contrast ratios
    // text-red-600 (#dc2626) has 4.63:1 contrast on white (vs text-error which is ~2.83:1)
    // Also remove text-base-content/50 which has poor contrast (3.4:1)
    this.statusTextTarget.classList.remove(
      'text-success',
      'text-red-600',
      'text-error',
      'text-warning',
      'text-amber-600',
      'text-base-content/50'
    );
    if (status === STATUS_TYPES.IDLE) {
      this.statusTextTarget.classList.add('text-success');
    } else if (status === STATUS_TYPES.ERROR) {
      this.statusTextTarget.classList.add('text-red-600');
    } else if (status === STATUS_TYPES.QUEUED) {
      this.statusTextTarget.classList.add('text-amber-600');
    }
  }

  animateRefreshIcon(spinning) {
    if (this.hasRefreshIconTarget) {
      this.refreshIconTarget.classList.toggle('animate-spin', spinning);
    }
  }

  toggleAutoRefresh(event) {
    this.autoRefreshValue = event.target.checked;
    this.updateStatus(this.autoRefreshValue ? STATUS_TYPES.IDLE : 'paused');
  }
}
