import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['input', 'button', 'icon', 'pulse'];

  connect() {
    this.hasSupport =
      'webkitSpeechRecognition' in window || 'SpeechRecognition' in window;

    if (!this.hasSupport) {
      this.buttonTarget.classList.add('hidden');

      return;
    }

    const SpeechRecognition =
      window.SpeechRecognition || window.webkitSpeechRecognition;

    this.recognition = new SpeechRecognition();
    this.recognition.continuous = false;
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
      let interimTranscript = '';

      for (let i = event.resultIndex; i < event.results.length; ++i) {
        if (event.results[i].isFinal) {
          finalTranscript += event.results[i][0].transcript;
        } else {
          interimTranscript += event.results[i][0].transcript;
        }
      }

      if (finalTranscript) {
        this.insertText(finalTranscript);
      }
    };
  }

  toggle(event) {
    event.preventDefault();
    if (this.isListening) {
      this.recognition.stop();
    } else {
      this.recognition.start();
    }
  }

  insertText(text) {
    const input = this.inputTarget;
    const startPos = input.selectionStart;
    const endPos = input.selectionEnd;
    const currentValue = input.value;

    // Auto-capitalize first letter if at start or after punctuation
    if (startPos === 0 || '.!?\n'.includes(currentValue[startPos - 1])) {
      text = text.charAt(0).toUpperCase() + text.slice(1);
    }

    // Insert text at cursor
    input.value =
      currentValue.substring(0, startPos) +
      (currentValue[startPos - 1] === ' ' ? '' : ' ') +
      text +
      currentValue.substring(endPos);

    // Dispatch input event for other controllers (like validation/autosave)
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.focus();
  }

  updateUI() {
    if (this.isListening) {
      this.buttonTarget.classList.add('text-error', 'animate-pulse');
      this.iconTarget.innerHTML = `
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-5 h-5">
          <path d="M8.25 4.5a3.75 3.75 0 117.5 0v8.25a3.75 3.75 0 11-7.5 0V4.5z" />
          <path d="M6 10.5a.75.75 0 01.75.75v1.5a5.25 5.25 0 1010.5 0v-1.5a.75.75 0 011.5 0v1.5a6.751 6.751 0 01-6 6.709v2.291h3a.75.75 0 010 1.5h-7.5a.75.75 0 010-1.5h3v-2.291a6.751 6.751 0 01-6-6.709v-1.5A.75.75 0 016 10.5z" />
        </svg>
      `;
    } else {
      this.buttonTarget.classList.remove('text-error', 'animate-pulse');
      this.iconTarget.innerHTML = `
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 18.75a6 6 0 006-6v-1.5m-6 7.5a6 6 0 01-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 01-3-3V4.5a3 3 0 116 0v8.25a3 3 0 01-3 3z" />
        </svg>
      `;
    }
  }
}
