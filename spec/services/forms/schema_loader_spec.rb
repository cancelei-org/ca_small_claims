# frozen_string_literal: true

require "rails_helper"

RSpec.describe Forms::SchemaLoader do
  describe ".sync_form" do
    let(:code) { "SC-100" }
    let(:schema) do
      {
        form: {
          title: "Plaintiff's Claim",
          description: "Description",
          category: "small-claims",
          fillable: true
        },
        sections: {
          info: {
            fields: [
              { name: "f1", type: "text", label: "L1" }
            ]
          }
        }
      }
    end

    let!(:category) { create(:category, slug: "small-claims") }

    it "creates form definition and fields" do
      expect {
        described_class.sync_form(code, schema)
      }.to change(FormDefinition, :count).by(1).and change(FieldDefinition, :count).by(1)

      form = FormDefinition.find_by(code: code)
      expect(form.title).to eq("Plaintiff's Claim")
      expect(form.category).to eq(category)
      expect(form.field_definitions.first.name).to eq("f1")
    end

    it "updates existing form if it already exists" do
      form = create(:form_definition, code: code, title: "Old Title")
      described_class.sync_form(code, schema)
      expect(form.reload.title).to eq("Plaintiff's Claim")
    end

    it "removes fields that are no longer in schema" do
      form = create(:form_definition, code: code)
      create(:field_definition, form_definition: form, name: "old_field")

      described_class.sync_form(code, schema)
      expect(form.field_definitions.where(name: "old_field")).not_to exist
    end
  end

  describe ".find_category" do
    let!(:cat) { create(:category, slug: "small-claims") }

    it "finds by direct slug" do
      expect(described_class.find_category("small-claims")).to eq(cat)
    end

    it "finds by path-like string" do
      expect(described_class.find_category("legal/small_claims")).to eq(cat)
    end

    it "returns nil if not found" do
      expect(described_class.find_category("unknown")).to be_nil
    end
  end
end
