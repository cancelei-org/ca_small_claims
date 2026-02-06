import { Controller } from '@hotwired/stimulus';

/**
 * Signature Pad Controller
 *
 * Provides a canvas-based signature capture interface optimized for mobile devices.
 *
 * Features:
 * - Touch and mouse support
 * - Smooth line drawing with pressure sensitivity
 * - Clear and Done buttons
 * - Captures signature as base64 PNG
 * - Responsive sizing (full-width on mobile)
 * - Landscape mode hint for better signing experience
 * - Haptic feedback on signature complete
 * - Accessibility fallback with typed signature option
 * - Minimum stroke validation
 */
export default class extends Controller {
  static targets = [
    'canvas',
    'preview',
    'previewImage',
    'input',
    'timestamp',
    'signatureMode',
    'drawMode',
    'typeMode',
    'typedInput',
    'clearButton',
    'doneButton',
    'resignButton',
    'landscapeHint'
  ];

  static values = {
    minStrokeLength: { type: Number, default: 50 },
    lineWidth: { type: Number, default: 2.5 },
    lineColor: { type: String, default: '#1a1a2e' },
    required: { type: Boolean, default: false }
  };

  connect() {
    this.isDrawing = false;
    this.lastPoint = null;
    this.strokeLength = 0;
    this.hasSignature = false;
    this.points = [];

    this.initializeCanvas();
    this.bindEvents();
    this.checkOrientation();
    this.restoreSignature();
  }

  disconnect() {
    this.unbindEvents();
    window.removeEventListener('resize', this.handleResize);
    window.removeEventListener('orientationchange', this.handleOrientation);
  }

  initializeCanvas() {
    if (!this.hasCanvasTarget) {
      return;
    }

    const canvas = this.canvasTarget;

    this.ctx = canvas.getContext('2d', { willReadFrequently: true });

    // Set canvas size based on container
    this.resizeCanvas();

    // Configure drawing context
    this.ctx.strokeStyle = this.lineColorValue;
    this.ctx.lineWidth = this.lineWidthValue;
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';
  }

  resizeCanvas() {
    if (!this.hasCanvasTarget) {
      return;
    }

    const canvas = this.canvasTarget;
    const container = canvas.parentElement;
    const rect = container.getBoundingClientRect();

    // Store existing signature data
    const imageData = this.hasSignature ? canvas.toDataURL() : null;

    // Set display size
    const dpr = window.devicePixelRatio || 1;

    canvas.width = rect.width * dpr;
    canvas.height = rect.height * dpr;

    // Scale context for retina displays
    this.ctx.scale(dpr, dpr);

    // Reset drawing context after resize
    this.ctx.strokeStyle = this.lineColorValue;
    this.ctx.lineWidth = this.lineWidthValue;
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';

    // Restore signature if it existed
    if (imageData && this.hasSignature) {
      const img = new Image();

      img.onload = () => {
        this.ctx.drawImage(img, 0, 0, rect.width, rect.height);
      };
      img.src = imageData;
    }
  }

  bindEvents() {
    if (!this.hasCanvasTarget) {
      return;
    }

    const canvas = this.canvasTarget;

    // Touch events
    canvas.addEventListener('touchstart', this.handleTouchStart.bind(this), {
      passive: false
    });
    canvas.addEventListener('touchmove', this.handleTouchMove.bind(this), {
      passive: false
    });
    canvas.addEventListener('touchend', this.handleTouchEnd.bind(this));
    canvas.addEventListener('touchcancel', this.handleTouchEnd.bind(this));

    // Mouse events
    canvas.addEventListener('mousedown', this.handleMouseDown.bind(this));
    canvas.addEventListener('mousemove', this.handleMouseMove.bind(this));
    canvas.addEventListener('mouseup', this.handleMouseUp.bind(this));
    canvas.addEventListener('mouseleave', this.handleMouseUp.bind(this));

    // Resize handler
    this.handleResize = this.debounce(() => this.resizeCanvas(), 100);
    window.addEventListener('resize', this.handleResize);

    // Orientation change handler
    this.handleOrientation = () => this.checkOrientation();
    window.addEventListener('orientationchange', this.handleOrientation);
  }

