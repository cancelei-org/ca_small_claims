import { Application } from '@hotwired/stimulus';
import DictationController from '../../../app/javascript/controllers/dictation_controller';

describe('DictationController', () => {
  let application;
  let element;

  beforeEach(() => {
    // Mock SpeechRecognition
    window.SpeechRecognition = jest.fn().mockImplementation(() => ({
      start: jest.fn(),
      stop: jest.fn(),
      addEventListener: jest.fn(),
      removeEventListener: jest.fn(),
    }));

    document.body.innerHTML = `
      <div data-controller="dictation">
        <textarea data-dictation-target="input"></textarea>
        <button data-dictation-target="button" data-action="click->dictation#toggle">
          <span data-dictation-target="icon">Icon</span>
        </button>
      </div>
    `;

    application = Application.start();
    application.register('dictation', DictationController);
    element = document.querySelector('[data-controller="dictation"]');
  });

  it('connects', () => {
    expect(element).toBeTruthy();
    expect(window.SpeechRecognition).toHaveBeenCalled();
  });

  it('toggles dictation on button click', () => {
    const button = document.querySelector('[data-dictation-target="button"]');
    const controller = application.getControllerForElementAndIdentifier(element, 'dictation');
    
    // Simulate start
    controller.isListening = false;
    button.click();
    expect(controller.recognition.start).toHaveBeenCalled();

    // Simulate stop
    controller.isListening = true;
    button.click();
    expect(controller.recognition.stop).toHaveBeenCalled();
  });

  it('updates UI when listening starts', () => {
    const controller = application.getControllerForElementAndIdentifier(element, 'dictation');
    const button = document.querySelector('[data-dictation-target="button"]');
    
    // Manually trigger onstart handler since we mocked the object
    controller.recognition.onstart();
    
    expect(button.classList.contains('animate-pulse')).toBe(true);
    expect(button.classList.contains('text-error')).toBe(true);
  });

  it('updates UI when listening ends', () => {
    const controller = application.getControllerForElementAndIdentifier(element, 'dictation');
    const button = document.querySelector('[data-dictation-target="button"]');
    
    // Set listening state
    controller.isListening = true;
    button.classList.add('animate-pulse');
    
    // Trigger onend
    controller.recognition.onend();
    
    expect(button.classList.contains('animate-pulse')).toBe(false);
  });
});
