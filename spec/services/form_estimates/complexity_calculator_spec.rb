# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormEstimates::ComplexityCalculator do
  let(:form) { create(:form_definition) }
  let(:calculator) { described_class.new(form) }

  describe "#complexity_score" do
    context "with simple text fields" do
      before do
        create_list(:field_definition, 5, :text, form_definition: form)
      end

      it "calculates correct score for simple fields" do
        # 5 text fields × weight 1 = 5
        expect(calculator.complexity_score).to eq(5)
      end
    end

    context "with mixed field types" do
      before do
        create(:field_definition, :text, form_definition: form)        # weight 1
        form.field_definitions.create!(
          name: "textarea_field",
          pdf_field_name: "TextareaField",
          field_type: "textarea",
          label: "Textarea",
          position: 2
        )                                                                # weight 2
        create(:field_definition, :signature, form_definition: form)   # weight 3
      end

      it "calculates weighted score correctly" do
        # 1 + 2 + 3 = 6
        expect(calculator.complexity_score).to eq(6)
      end
    end

    context "with required fields" do
      before do
        create_list(:field_definition, 5, :text, form_definition: form)
        create_list(:field_definition, 3, :text, :required, form_definition: form)
      end

      it "adds bonus for required fields" do
        # 8 text fields × 1 = 8
        # 3 required × 0.5 = 1.5 rounded to 2
        # Total: 8 + 2 = 10
        expect(calculator.complexity_score).to eq(10)
      end
    end

    context "with hidden and readonly fields" do
      before do
        create_list(:field_definition, 3, :text, form_definition: form)
        form.field_definitions.create!(
          name: "hidden_field",
          pdf_field_name: "HiddenField",
          field_type: "hidden",
          label: "Hidden",
          position: 4
        )
        form.field_definitions.create!(
          name: "readonly_field",
          pdf_field_name: "ReadonlyField",
          field_type: "readonly",
          label: "Readonly",
          position: 5
        )
      end

      it "excludes hidden and readonly fields from score" do
        # Only 3 text fields counted, hidden/readonly have weight 0
        expect(calculator.complexity_score).to eq(3)
      end
    end
  end

  describe "#difficulty_level" do
    context "when score is <= 15 (easy threshold)" do
      before do
        create_list(:field_definition, 5, :text, form_definition: form)
      end

      it "returns :easy" do
        expect(calculator.difficulty_level).to eq(:easy)
      end
    end

    context "when score is between 15 and 40 (medium threshold)" do
      before do
        create_list(:field_definition, 20, :text, form_definition: form)
      end

      it "returns :medium" do
        expect(calculator.difficulty_level).to eq(:medium)
      end
    end

    context "when score is > 40 (complex threshold)" do
      before do
        create_list(:field_definition, 50, :text, form_definition: form)
      end

      it "returns :complex" do
        expect(calculator.difficulty_level).to eq(:complex)
      end
    end
  end

  describe "#difficulty_label" do
    it "returns 'Easy' for easy difficulty" do
      create_list(:field_definition, 5, :text, form_definition: form)
      expect(calculator.difficulty_label).to eq("Easy")
    end

    it "returns 'Medium' for medium difficulty" do
      create_list(:field_definition, 20, :text, form_definition: form)
      expect(calculator.difficulty_label).to eq("Medium")
    end

    it "returns 'Complex' for complex difficulty" do
      create_list(:field_definition, 50, :text, form_definition: form)
      expect(calculator.difficulty_label).to eq("Complex")
    end
  end

  describe "#total_fields" do
    before do
      create_list(:field_definition, 5, :text, form_definition: form)
      form.field_definitions.create!(
        name: "hidden_field",
        pdf_field_name: "HiddenField",
        field_type: "hidden",
        label: "Hidden",
        position: 6
      )
    end

    it "counts only visible fields" do
      expect(calculator.total_fields).to eq(5)
    end
  end

  describe "#required_fields_count" do
    before do
      create_list(:field_definition, 3, :text, form_definition: form)
      create_list(:field_definition, 2, :text, :required, form_definition: form)
    end

    it "counts only required visible fields" do
      expect(calculator.required_fields_count).to eq(2)
    end
  end

  describe "#fields_by_type" do
    before do
      create_list(:field_definition, 2, :text, form_definition: form)
      create(:field_definition, :email, form_definition: form)
      create(:field_definition, :date, form_definition: form)
    end

    it "returns hash of field type counts" do
      result = calculator.fields_by_type
      expect(result["text"]).to eq(2)
      expect(result["email"]).to eq(1)
      expect(result["date"]).to eq(1)
    end
  end

  describe "#complex_fields_count" do
    before do
      create_list(:field_definition, 3, :text, form_definition: form)
      create(:field_definition, :signature, form_definition: form)
      form.field_definitions.create!(
        name: "address_field",
        pdf_field_name: "AddressField",
        field_type: "address",
        label: "Address",
        position: 5
      )
    end

    it "counts address, signature, and repeating_group fields" do
      expect(calculator.complex_fields_count).to eq(2)
    end
  end

  describe "FIELD_TYPE_WEIGHTS constant" do
    it "defines weights for all standard field types" do
      expect(described_class::FIELD_TYPE_WEIGHTS).to include(
        "text" => 1,
        "email" => 1,
        "tel" => 1,
        "textarea" => 2,
        "signature" => 3,
        "hidden" => 0
      )
    end

    it "is frozen" do
      expect(described_class::FIELD_TYPE_WEIGHTS).to be_frozen
    end
  end

  describe "DIFFICULTY_LABELS constant" do
    it "maps all difficulty levels to labels" do
      expect(described_class::DIFFICULTY_LABELS).to eq(
        easy: "Easy",
        medium: "Medium",
        complex: "Complex"
      )
    end

    it "is frozen" do
      expect(described_class::DIFFICULTY_LABELS).to be_frozen
    end
  end
end