  unbindEvents() {
    if (!this.hasCanvasTarget) {
      return;
    }

    const canvas = this.canvasTarget;

    canvas.removeEventListener('touchstart', this.handleTouchStart);
    canvas.removeEventListener('touchmove', this.handleTouchMove);
    canvas.removeEventListener('touchend', this.handleTouchEnd);
    canvas.removeEventListener('touchcancel', this.handleTouchEnd);
    canvas.removeEventListener('mousedown', this.handleMouseDown);
    canvas.removeEventListener('mousemove', this.handleMouseMove);
    canvas.removeEventListener('mouseup', this.handleMouseUp);
    canvas.removeEventListener('mouseleave', this.handleMouseUp);
  }

  // Touch event handlers
  handleTouchStart(event) {
    event.preventDefault();
    const [touch] = event.touches;
    const point = this.getTouchPoint(touch);

    this.startDrawing(point, this.getPressure(touch));
  }

  handleTouchMove(event) {
    event.preventDefault();
    if (!this.isDrawing) {
      return;
    }

    const [touch] = event.touches;
    const point = this.getTouchPoint(touch);

    this.continueDrawing(point, this.getPressure(touch));
  }

  handleTouchEnd() {
    this.stopDrawing();
  }

  // Mouse event handlers
  handleMouseDown(event) {
    const point = this.getMousePoint(event);

    this.startDrawing(point, 0.5);
  }

  handleMouseMove(event) {
    if (!this.isDrawing) {
      return;
    }
    const point = this.getMousePoint(event);

    this.continueDrawing(point, 0.5);
  }

  handleMouseUp() {
    this.stopDrawing();
  }

  // Drawing methods
  startDrawing(point, pressure) {
    this.isDrawing = true;
    this.lastPoint = point;
    this.points = [{ ...point, pressure }];

    this.ctx.beginPath();
    this.ctx.moveTo(point.x, point.y);

    // Hide landscape hint when user starts drawing
    if (this.hasLandscapeHintTarget) {
      this.landscapeHintTarget.classList.add('hidden');
    }
  }

  continueDrawing(point, pressure) {
    if (!this.isDrawing || !this.lastPoint) {
      return;
    }

    // Calculate stroke length
    const dx = point.x - this.lastPoint.x;
    const dy = point.y - this.lastPoint.y;

    this.strokeLength += Math.sqrt(dx * dx + dy * dy);

    // Adjust line width based on pressure (if available)
    const adjustedWidth = this.lineWidthValue * (0.5 + pressure);

    this.ctx.lineWidth = adjustedWidth;

    // Draw smooth curve using quadratic bezier
    const midPoint = {
      x: (this.lastPoint.x + point.x) / 2,
      y: (this.lastPoint.y + point.y) / 2
    };

    this.ctx.quadraticCurveTo(
      this.lastPoint.x,
      this.lastPoint.y,
      midPoint.x,
      midPoint.y
    );
    this.ctx.stroke();
    this.ctx.beginPath();
    this.ctx.moveTo(midPoint.x, midPoint.y);

    this.lastPoint = point;
    this.points.push({ ...point, pressure });
    this.hasSignature = true;

    // Enable clear button
    if (this.hasClearButtonTarget) {
      this.clearButtonTarget.disabled = false;
    }
  }

  stopDrawing() {
    if (!this.isDrawing) {
      return;
    }

    this.isDrawing = false;
    this.ctx.stroke();
    this.lastPoint = null;

    // Check if signature meets minimum stroke requirement
    this.updateValidation();
  }

  // Coordinate helpers
  getTouchPoint(touch) {
    const rect = this.canvasTarget.getBoundingClientRect();

    return {
      x: touch.clientX - rect.left,
      y: touch.clientY - rect.top
    };
  }

  getMousePoint(event) {
    const rect = this.canvasTarget.getBoundingClientRect();

    return {
      x: event.clientX - rect.left,
      y: event.clientY - rect.top
    };
  }

  getPressure(touch) {
    // Use pressure if available (Force Touch / 3D Touch)
    if (touch.force !== undefined && touch.force > 0) {
      return touch.force;
    }

    // Fallback to default pressure
    return 0.5;
  }

