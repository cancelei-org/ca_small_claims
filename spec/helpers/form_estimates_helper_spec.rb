# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormEstimatesHelper, type: :helper do
  # Easy form: 5 simple text fields (score: 5, under EASY_THRESHOLD of 15)
  let(:form_easy) do
    create(:form_definition, code: "SC-100").tap do |form|
      create_list(:field_definition, 5, :text, form_definition: form)
    end
  end

  # Medium form: 20 text fields (score: 20, between EASY_THRESHOLD 15 and MEDIUM_THRESHOLD 40)
  let(:form_medium) do
    create(:form_definition, code: "SC-120").tap do |form|
      create_list(:field_definition, 20, :text, form_definition: form)
    end
  end

  # Complex form: 50 text fields (score: 50, above MEDIUM_THRESHOLD of 40)
  let(:form_complex) do
    create(:form_definition, code: "SC-300").tap do |form|
      create_list(:field_definition, 50, :text, form_definition: form)
    end
  end

  describe "#difficulty_badge" do
    it "renders badge with correct color for easy difficulty" do
      result = helper.difficulty_badge(form_easy)

      expect(result).to include("badge")
      expect(result).to include("badge-success")
      expect(result).to include("Easy")
    end

    it "renders badge with correct color for medium difficulty" do
      result = helper.difficulty_badge(form_medium)

      expect(result).to include("badge-warning")
      expect(result).to include("Medium")
    end

    it "renders badge with correct color for complex difficulty" do
      result = helper.difficulty_badge(form_complex)

      expect(result).to include("badge-error")
      expect(result).to include("Complex")
    end

    it "respects size parameter" do
      result_sm = helper.difficulty_badge(form_easy, size: :sm)
      result_lg = helper.difficulty_badge(form_easy, size: :lg)

      expect(result_sm).to include("badge-sm")
      expect(result_lg).to include("badge-lg")
    end

    it "includes icon by default" do
      result = helper.difficulty_badge(form_easy)
      expect(result).to include("svg")
    end

    it "omits icon when show_icon is false" do
      result = helper.difficulty_badge(form_easy, show_icon: false)
      expect(result).not_to include("svg")
    end
  end

  describe "#time_estimate_badge" do
    it "renders time badge with estimated time" do
      result = helper.time_estimate_badge(form_easy)

      expect(result).to include("badge")
      expect(result).to include("min") # Dynamic calculation based on field count
    end

    it "respects size parameter" do
      result_lg = helper.time_estimate_badge(form_easy, size: :lg)
      expect(result_lg).to include("badge-lg")
    end

    it "includes clock icon by default" do
      result = helper.time_estimate_badge(form_easy)
      expect(result).to include("svg")
    end

    it "omits icon when show_icon is false" do
      result = helper.time_estimate_badge(form_easy, show_icon: false)
      expect(result).not_to include("svg")
    end
  end

  describe "#form_estimates_badges" do
    it "renders both difficulty and time badges" do
      result = helper.form_estimates_badges(form_medium)

      expect(result).to include("badge-warning")
      expect(result).to include("Medium")
      expect(result).to include("min") # Time estimate is calculated dynamically
    end

    it "wraps badges in flex container" do
      result = helper.form_estimates_badges(form_easy)
      expect(result).to include("flex")
    end
  end

  describe "#compact_estimates" do
    it "renders compact format with difficulty and time" do
      result = helper.compact_estimates(form_easy)

      expect(result).to include("Easy")
      expect(result).to include("min") # Time estimate is calculated dynamically
      expect(result).to include("text-xs")
    end

    it "uses correct color for difficulty level" do
      result = helper.compact_estimates(form_complex)
      expect(result).to include("text-error")
    end
  end

  describe "#detailed_estimates_card" do
    it "renders detailed card with all information" do
      result = helper.detailed_estimates_card(form_medium)

      expect(result).to include("Medium")
      expect(result).to include("difficulty")
      expect(result).to include("min") # Time estimate is calculated dynamically
      expect(result).to include("to complete")
    end

    it "includes field count when positive" do
      result = helper.detailed_estimates_card(form_easy)
      expect(result).to include("5") # form_easy has 5 fields
      expect(result).to include("fields")
    end

    it "uses correct background color" do
      result_easy = helper.detailed_estimates_card(form_easy)
      result_complex = helper.detailed_estimates_card(form_complex)

      expect(result_easy).to include("bg-success/10")
      expect(result_complex).to include("bg-error/10")
    end
  end

  describe "DIFFICULTY_COLORS constant" do
    it "defines colors for all difficulty levels" do
      expect(described_class::DIFFICULTY_COLORS.keys).to match_array([ :easy, :medium, :complex ])
    end

    it "includes all required color properties" do
      %i[easy medium complex].each do |level|
        colors = described_class::DIFFICULTY_COLORS[level]
        expect(colors).to have_key(:badge)
        expect(colors).to have_key(:bg)
        expect(colors).to have_key(:text)
        expect(colors).to have_key(:border)
      end
    end
  end
end
