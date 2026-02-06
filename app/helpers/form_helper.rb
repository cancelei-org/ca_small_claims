# frozen_string_literal: true

module FormHelper
  include FieldAccessibilityHelper
  include InputFieldHelper

  # Wraps form fields with consistent label, required indicator, help text, and ARIA support
  # Usage:
  #   <%= field_wrapper(field) do %>
  #     <%= form.text_field field.name, **field_aria_attributes(field) %>
  #   <% end %>
  #
  # Options:
  #   label_inline: false - set true for checkbox-style inline labels
  #   extra_classes: "" - additional classes for the outer div
  #   show_tooltip: true - show tooltip icon for help text (default: true)
  def field_wrapper(field, options = {}, &block)
    wrapper_options = extract_wrapper_options(options)
    metadata = extract_field_metadata(wrapper_options[:submission], field)

    content_tag(:div,
                class: build_wrapper_class(wrapper_options[:extra_classes]),
                data: build_wrapper_data_attributes(field, metadata, wrapper_options[:submission])) do
      build_field_wrapper_parts(field, wrapper_options, metadata, &block)
    end
  end

  def extract_wrapper_options(options)
    {
      label_inline: options.fetch(:label_inline, false),
      extra_classes: options.fetch(:extra_classes, ""),
      show_tooltip: options.fetch(:show_tooltip, true),
      prefix: options[:prefix],
      submission: options[:submission]
    }
  end

  def extract_field_metadata(submission, field)
    metadata = submission&.field_metadata(field.name) || {}
    metadata.merge("is_autofilled" => metadata["source"].present?)
  end

  def build_wrapper_class(extra_classes)
    "form-control w-full mb-4 #{extra_classes}".strip
  end

  def build_wrapper_data_attributes(field, metadata, submission)
    {
      field_name: field.name,
      controller: metadata["is_autofilled"] ? "autofill-indicator" : nil,
      autofill_indicator_source_value: metadata["source"],
      autofill_indicator_original_value_value: submission&.field_value(field.name),
      autofill_indicator_field_name_value: field.name
    }
  end

  def build_field_wrapper_parts(field, options, metadata, &block)
    parts = []
    parts << build_field_label_section(field, options) unless options[:label_inline]
    parts << autofill_badge(metadata) if metadata["is_autofilled"]
    parts << capture(&block) if block_given?
    parts << field_help_hint(field)
    parts << build_field_help_text_section(field, options)
    parts << stuck_get_help_button(field)
    parts << field_error_container(field, prefix: options[:prefix])
    safe_join(parts)
  end

  def build_field_label_section(field, options)
    content_tag(:div, class: "flex items-center justify-between") do
      label_parts = [ field_label(field, show_tooltip: options[:show_tooltip], prefix: options[:prefix]) ]

      if field.shared_field_key.present? && user_signed_in?
        trigger = autofill_trigger(field)
        label_parts << trigger if trigger
      end

      safe_join(label_parts)
    end
  end

  def build_field_help_text_section(field, options)
    return unless field.help_text.present? && !options[:show_tooltip]

    field_help_text(field.help_text, field_help_id(field, prefix: options[:prefix]))
  end

  # Renders an autofill indicator badge
  def autofill_badge(metadata)
    source = metadata["source"]
    source_text = case source
    when "profile" then "Profile"
    when "previous_submission" then "Previous Form"
    else source
    end

    content_tag(:div,
                class: "autofill-badge badge badge-primary badge-sm gap-1 mb-1 py-3 px-3 h-auto",
                data: { autofill_indicator_target: "badge" }) do
      safe_join([
        icon(:lightning_bolt, class: "w-3 h-3"),
        content_tag(:span, "Auto-filled from #{source_text}"),
        content_tag(:div, class: "flex gap-2 ml-2 border-l border-primary-content/20 pl-2 text-[10px]") do
          safe_join([
            content_tag(:button, "Edit", type: "button", data: { action: "click->autofill-indicator#edit" }, class: "hover:underline"),
            content_tag(:button, "Clear", type: "button", data: { action: "click->autofill-indicator#clear" }, class: "hover:underline text-error-content")
          ])
        end
      ])
    end
  end

  # Renders format hint and example for a field
  def field_help_hint(field)
    help_info = Utilities::FieldHelpService.help_for(field)
    return nil if help_info[:format_hint].blank? && help_info[:example].blank?

    content_tag(:div, class: "flex flex-col gap-0.5 mt-1 mb-1") do
      hint_parts = []
      hint_parts << content_tag(:p, help_info[:format_hint], class: "text-xs text-base-content/60 italic") if help_info[:format_hint].present?
      hint_parts << format_example(help_info[:example]) if help_info[:example].present?
      safe_join(hint_parts)
    end
  end

  # Renders a "Stuck? Get Help" button for a field
  def stuck_get_help_button(field)
    faq_anchor = Utilities::FieldHelpService.faq_anchor(field.name)
    return nil unless faq_anchor

    content_tag(:div, class: "mt-2") do
      content_tag(:button, type: "button",
                  class: "btn btn-ghost btn-xs text-primary gap-1 normal-case font-normal p-0 h-auto min-h-0",
                  data: {
                    action: "click->faq#open",
                    faq_anchor: faq_anchor
                  }) do
        safe_join([
          icon(:question_circle, class: "w-3.5 h-3.5"),
          "Stuck? Get help with this field"
        ])
      end
    end
  end

  def autofill_trigger(field)
    suggestion_service = Autofill::SuggestionService.new(current_user)
    suggestions = suggestion_service.suggestions_for(field.shared_field_key)

    return nil if suggestions.empty?

    content_tag(:button, type: "button",
                class: "btn btn-ghost btn-xs gap-1 text-primary normal-case font-normal",
                data: {
                  controller: "autofill",
                  autofill_suggestions_value: suggestions.to_json,
                  action: "click->autofill#toggle"
                },
                aria: { haspopup: "listbox", expanded: "false" },
                title: "Autofill from your profile") do
      safe_join([
        magic_wand_icon,
        "Magic Fill"
      ])
    end
  end

  # magic_wand_icon is now provided by IconHelper

  # Generate unique ID for field help text (used by aria-describedby)
  def field_help_id(field, prefix: nil)
    [ prefix, field.name.parameterize, "help" ].compact.join("-")
  end

  # Generate unique ID for field error message (used by aria-errormessage)
  def field_error_id(field, prefix: nil)
    [ prefix, field.name.parameterize, "error" ].compact.join("-")
  end

  # ARIA attributes hash to spread into form fields
  # Usage: <%= form.text_field field.name, **field_aria_attributes(field, errors: @submission.errors) %>
  # @param field [FieldDefinition] The field definition
  # @param prefix [String] Optional prefix for IDs
  # @param errors [ActiveModel::Errors] Optional errors object to check for validation errors
  def field_aria_attributes(field, prefix: nil, errors: nil)
    attrs = {}

    # Link to help text if present
    describedby_ids = []
    describedby_ids << field_help_id(field, prefix: prefix) if field.help_text.present?
    describedby_ids << field_error_id(field, prefix: prefix) # Always include error container
    attrs[:"aria-describedby"] = describedby_ids.join(" ") if describedby_ids.any?

    # Required fields
    attrs[:"aria-required"] = "true" if field.required

    # Validation error state - set aria-invalid when field has errors
    if errors.present? && field_has_error?(field, errors)
      attrs[:"aria-invalid"] = "true"
      attrs[:"aria-errormessage"] = field_error_id(field, prefix: prefix)
    end

    attrs
  end

  # Check if a field has validation errors
  # @param field [FieldDefinition] The field definition
  # @param errors [ActiveModel::Errors] The errors object
  # @return [Boolean]
  def field_has_error?(field, errors)
    return false if errors.blank?

    # Check both the field name and form_data.field_name patterns
    errors.key?(field.name.to_sym) ||
      errors.key?("form_data.#{field.name}".to_sym) ||
      errors.key?(:form_data) && errors[:form_data].to_s.include?(field.name)
  end

  # Standard field label with required indicator, optional tooltip, and legal term tooltips
  def field_label(field, show_tooltip: true, prefix: nil)
    content_tag(:label, class: "label", for: [ prefix, field.name.parameterize, "input" ].compact.join("-")) do
      label_parts = []
      label_text = field.label || field.name.titleize

      # Label text with optional tooltip hint
      if field.help_text.present? && show_tooltip
        label_parts << tooltip_label(label_text, field.help_text)
      else
        label_parts << content_tag(:span, label_text, class: "label-text font-medium text-base")
      end

      # Add legal term tooltip icon if label contains legal terms
      legal_tooltip = legal_term_tooltip_icon(label_text)
      label_parts << legal_tooltip if legal_tooltip

      label_parts << content_tag(:span, "*", class: "label-text-alt text-error ml-1") if field.required

      safe_join(label_parts)
    end
  end

  # Label with tooltip hint icon
  def tooltip_label(label_text, tooltip_text)
    content_tag(:span, class: "tooltip-hint label-text font-medium text-base",
                       data: { tip: tooltip_text },
                       tabindex: "0") do
      safe_join([ label_text, icon(:info_circle, class: "tooltip-icon") ])
    end
  end

  # Help text below field (with optional ID for aria-describedby)
  # Now automatically highlights legal terms with interactive tooltips
  def field_help_text(text, id = nil, highlight_terms: true)
    content_tag(:label, class: "label w-full text-wrap", id: id) do
      displayed_text = highlight_terms ? highlight_legal_terms(text) : text
      content_tag(:span, displayed_text, class: "label-text-alt text-base-content/70")
    end
  end

  # Expandable "What's this?" section for legal terms and complex concepts
  # Usage: <%= expandable_help("Venue", "The court location where your case will be heard...") %>
  def expandable_help(title, content, options = {})
    link_url = options[:link_url]
    link_text = options[:link_text] || "Learn more"

    content_tag(:details, class: "mt-2 text-sm") do
      parts = []

      # Summary (clickable header)
      parts << content_tag(:summary, class: "cursor-pointer text-primary hover:text-primary-focus font-medium") do
        safe_join([
          content_tag(:span, "What is \"#{title}\" ?", class: "underline decoration-dotted"),
          icon(:chevron_down, class: "inline w-4 h-4 ml-1 transition-transform details-open:rotate-180")
        ])
      end

      # Content
      parts << content_tag(:div, class: "mt-2 p-3 bg-base-200 rounded-lg text-base-content/80") do
        inner_parts = [ content_tag(:p, content) ]

        # Optional link to CA Courts Self-Help
        if link_url.present?
          inner_parts << content_tag(:a, href: link_url, target: "_blank", rel: "noopener",
                                        class: "inline-flex items-center gap-1 mt-2 text-primary hover:underline") do
            safe_join([ link_text, external_link_icon ])
          end
        end

        safe_join(inner_parts)
      end

      safe_join(parts)
    end
  end

  # Format example hint for input fields
  # Usage: <%= format_example("e.g., John Smith") %>
  def format_example(example, options = {})
    css_class = options[:class] || "text-xs text-base-content/60 mt-1"

    content_tag(:p, class: css_class) do
      safe_join([
        content_tag(:span, "Format: ", class: "font-medium"),
        example
      ])
    end
  end

  # Link to CA Courts Self-Help Center
  def self_help_link(topic = nil)
    base_url = "https://selfhelp.courts.ca.gov/small-claims"
    url = topic.present? ? "#{base_url}/#{topic}" : base_url

    content_tag(:a, href: url, target: "_blank", rel: "noopener",
                   class: "inline-flex items-center gap-1 text-xs text-primary hover:underline mt-2") do
      safe_join([ "CA Courts Self-Help", external_link_icon ])
    end
  end

  # Error message container with aria-live for screen reader announcements
  # Error content is populated dynamically by JavaScript validation
  def field_error_container(field, prefix: nil)
    content_tag(:div,
                "",
                id: field_error_id(field, prefix: prefix),
                class: "field-error text-error text-sm mt-1 hidden",
                role: "alert",
                aria: { live: "polite", atomic: "true" })
  end

  # Standard input classes for consistent styling
  def standard_input_class
    "input input-bordered w-full min-h-[48px] text-base"
  end

  def standard_textarea_class
    "textarea textarea-bordered w-full text-base"
  end

  def standard_select_class
    "select select-bordered w-full min-h-[48px] text-base"
  end

  # Standard data attributes for form fields
  def field_data_attributes(action: "input->form#fieldChanged")
    {
      action: "#{action} mouseenter->form#highlightField mouseleave->form#clearHighlight",
      validation_target: "input"
    }
  end

  # Field type configurations for consolidated input rendering
  FIELD_TYPE_CONFIG = {
    text: {
      method: :text_field,
      options: ->(field) { { maxlength: field.max_length, pattern: field.validation_pattern } }
    },
    email: {
      method: :email_field,
      options: ->(_field) { { inputmode: "email", autocomplete: "email" } },
      default_placeholder: "email@example.com"
    },
    tel: {
      method: :telephone_field,
      options: ->(_field) { { inputmode: "tel", autocomplete: "tel" } },
      default_placeholder: "(555) 555-5555",
      extra_actions: "input->input-format#format",
      extra_controller: "input-format",
      extra_data: { input_format_type_value: "phone" }
    },
    number: {
      method: :number_field,
      options: ->(field) { { min: field.min_length, max: field.max_length, inputmode: "numeric" } }
    },
    date: {
      method: :date_field,
      options: ->(_field) { {} }
    },
    currency: {
      method: :text_field, # Use text_field for currency to allow formatting with commas
      options: ->(_field) { { inputmode: "decimal" } },
      default_placeholder: "0.00",
      extra_actions: "input->input-format#format",
      extra_controller: "input-format",
      extra_data: { input_format_type_value: "currency" },
      wrapper: true,
      wrapper_class: "pl-7"
    }
  }.freeze

  # Build common field options for any input type
  # @param field [FieldDefinition] The field definition
  # @param field_type [Symbol] The type of field (:text, :email, :tel, :number, :date, :currency)
  # @param submission [Submission] The submission to get values from
  # @param prefix [String, nil] Optional prefix for field IDs
  # @return [Hash] Options hash for form field helper
  def build_field_options(field, field_type, submission, prefix: nil)
    config = FIELD_TYPE_CONFIG[field_type] || FIELD_TYPE_CONFIG[:text]

    # Base action string
    base_action = "input->form#fieldChanged keydown->keyboard-nav#handleKeydown"
    action = config[:extra_actions] ? "#{base_action} #{config[:extra_actions]}" : base_action

    # Build options hash
    options = {
      value: submission.field_value(field.name),
      placeholder: field.placeholder || config[:default_placeholder],
      required: field.required,
      enterkeyhint: "next",
      class: config[:wrapper_class] ? "#{standard_input_class} #{config[:wrapper_class]}" : standard_input_class,
      id: [ prefix, field.name.parameterize, "input" ].compact.join("-"),
      data: field_data_attributes.merge(
        action: action,
        field_help: Utilities::FieldHelpService.help_for(field).to_json,
        retry_suggestions: Utilities::FieldHelpService.retry_suggestions(field.name).presence || Utilities::FieldHelpService.retry_suggestions(field.field_type)
      )
    }

    # Add extra controller if defined
    if config[:extra_controller]
      options[:data][:controller] = [ options[:data][:controller], config[:extra_controller] ].compact.join(" ")
      options[:data].merge!(config[:extra_data]) if config[:extra_data]
      # Set target for the extra controller
      options[:data]["#{config[:extra_controller]}_target"] = "input"
    end

    # Merge type-specific options
    type_options = config[:options].call(field)
    options.merge!(type_options.compact)

    # Add ARIA attributes
    options.merge!(field_aria_attributes(field, prefix: prefix))

    options
  end

  # Render an input field with the appropriate type
  # @param form [ActionView::Helpers::FormBuilder] The form builder
  # @param field [FieldDefinition] The field definition
  # @param field_type [Symbol] The type of field
  # @param submission [Submission] The submission
  # @param prefix [String, nil] Optional prefix for field IDs
  # @return [String] The rendered field HTML
  def render_input_field(form, field, field_type, submission, prefix: nil)
    config = FIELD_TYPE_CONFIG[field_type] || FIELD_TYPE_CONFIG[:text]
    options = build_field_options(field, field_type, submission, prefix: prefix)
    method = config[:method]

    field_html = form.send(method, field.name, options)

    # Wrap currency field with $ prefix
    if config[:wrapper]
      content_tag(:div, class: "relative") do
        safe_join([
          content_tag(:span, "$", class: "absolute left-3 top-1/2 -translate-y-1/2 text-base-content/60"),
          field_html
        ])
      end
    else
      field_html
    end
  end

  # Textarea with dictation support
  def dictatable_textarea(form, method, options = {})
    content_tag(:div, class: "relative", data: { controller: "dictation" }) do
      parts = []

      # Textarea
      options[:data] ||= {}
      options[:data][:dictation_target] = "input"
      parts << form.text_area(method, options)

      # Dictation Button
      parts << content_tag(:button, type: "button",
                           class: "absolute bottom-2 right-2 p-2 text-base-content/60 hover:text-primary transition-colors rounded-full",
                           data: { dictation_target: "button", action: "click->dictation#toggle" },
                           title: "Dictate",
                           aria: { label: "Start dictation" }) do
        content_tag(:span, data: { dictation_target: "icon" }) do
          content_tag(:svg, class: "w-5 h-5", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24", "stroke-width": "1.5") do
            content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M12 18.75a6 6 0 006-6v-1.5m-6 7.5a6 6 0 01-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 01-3-3V4.5a3 3 0 116 0v8.25a3 3 0 01-3 3z")
          end
        end
      end

      safe_join(parts)
    end
  end
end
