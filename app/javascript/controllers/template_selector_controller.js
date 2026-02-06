import { Controller } from '@hotwired/stimulus';
import { showToast } from '../utils/toast';

/**
 * Template Selector Controller
 * Handles quick fill template selection and application
 */
export default class extends Controller {
  static targets = [
    'collapsed',
    'expanded',
    'applied',
    'modal',
    'modalTitle',
    'modalContent'
  ];

  static values = {
    formCode: String,
    applyUrl: String
  };

  connect() {
    this.selectedTemplateId = null;
    this.customizations = {};
  }

  /**
   * Expand the template selector to show available templates
   */
  expand() {
    this.collapsedTarget.classList.add('hidden');
    this.expandedTarget.classList.remove('hidden');
  }

  /**
   * Collapse the template selector back to the button
   */
  collapse() {
    this.expandedTarget.classList.add('hidden');
    this.collapsedTarget.classList.remove('hidden');
  }

  /**
   * Select a template - either apply directly or show customization modal
   */
  async select(event) {
    const templateId = event.currentTarget.dataset.templateId;

    this.selectedTemplateId = templateId;

    // Fetch template details to check for customization questions
    try {
      const response = await fetch(`/templates/${templateId}.json`);

      if (!response.ok) {
        throw new Error('Failed to fetch template');
      }

      const template = await response.json();
      const questions = template.scenario?.customization || [];

      if (questions.length > 0) {
        // Show customization modal
        this.showCustomizationModal(template, questions);
      } else {
        // Apply template directly
        this.applyTemplate(templateId, {});
      }
    } catch (error) {
      console.error('Error fetching template:', error);
      // Apply template without customization as fallback
      this.applyTemplate(templateId, {});
    }
  }

  /**
   * Show the customization modal with questions
   */
  showCustomizationModal(template, questions) {
    this.modalTitleTarget.textContent = `Customize: ${template.scenario.name}`;
    this.modalContentTarget.innerHTML = this.buildQuestionsHtml(questions);
    this.modalTarget.showModal();
  }

  /**
   * Build HTML for customization questions
   */
  buildQuestionsHtml(questions) {
    return questions
      .map(question => {
        const optionsHtml = question.options
          .map(
            option => `
        <label class="label cursor-pointer justify-start gap-3 p-3 rounded-lg hover:bg-base-200">
          <input type="radio"
                 name="${question.id}"
                 value="${option.value}"
                 class="radio radio-primary"
                 data-action="change->template-selector#updateCustomization">
          <div>
            <span class="label-text font-medium">${option.label}</span>
            ${option.description ? `<p class="text-xs text-base-content/70">${option.description}</p>` : ''}
          </div>
        </label>
      `
          )
          .join('');

        return `
        <div class="mb-6">
          <h4 class="font-semibold text-base-content mb-3">${question.question}</h4>
          <div class="space-y-2">
            ${optionsHtml}
          </div>
        </div>
      `;
      })
      .join('');
  }

  /**
   * Update customization value when user selects an option
   */
  updateCustomization(event) {
    const name = event.target.name;
    const value = event.target.value;

    this.customizations[name] = value;
  }

  /**
   * Close the customization modal
   */
  closeModal() {
    this.modalTarget.close();
    this.customizations = {};
  }

  /**
   * Apply the selected template with customizations
   */
  async applyTemplate(templateId = null, customizations = null) {
    const id = templateId || this.selectedTemplateId;
    const customs =
      customizations !== null ? customizations : this.customizations;

    try {
      const formData = new FormData();

      formData.append('template_id', id);

      // Add customizations
      Object.entries(customs).forEach(([key, value]) => {
        formData.append(`customizations[${key}]`, value);
      });

      // Get CSRF token
      const csrfToken = document.querySelector(
        'meta[name="csrf-token"]'
      )?.content;

      const response = await fetch(this.applyUrlValue, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': csrfToken,
          'Accept': 'text/html, application/json'
        },
        body: formData
      });

      if (response.ok) {
        // Close modal if open
        if (this.hasModalTarget) {
          this.modalTarget.close();
        }
        // Reload page to show applied template
        window.location.reload();
      } else {
        const error = await response.json();

        showToast(
          `Error applying template: ${error.errors?.join(', ') || 'Unknown error'}`,
          'error'
        );
      }
    } catch (error) {
      console.error('Error applying template:', error);
      showToast('Failed to apply template. Please try again.', 'error');
    }
  }

  /**
   * Clear the applied template
   */
  async clear() {
    const clearUrl = this.applyUrlValue.replace(
      'apply_template',
      'clear_template'
    );
    const csrfToken = document.querySelector(
      'meta[name="csrf-token"]'
    )?.content;

    try {
      const response = await fetch(clearUrl, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': csrfToken,
          'Accept': 'application/json'
        }
      });

      if (response.ok) {
        window.location.reload();
      } else {
        showToast('Failed to clear template', 'error');
      }
    } catch (error) {
      console.error('Error clearing template:', error);
      showToast('Failed to clear template. Please try again.', 'error');
    }
  }
}
