# frozen_string_literal: true

module LegalTerms
  class Glossary
    include Singleton

    GLOSSARY_PATH = Rails.root.join("config/legal_terms/glossary.yml")

    def initialize
      @terms = load_terms
      @term_pattern = build_pattern
      @term_lookup = build_lookup
    end

    def terms
      @terms.values
    end

    def find(key)
      @terms[key.to_s]
    end

    def find_by_term(term_text)
      normalized = normalize_term(term_text)
      @term_lookup[normalized]
    end

    # Check if a label contains any legal terms
    # Returns array of matching terms found in the label
    def terms_in_label(label_text)
      return [] if label_text.blank? || @term_pattern.nil?

      matches = []
      label_text.scan(@term_pattern) do |match|
        term_data = find_term_for_match(match)
        matches << term_data if term_data
      end
      matches.uniq { |t| t[:term] }
    end

    # Check if text contains any legal terms
    def contains_terms?(text)
      return false if text.blank? || @term_pattern.nil?

      @term_pattern.match?(text)
    end

    # Get first legal term found in text (for tooltip display)
    def first_term_in(text)
      return nil if text.blank? || @term_pattern.nil?

      match = text.match(@term_pattern)
      return nil unless match

      find_term_for_match(match[0])
    end

    def highlight_terms(text)
      return text if text.blank? || @term_pattern.nil?

      text.gsub(@term_pattern) do |match|
        term_data = find_term_for_match(match)
        if term_data
          build_tooltip_span(match, term_data)
        else
          match
        end
      end
    end

    def all_terms
      @terms
    end

    # Get all terms grouped by category for display
    def terms_by_category
      # Group terms by their key prefix (before underscore)
      grouped = @terms.group_by do |key, _value|
        case key
        when /^(plaintiff|defendant|claimant|respondent)/
          "Parties"
        when /^(service|proof_of_service|personal_service|substituted_service|certified_mail)/
          "Service of Process"
        when /^(hearing|trial|continuance|default_judgment|judgment)/
          "Court Proceedings"
        when /^(venue|jurisdiction|small_claims_limit)/
          "Jurisdiction"
        when /^(damages|restitution|principal|interest|court_costs)/
          "Money & Damages"
        when /^(filing_fee|fee_waiver)/
          "Fees"
        when /^(statute_of_limitations|deadline)/
          "Deadlines"
        when /^(appeal|de_novo)/
          "Appeals"
        when /^(abstract_of_judgment|lien|garnishment|levy|writ_of_execution|satisfaction_of_judgment)/
          "Enforcement"
        when /^(subpoena|evidence|witness|testimony|exhibit)/
          "Evidence & Witnesses"
        when /^(small_claims_advisor|self_help_center|superior_court|clerk)/
          "Court Resources"
        when /^(dba|corporation|llc)/
          "Business Terms"
        when /^(contract|breach_of_contract|oral_contract)/
          "Contracts"
        when /^(security_deposit|landlord|tenant)/
          "Property & Rentals"
        when /^(dismissal|settlement|mediation|stipulation)/
          "Settlement & Dismissal"
        when /^(motion|vacate)/
          "Motions"
        else
          "General Terms"
        end
      end

      # Transform to just the values
      grouped.transform_values { |pairs| pairs.map { |_k, v| v } }
    end

    # Get glossary URL for linking
    def glossary_url
      "/glossary"
    end

    # Get term anchor for glossary page
    def term_anchor(term_data)
      term_data[:term].parameterize
    end

    def reload!
      @terms = load_terms
      @term_pattern = build_pattern
      @term_lookup = build_lookup
    end

    private

    def load_terms
      return {} unless File.exist?(GLOSSARY_PATH)

      data = YAML.load_file(GLOSSARY_PATH, permitted_classes: [ Symbol ])
      (data["terms"] || {}).transform_values(&:with_indifferent_access)
    end

    def build_pattern
      return nil if @terms.empty?

      # Build pattern matching all term variations
      term_words = @terms.values.flat_map do |t|
        [ t[:term], t[:term].pluralize, t[:term].singularize ].uniq
      end.compact.uniq

      # Sort by length (longest first) to match longer terms before shorter ones
      sorted_terms = term_words.sort_by { |t| -t.length }

      # Build case-insensitive pattern with word boundaries
      pattern_str = sorted_terms.map { |t| Regexp.escape(t) }.join("|")
      Regexp.new("\\b(#{pattern_str})\\b", Regexp::IGNORECASE)
    end

    def build_lookup
      lookup = {}
      @terms.each_value do |term_data|
        term = term_data[:term]
        # Add normalized versions of the term
        [ term, term.pluralize, term.singularize ].uniq.each do |variation|
          lookup[normalize_term(variation)] = term_data
        end
      end
      lookup
    end

    def normalize_term(text)
      text.to_s.downcase.gsub(/[^a-z\s]/, "").strip
    end

    def find_term_for_match(match)
      @term_lookup[normalize_term(match)]
    end

    def build_tooltip_span(match, term_data)
      tooltip_text = term_data[:simple] || term_data[:definition]
      glossary_link = "#{glossary_url}##{term_anchor(term_data)}"

      %(<span class="legal-term" data-controller="legal-tooltip" ) +
        %(data-legal-tooltip-definition-value="#{ERB::Util.html_escape(term_data[:definition])}" ) +
        %(data-legal-tooltip-simple-value="#{ERB::Util.html_escape(term_data[:simple] || "")}" ) +
        %(data-legal-tooltip-url-value="#{ERB::Util.html_escape(term_data[:help_url] || glossary_link)}" ) +
        %(tabindex="0" role="button" aria-label="#{ERB::Util.html_escape(match)}: #{ERB::Util.html_escape(tooltip_text)}">#{ERB::Util.html_escape(match)}</span>)
    end
  end
end
