# frozen_string_literal: true

module Templates
  # Recommends templates based on form context and user input
  class Recommender
    # Recommend templates based on claim basis
    # @param claim_basis [String] the selected claim basis
    # @return [Array<Hash>] recommended templates sorted by relevance
    def self.for_claim_basis(claim_basis)
      return [] if claim_basis.blank?

      Loader.instance.for_claim_basis(claim_basis)
    end

    # Recommend templates based on form code
    # @param form_code [String] the form code (e.g., "SC-100")
    # @return [Array<Hash>] all available templates (most forms can use any template)
    def self.for_form(form_code)
      # For the main claim form (SC-100), show all templates
      return Loader.instance.all if form_code&.upcase == "SC-100"

      # For other forms, return empty (templates mainly apply to initial claim)
      []
    end

    # Get template suggestions based on keywords in description text
    # @param text [String] user-entered description text
    # @return [Array<Hash>] matching templates
    def self.from_description(text)
      return [] if text.blank?

      text_lower = text.downcase
      all_templates = Loader.instance.all

      # Score each template based on keyword matches
      scored = all_templates.map do |template|
        score = calculate_relevance_score(template, text_lower)
        { template: template, score: score }
      end

      # Return templates with positive scores, sorted by relevance
      scored.select { |s| s[:score] > 0 }
            .sort_by { |s| -s[:score] }
            .pluck(:template)
    end

    private_class_method def self.calculate_relevance_score(template, text)
      score = 0

      # Keywords associated with each template category
      keywords = {
        "landlord_dispute" => %w[
          landlord tenant rent lease apartment rental security deposit
          eviction habitability mold repair lease move-out
        ],
        "auto_accident" => %w[
          car vehicle accident collision crash insurance driver
          rear-end rear-ended hit damage fender
        ],
        "unpaid_debt" => %w[
          loan money owe owed debt check bounced lent borrowed
          invoice pay paid payment
        ],
        "property_damage" => %w[
          damage property broken contractor repair fence tree
          neighbor vandal vandalism pet dog
        ]
      }

      template_id = template[:id].to_s
      return 0 unless keywords.key?(template_id)

      keywords[template_id].each do |keyword|
        score += 1 if text.include?(keyword)
      end

      score
    end
  end
end
