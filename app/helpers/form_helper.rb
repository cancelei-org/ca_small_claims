# frozen_string_literal: true

module FormHelper
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
    label_inline = options.fetch(:label_inline, false)
    extra_classes = options.fetch(:extra_classes, "")
    show_tooltip = options.fetch(:show_tooltip, true)
    prefix = options[:prefix]
    wrapper_class = "form-control w-full mb-4 #{extra_classes}".strip

    content_tag(:div, class: wrapper_class, data: { field_name: field.name }) do
      parts = []

      # Label (unless inline)
      unless label_inline
        parts << content_tag(:div, class: "flex items-center justify-between") do
          label_parts = [ field_label(field, show_tooltip: show_tooltip, prefix: prefix) ]

          # Add Autofill Trigger if suggestions are available
          if field.shared_field_key.present? && user_signed_in?
            trigger = autofill_trigger(field)
            label_parts << trigger if trigger
          end

          safe_join(label_parts)
        end
      end

      # Input content from block
      parts << capture(&block) if block_given?

      # Help text below field (with ID for aria-describedby)
      parts << field_help_text(field.help_text, field_help_id(field, prefix: prefix)) if field.help_text.present? && !show_tooltip

      # Error message container (aria-live for screen reader announcements)
      parts << field_error_container(field, prefix: prefix)

      safe_join(parts)
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

  def magic_wand_icon
    '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-3.5 h-3.5"><path stroke-linecap="round" stroke-linejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456zM16.894 20.567L16.5 21.75l-.394-1.183a2.25 2.25 0 00-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 001.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 001.423 1.423l1.183.394-1.183.394a2.25 2.25 0 00-1.423 1.423z" /></svg>'.html_safe
  end

  # Generate unique ID for field help text (used by aria-describedby)
  def field_help_id(field, prefix: nil)
    [ prefix, field.name.parameterize, "help" ].compact.join("-")
  end

  # Generate unique ID for field error message (used by aria-errormessage)
  def field_error_id(field, prefix: nil)
    [ prefix, field.name.parameterize, "error" ].compact.join("-")
  end

  # ARIA attributes hash to spread into form fields
  # Usage: <%= form.text_field field.name, **field_aria_attributes(field) %>
  def field_aria_attributes(field, prefix: nil)
    attrs = {}

    # Link to help text if present
    describedby_ids = []
    describedby_ids << field_help_id(field, prefix: prefix) if field.help_text.present?
    describedby_ids << field_error_id(field, prefix: prefix) # Always include error container
    attrs[:"aria-describedby"] = describedby_ids.join(" ") if describedby_ids.any?

    # Required fields
    attrs[:"aria-required"] = "true" if field.required

    attrs
  end

  # Standard field label with required indicator and optional tooltip
  def field_label(field, show_tooltip: true, prefix: nil)
    content_tag(:label, class: "label", for: [ prefix, field.name.parameterize, "input" ].compact.join("-")) do
      label_parts = []

      # Label text with optional tooltip hint
      if field.help_text.present? && show_tooltip
        label_parts << tooltip_label(field.label || field.name.titleize, field.help_text)
      else
        label_parts << content_tag(:span, field.label || field.name.titleize,
                                   class: "label-text font-medium text-base")
      end

      label_parts << content_tag(:span, "*", class: "label-text-alt text-error ml-1") if field.required

      safe_join(label_parts)
    end
  end

  # Label with tooltip hint icon
  def tooltip_label(label_text, tooltip_text)
    content_tag(:span, class: "tooltip-hint label-text font-medium text-base",
                       data: { tip: tooltip_text },
                       tabindex: "0") do
      icon = content_tag(:svg, class: "tooltip-icon",
                                fill: "none",
                                stroke: "currentColor",
                                viewBox: "0 0 24 24") do
        content_tag(:path, nil,
                    "stroke-linecap": "round",
                    "stroke-linejoin": "round",
                    "stroke-width": "2",
                    d: "M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z")
      end

      safe_join([ label_text, icon ])
    end
  end

  # Help text below field (with optional ID for aria-describedby)
  def field_help_text(text, id = nil)
    content_tag(:label, class: "label w-full text-wrap", id: id) do
      content_tag(:span, text, class: "label-text-alt text-base-content/70")
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
          content_tag(:svg, class: "inline w-4 h-4 ml-1 transition-transform details-open:rotate-180",
                           fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
            content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round",
                              "stroke-width": "2", d: "M19 9l-7 7-7-7")
          end
        ])
      end

      # Content
      parts << content_tag(:div, class: "mt-2 p-3 bg-base-200 rounded-lg text-base-content/80") do
        inner_parts = [ content_tag(:p, content) ]

        # Optional link to CA Courts Self-Help
        if link_url.present?
          inner_parts << content_tag(:a, href: link_url, target: "_blank", rel: "noopener",
                                        class: "inline-flex items-center gap-1 mt-2 text-primary hover:underline") do
            safe_join([
              link_text,
              content_tag(:svg, class: "w-3 h-3", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
                content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round",
                                  "stroke-width": "2", d: "M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14")
              end
            ])
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
    css_class = options[:class] || "text-xs text-base-content/50 mt-1"

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
      safe_join([
        "CA Courts Self-Help",
        content_tag(:svg, class: "w-3 h-3", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
          content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round",
                            "stroke-width": "2", d: "M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14")
        end
      ])
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
                           class: "absolute bottom-2 right-2 p-2 text-base-content/50 hover:text-primary transition-colors rounded-full",
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
