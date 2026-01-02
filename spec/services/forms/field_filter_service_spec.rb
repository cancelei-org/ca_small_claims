# frozen_string_literal: true

require "rails_helper"

RSpec.describe Forms::FieldFilterService do
  let(:form) { create(:form_definition) }
  let!(:f1) { create(:field_definition, form_definition: form, name: "f1", position: 1, field_type: "text") }
  let!(:f2) { create(:field_definition, form_definition: form, name: "f2", position: 2, field_type: "text") }
  let!(:f3) { create(:field_definition, form_definition: form, name: "f3", position: 3, field_type: "text") }
  let!(:hidden) { create(:field_definition, form_definition: form, name: "hidden", position: 4, field_type: "hidden") }

  let(:submission) { create(:submission, form_definition: form, form_data: {}) }
  let(:user) { create(:user) }
  let(:service) { described_class.new(form, submission, user) }

  describe "#wizard_fields" do
    it "returns all visible fields by default" do
      fields = service.wizard_fields
      expect(fields).to contain_exactly(f1, f2, f3)
      expect(fields).not_to include(hidden)
    end

    context "with skip_filled: true" do
      before do
        submission.update!(form_data: { "f1" => "Value 1" })
      end

      it "skips fields that have data if user is present" do
        fields = service.wizard_fields(skip_filled: true)
        expect(fields).to contain_exactly(f2, f3)
      end

      it "does not skip fields if user is nil" do
        guest_service = described_class.new(form, submission, nil)
        fields = guest_service.wizard_fields(skip_filled: true)
        expect(fields).to contain_exactly(f1, f2, f3)
      end

      context "when a filled field is a trigger for a conditional field" do
        let!(:conditional_field) do
          create(:field_definition,
            form_definition: form,
            name: "cond",
            position: 5,
            conditions: { "field" => "f1", "operator" => "equals", "value" => "show" }
          )
        end

        it "includes the trigger field even if it has data" do
          submission.update!(form_data: { "f1" => "show" })

          # f1 has data, but it's a trigger for 'cond'.
          # So it should be included so the user can change it and see 'cond' react.
          fields = service.wizard_fields(skip_filled: true)
          expect(fields).to include(f1)
          expect(fields).to include(conditional_field)
        end
      end
    end
  end

  describe "#filled_fields" do
    it "returns only fields with data" do
      submission.update!(form_data: { "f1" => "data" })
      expect(service.filled_fields).to contain_exactly(f1)
    end
  end

  describe "#empty_fields" do
    it "returns only fields without data" do
      submission.update!(form_data: { "f1" => "data" })
      expect(service.empty_fields).to contain_exactly(f2, f3)
    end
  end
end