  // Actions
  clear() {
    if (!this.hasCanvasTarget) {
      return;
    }

    const canvas = this.canvasTarget;

    this.ctx.clearRect(0, 0, canvas.width, canvas.height);

    this.strokeLength = 0;
    this.hasSignature = false;
    this.points = [];

    // Reset input value
    if (this.hasInputTarget) {
      this.inputTarget.value = '';
    }

    // Disable clear button
    if (this.hasClearButtonTarget) {
      this.clearButtonTarget.disabled = true;
    }

    // Update validation
    this.updateValidation();

    // Dispatch event
    this.dispatch('cleared');
  }

  done() {
    if (!this.validateSignature()) {
      this.showError('Please provide a longer signature');

      return;
    }

    // Capture signature as base64 PNG
    const signatureData = this.captureSignature();

    // Update hidden input
    if (this.hasInputTarget) {
      this.inputTarget.value = signatureData;
    }

    // Update preview
    this.showPreview(signatureData);

    // Set timestamp
    this.updateTimestamp();

    // Haptic feedback
    this.triggerHapticFeedback();

    // Dispatch completion event
    this.dispatch('completed', {
      detail: {
        signature: signatureData,
        timestamp: new Date().toISOString()
      }
    });
  }

  resign() {
    // Hide preview, show canvas
    if (this.hasPreviewTarget) {
      this.previewTarget.classList.add('hidden');
    }
    if (this.hasSignatureModeTarget) {
      this.signatureModeTarget.classList.remove('hidden');
    }

    // Clear canvas
    this.clear();

    // Dispatch event
    this.dispatch('resign');
  }

  // Mode switching
  switchToDrawMode() {
    if (this.hasDrawModeTarget) {
      this.drawModeTarget.classList.remove('hidden');
    }
    if (this.hasTypeModeTarget) {
      this.typeModeTarget.classList.add('hidden');
    }
  }

  switchToTypeMode() {
    if (this.hasDrawModeTarget) {
      this.drawModeTarget.classList.add('hidden');
    }
    if (this.hasTypeModeTarget) {
      this.typeModeTarget.classList.remove('hidden');
    }
  }

  // Typed signature handler
  handleTypedSignature() {
    if (!this.hasTypedInputTarget) {
      return;
    }

    const typedName = this.typedInputTarget.value.trim();

    if (!typedName) {
      this.showError('Please type your name');

      return;
    }

    // Generate signature from typed text
    const signatureData = this.generateTypedSignature(typedName);

    // Update hidden input
    if (this.hasInputTarget) {
      this.inputTarget.value = signatureData;
    }

    // Show preview
    this.showPreview(signatureData);

    // Set timestamp
    this.updateTimestamp();

    // Dispatch completion event
    this.dispatch('completed', {
      detail: {
        signature: signatureData,
        typed: true,
        name: typedName,
        timestamp: new Date().toISOString()
      }
    });
  }

  generateTypedSignature(text) {
    // Create temporary canvas for typed signature
    const canvas = document.createElement('canvas');

    canvas.width = 400;
    canvas.height = 100;
    const ctx = canvas.getContext('2d');

    // Clear and set background
    ctx.fillStyle = 'transparent';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Draw signature-style text
    ctx.fillStyle = this.lineColorValue;
    ctx.font = 'italic 32px "Brush Script MT", cursive, serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(text, canvas.width / 2, canvas.height / 2);

    return canvas.toDataURL('image/png');
  }

  // Validation
  validateSignature() {
    return this.strokeLength >= this.minStrokeLengthValue;
  }

  updateValidation() {
    const isValid = this.validateSignature();
    const input = this.inputTarget;

    if (this.requiredValue && !isValid && !input.value) {
      input.setCustomValidity('Please provide a signature');
    } else {
      input.setCustomValidity('');
    }

    // Update done button state
    if (this.hasDoneButtonTarget) {
      this.doneButtonTarget.disabled = !this.hasSignature;
    }

    // Dispatch validation event
    this.dispatch('validation', { detail: { valid: isValid } });
  }

