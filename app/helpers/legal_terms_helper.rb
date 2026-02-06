# frozen_string_literal: true

module LegalTermsHelper
  # Highlights legal terms in text with interactive tooltips
  # Usage: <%= highlight_legal_terms("The plaintiff must serve the defendant") %>
  def highlight_legal_terms(text)
    return "" if text.blank?

    highlighted = LegalTerms::Glossary.instance.highlight_terms(text)
    highlighted.html_safe
  end

  # Creates a single legal term tooltip
  # Usage: <%= legal_term("plaintiff") %>
  def legal_term(term_text, options = {})
    term_data = LegalTerms::Glossary.instance.find_by_term(term_text)
    return term_text unless term_data

    display_text = options[:display] || term_text
    tooltip_text = term_data[:simple] || term_data[:definition]

    content_tag(:span,
      display_text,
      class: "legal-term #{options[:class]}".strip,
      data: {
        controller: "legal-tooltip",
        legal_tooltip_definition_value: term_data[:definition],
        legal_tooltip_simple_value: term_data[:simple] || "",
        legal_tooltip_url_value: term_data[:help_url] || glossary_term_url(term_data)
      },
      tabindex: "0",
      role: "button",
      aria: { label: "#{display_text}: #{tooltip_text}" }
    )
  end

  # Creates a "What's this?" tooltip icon for field labels containing legal terms
  # Usage: <%= legal_term_tooltip_icon(field.label) %>
  def legal_term_tooltip_icon(label_text, options = {})
    return nil if label_text.blank?

    glossary = LegalTerms::Glossary.instance
    terms = glossary.terms_in_label(label_text)
    return nil if terms.empty?

    # Use the first term found for the tooltip
    term_data = terms.first
    tooltip_text = term_data[:simple] || term_data[:definition]
    icon_class = options[:class] || "w-4 h-4 ml-1"

    content_tag(:button,
      type: "button",
      class: "legal-term-icon inline-flex items-center text-base-content/60 hover:text-primary focus:text-primary transition-colors",
      data: {
        controller: "legal-tooltip",
        legal_tooltip_definition_value: term_data[:definition],
        legal_tooltip_simple_value: term_data[:simple] || "",
        legal_tooltip_url_value: term_data[:help_url] || glossary_term_url(term_data)
      },
      tabindex: "0",
      title: "What is #{term_data[:term]}?",
      aria: { label: "Learn about #{term_data[:term]}: #{tooltip_text}" }
    ) do
      icon(:info_circle, class: icon_class)
    end
  end

  # Creates a label with legal term tooltip icon if terms are found
  # Usage: <%= label_with_legal_tooltip("Plaintiff Name", "plaintiff") %>
  def label_with_legal_tooltip(label_text, term_key = nil)
    glossary = LegalTerms::Glossary.instance

    # If specific term key provided, look it up
    term_data = if term_key.present?
                  glossary.find(term_key) || glossary.find_by_term(term_key)
    else
                  glossary.first_term_in(label_text)
    end

    return content_tag(:span, label_text, class: "label-text font-medium text-base") unless term_data

    tooltip_text = term_data[:simple] || term_data[:definition]

    content_tag(:span, class: "inline-flex items-center gap-1") do
      label_span = content_tag(:span, label_text, class: "label-text font-medium text-base")

      tooltip_button = content_tag(:button,
        type: "button",
        class: "legal-term-icon inline-flex items-center text-base-content/60 hover:text-primary focus:text-primary transition-colors rounded-full",
        data: {
          controller: "legal-tooltip",
          legal_tooltip_definition_value: term_data[:definition],
          legal_tooltip_simple_value: term_data[:simple] || "",
          legal_tooltip_url_value: term_data[:help_url] || glossary_term_url(term_data)
        },
        tabindex: "0",
        title: "What is #{term_data[:term]}?",
        aria: { label: "Learn about #{term_data[:term]}: #{tooltip_text}" }
      ) do
        icon(:info_circle, class: "w-4 h-4")
      end

      safe_join([ label_span, tooltip_button ])
    end
  end

  # Renders the full glossary for reference
  def legal_terms_glossary
    terms = LegalTerms::Glossary.instance.terms.sort_by { |t| t[:term] }
    render partial: "shared/legal_terms_glossary", locals: { terms: terms }
  end

  # Renders grouped glossary with categories
  def legal_terms_glossary_grouped
    categories = LegalTerms::Glossary.instance.terms_by_category
    render partial: "shared/legal_terms_glossary_grouped", locals: { categories: categories }
  end

  # Check if text contains any legal terms
  def contains_legal_terms?(text)
    return false if text.blank?

    LegalTerms::Glossary.instance.contains_terms?(text)
  end

  # Get all legal terms for a given text
  def legal_terms_in(text)
    return [] if text.blank?

    LegalTerms::Glossary.instance.terms_in_label(text)
  end

  # URL to glossary page with anchor to specific term
  def glossary_term_url(term_data)
    "/glossary##{term_data[:term].parameterize}"
  end

  # Render a compact tooltip for inline use
  # Shows term with dotted underline and tooltip on hover
  def inline_legal_term(term_text, display_text = nil)
    term_data = LegalTerms::Glossary.instance.find_by_term(term_text)
    display = display_text || term_text

    return display unless term_data

    content_tag(:span,
      display,
      class: "legal-term-inline",
      data: {
        controller: "legal-tooltip",
        legal_tooltip_definition_value: term_data[:definition],
        legal_tooltip_simple_value: term_data[:simple] || "",
        legal_tooltip_url_value: term_data[:help_url] || glossary_term_url(term_data)
      },
      tabindex: "0",
      role: "button",
      aria: { label: "#{display}: #{term_data[:simple] || term_data[:definition]}" }
    )
  end
end
