# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormEstimates::TimeEstimator do
  let(:form) { create(:form_definition) }
  let(:estimator) { described_class.new(form) }

  describe "#estimated_minutes" do
    context "with minimal form (5 text fields)" do
      before do
        create_list(:field_definition, 5, :text, form_definition: form)
      end

      it "calculates estimate with base time and field time" do
        # Base: 2 min
        # Fields: 5 × 0.5 = 2.5 min
        # Complexity modifier (easy): 0
        # Total: 4.5, rounded to 5
        expect(estimator.estimated_minutes).to eq(5)
      end
    end

    context "with medium complexity form (20 text fields)" do
      before do
        create_list(:field_definition, 20, :text, form_definition: form)
      end

      it "includes complexity modifier for medium difficulty" do
        # Base: 2 min
        # Fields: 20 × 0.5 = 10 min
        # Complexity modifier (medium): 3 min
        # Total: 15 min
        expect(estimator.estimated_minutes).to eq(15)
      end
    end

    context "with mixed field types" do
      before do
        create_list(:field_definition, 3, :text, form_definition: form)        # 3 × 0.5 = 1.5
        2.times do |i|
          form.field_definitions.create!(
            name: "textarea_field_#{i}",
            pdf_field_name: "TextareaField#{i}",
            field_type: "textarea",
            label: "Textarea #{i}",
            position: 4 + i
          )
        end                                                                      # 2 × 1.5 = 3
        create(:field_definition, :signature, form_definition: form)           # 1 × 1.5 = 1.5
      end

      it "weights different field types correctly" do
        # Base: 2 min
        # Fields: 1.5 + 3 + 1.5 = 6 min
        # Complexity modifier (easy): 0
        # Total: 8, rounded to 10
        expect(estimator.estimated_minutes).to eq(10)
      end
    end

    context "with complex form (50 text fields)" do
      before do
        create_list(:field_definition, 50, :text, form_definition: form)
      end

      it "includes higher complexity modifier" do
        # Base: 2 min
        # Fields: 50 × 0.5 = 25 min
        # Complexity modifier (complex): 8 min
        # Total: 35 min
        expect(estimator.estimated_minutes).to eq(35)
      end
    end

    it "enforces minimum of 5 minutes" do
      # Even with 0 fields, should be at least 5 minutes
      expect(estimator.estimated_minutes).to be >= 5
    end

    it "rounds to nearest 5 minutes" do
      create_list(:field_definition, 3, :text, form_definition: form)
      # Should be multiple of 5
      expect(estimator.estimated_minutes % 5).to eq(0)
    end
  end

  describe "#formatted_estimate" do
    context "with less than 60 minutes" do
      before do
        create_list(:field_definition, 5, :text, form_definition: form)
      end

      it "formats as minutes" do
        expect(estimator.formatted_estimate).to match(/~\d+ min/)
      end
    end

    context "with exactly 60 minutes" do
      before do
        # Create enough fields to reach 60 minutes
        # Need (60 - 2 base - 3 medium modifier) = 55 from fields
        # 55 / 0.5 = 110 fields
        # But that's complex level (+8 modifier)
        # Let's create a form that estimates to exactly 60
        allow(estimator).to receive(:calculate_estimated_minutes).and_return(60)
      end

      it "formats as hours only" do
        expect(estimator.formatted_estimate).to eq("~1 hr")
      end
    end

    context "with more than 60 minutes" do
      before do
        # Mock to control exact time
        allow(estimator).to receive(:calculate_estimated_minutes).and_return(85)
      end

      it "formats as hours and minutes" do
        expect(estimator.formatted_estimate).to eq("~1 hr 25 min")
      end
    end

    context "with multiple hours" do
      before do
        allow(estimator).to receive(:calculate_estimated_minutes).and_return(150)
      end

      it "formats hours and minutes" do
        expect(estimator.formatted_estimate).to eq("~2 hr 30 min")
      end
    end
  end

  describe "#time_range" do
    before do
      create_list(:field_definition, 10, :text, form_definition: form)
    end

    it "returns hash with min and max keys" do
      range = estimator.time_range
      expect(range).to have_key(:min)
      expect(range).to have_key(:max)
    end

    it "calculates min as 70% of estimate" do
      estimate = estimator.estimated_minutes
      range = estimator.time_range
      expect(range[:min]).to eq((estimate * 0.7).round)
    end

    it "calculates max as 150% of estimate" do
      estimate = estimator.estimated_minutes
      range = estimator.time_range
      expect(range[:max]).to eq((estimate * 1.5).round)
    end

    it "enforces minimum of 2 minutes" do
      range = estimator.time_range
      expect(range[:min]).to be >= 2
    end
  end

  describe "#formatted_range" do
    before do
      create_list(:field_definition, 10, :text, form_definition: form)
    end

    it "returns formatted string with min-max" do
      expect(estimator.formatted_range).to match(/\d+-\d+ min/)
    end

    it "uses values from time_range" do
      range = estimator.time_range
      expected = "#{range[:min]}-#{range[:max]} min"
      expect(estimator.formatted_range).to eq(expected)
    end
  end

  describe "#time_category" do
    context "with 10 minutes or less" do
      before do
        create_list(:field_definition, 5, :text, form_definition: form)
      end

      it "returns :quick" do
        expect(estimator.time_category).to eq(:quick)
      end
    end

    context "with 11-30 minutes" do
      before do
        create_list(:field_definition, 20, :text, form_definition: form)
      end

      it "returns :moderate" do
        expect(estimator.time_category).to eq(:moderate)
      end
    end

    context "with more than 30 minutes" do
      before do
        create_list(:field_definition, 50, :text, form_definition: form)
      end

      it "returns :extended" do
        expect(estimator.time_category).to eq(:extended)
      end
    end
  end

  describe "TIME_PER_FIELD_TYPE constant" do
    it "defines time for all standard field types" do
      expect(described_class::TIME_PER_FIELD_TYPE).to include(
        "text" => 0.5,
        "textarea" => 1.5,
        "signature" => 1.5,
        "address" => 2.5,
        "hidden" => 0
      )
    end

    it "is frozen" do
      expect(described_class::TIME_PER_FIELD_TYPE).to be_frozen
    end
  end

  describe "COMPLEXITY_MODIFIERS constant" do
    it "defines modifiers for all difficulty levels" do
      expect(described_class::COMPLEXITY_MODIFIERS).to eq(
        easy: 0,
        medium: 3,
        complex: 8
      )
    end

    it "is frozen" do
      expect(described_class::COMPLEXITY_MODIFIERS).to be_frozen
    end
  end

  describe "BASE_TIME_MINUTES constant" do
    it "is set to 2 minutes" do
      expect(described_class::BASE_TIME_MINUTES).to eq(2)
    end
  end
end