  showError(message) {
    // Find error container
    const errorContainer = this.element.querySelector('.field-error');

    if (errorContainer) {
      errorContainer.textContent = message;
      errorContainer.classList.remove('hidden');
      errorContainer.setAttribute('role', 'alert');
    }
  }

  hideError() {
    const errorContainer = this.element.querySelector('.field-error');

    if (errorContainer) {
      errorContainer.textContent = '';
      errorContainer.classList.add('hidden');
    }
  }

  // Capture and preview
  captureSignature() {
    if (!this.hasCanvasTarget) {
      return '';
    }

    // Create a trimmed version of the signature
    return this.trimCanvas(this.canvasTarget);
  }

  trimCanvas(canvas) {
    // Get canvas data and trim whitespace
    const ctx = canvas.getContext('2d');
    const dpr = window.devicePixelRatio || 1;
    const width = canvas.width;
    const height = canvas.height;

    const imageData = ctx.getImageData(0, 0, width, height);
    const data = imageData.data;

    let minX = width;
    let minY = height;
    let maxX = 0;
    let maxY = 0;
    let hasContent = false;

    // Find bounds of actual content
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const alpha = data[(y * width + x) * 4 + 3];

        if (alpha > 0) {
          hasContent = true;
          minX = Math.min(minX, x);
          minY = Math.min(minY, y);
          maxX = Math.max(maxX, x);
          maxY = Math.max(maxY, y);
        }
      }
    }

    if (!hasContent) {
      return '';
    }

    // Add padding
    const padding = 10 * dpr;

    minX = Math.max(0, minX - padding);
    minY = Math.max(0, minY - padding);
    maxX = Math.min(width, maxX + padding);
    maxY = Math.min(height, maxY + padding);

    // Create trimmed canvas
    const trimmedWidth = maxX - minX;
    const trimmedHeight = maxY - minY;

    const trimmedCanvas = document.createElement('canvas');

    trimmedCanvas.width = trimmedWidth;
    trimmedCanvas.height = trimmedHeight;

    const trimmedCtx = trimmedCanvas.getContext('2d');

    trimmedCtx.drawImage(
      canvas,
      minX,
      minY,
      trimmedWidth,
      trimmedHeight,
      0,
      0,
      trimmedWidth,
      trimmedHeight
    );

    return trimmedCanvas.toDataURL('image/png');
  }

  showPreview(signatureData) {
    if (this.hasPreviewTarget && this.hasPreviewImageTarget) {
      this.previewImageTarget.src = signatureData;
      this.previewTarget.classList.remove('hidden');
    }

    if (this.hasSignatureModeTarget) {
      this.signatureModeTarget.classList.add('hidden');
    }
  }

  updateTimestamp() {
    if (!this.hasTimestampTarget) {
      return;
    }

    const now = new Date();
    const options = {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true
    };

    const formattedDate = now.toLocaleDateString('en-US', options);

    this.timestampTarget.textContent = `Signed on ${formattedDate}`;
  }

  // Orientation handling
  checkOrientation() {
    if (!this.hasLandscapeHintTarget) {
      return;
    }

    const isPortrait = window.innerHeight > window.innerWidth;
    const isMobile = window.innerWidth < 768;

    if (isPortrait && isMobile && !this.hasSignature) {
      this.landscapeHintTarget.classList.remove('hidden');
    } else {
      this.landscapeHintTarget.classList.add('hidden');
    }
  }

  // Restore signature from hidden input
  restoreSignature() {
    if (!this.hasInputTarget || !this.inputTarget.value) {
      return;
    }

    const signatureData = this.inputTarget.value;

    if (signatureData && signatureData.startsWith('data:image')) {
      this.showPreview(signatureData);
      this.hasSignature = true;

      // Try to parse timestamp from data if available
      this.updateTimestamp();
    }
  }

  // Haptic feedback
  triggerHapticFeedback() {
    if ('vibrate' in navigator) {
      navigator.vibrate(50);
    }
  }

  // Utility methods
  debounce(func, wait) {
    let timeout = null;

    return (...args) => {
      clearTimeout(timeout);
      timeout = setTimeout(() => func.apply(this, args), wait);
    };
  }
}
