import { Controller } from '@hotwired/stimulus';

/**
 * Dictation Controller
 * Uses Web Speech API to provide voice-to-text for textareas
 */
export default class extends Controller {
  static targets = ['input', 'button', 'icon'];

  connect() {
    this.isListening = false;
    this.setupRecognition();
  }

  setupRecognition() {
    const SpeechRecognition =
      window.SpeechRecognition || window.webkitSpeechRecognition;

    if (!SpeechRecognition) {
      this.buttonTarget.classList.add('hidden');
      console.warn('Speech Recognition not supported in this browser');

      return;
    }

    this.recognition = new SpeechRecognition();
    this.recognition.continuous = true;
    this.recognition.interimResults = true;
    this.recognition.lang = 'en-US';

    this.recognition.onstart = () => {
      this.isListening = true;
      this.updateUI();
    };

    this.recognition.onend = () => {
      this.isListening = false;
      this.updateUI();
    };

    this.recognition.onresult = event => {
      let finalTranscript = '';

      for (let i = event.resultIndex; i < event.results.length; ++i) {
        if (event.results[i].isFinal) {
          finalTranscript += event.results[i][0].transcript;
        }
      }

      if (finalTranscript) {
        this.appendTranscript(finalTranscript);
      }
    };

    this.recognition.onerror = event => {
      console.error('Speech recognition error:', event.error);
      this.stop();
    };
  }

  toggle() {
    if (this.isListening) {
      this.stop();
    } else {
      this.start();
    }
  }

  start() {
    if (!this.recognition) {
      return;
    }

    try {
      this.recognition.start();
    } catch (e) {
      console.error('Failed to start recognition:', e);
    }
  }

  stop() {
    if (!this.recognition) {
      return;
    }
    this.recognition.stop();
  }

  appendTranscript(text) {
    const input = this.inputTarget;
    const currentValue = input.value.trim();
    const newValue = currentValue
      ? `${currentValue} ${text.trim()}`
      : text.trim();

    input.value = newValue;

    // Trigger input event for auto-save/validation
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.dispatchEvent(new Event('change', { bubbles: true }));
  }

  updateUI() {
    if (this.isListening) {
      this.buttonTarget.classList.add('text-primary', 'animate-pulse');
      this.buttonTarget.setAttribute('aria-label', 'Stop dictation');
    } else {
      this.buttonTarget.classList.remove('text-primary', 'animate-pulse');
      this.buttonTarget.setAttribute('aria-label', 'Start dictation');
    }
  }
}
