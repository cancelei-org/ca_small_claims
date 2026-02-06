# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormDefinition, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:category).optional }
    it { is_expected.to have_many(:field_definitions).dependent(:destroy) }
    it { is_expected.to have_many(:workflow_steps).dependent(:destroy) }
    it { is_expected.to have_many(:submissions).dependent(:destroy) }
    it { is_expected.to have_many(:session_submissions).dependent(:destroy) }
    it { is_expected.to have_many(:form_feedbacks).dependent(:destroy) }
  end

  describe "validations" do
    # Subject needed for uniqueness test - shoulda-matchers requires a valid record
    subject { build(:form_definition) }

    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:pdf_filename) }
    it { is_expected.to validate_uniqueness_of(:code) }
  end

  describe "#pdf_path" do
    let(:form) { create(:form_definition, pdf_filename: "sc100.pdf") }

    context "when using local storage" do
      before do
        allow(ENV).to receive(:fetch).with("USE_S3_STORAGE", "false").and_return("false")
      end

      it "returns local filesystem path" do
        expect(form.pdf_path).to eq(Rails.root.join("lib", "pdf_templates", "sc100.pdf"))
      end
    end

    context "when using S3 storage" do
      let(:s3_service_double) { instance_double(S3::TemplateService) }
      let(:cached_path) { Rails.root.join("tmp", "cached_templates", "sc100.pdf") }

      before do
        allow(ENV).to receive(:fetch).with("USE_S3_STORAGE", "false").and_return("true")
        allow(S3::TemplateService).to receive(:new).and_return(s3_service_double)
        allow(s3_service_double).to receive(:download_template).with("sc100.pdf").and_return(cached_path)
      end

      it "downloads from S3 and returns cached path" do
        expect(s3_service_double).to receive(:download_template).with("sc100.pdf")

        result = form.pdf_path

        expect(result).to eq(cached_path)
      end
    end
  end

  describe "#pdf_exists?" do
    let(:form) { create(:form_definition, pdf_filename: "sc100.pdf") }

    context "when using local storage" do
      before do
        allow(ENV).to receive(:fetch).with("USE_S3_STORAGE", "false").and_return("false")
      end

      it "checks local filesystem" do
        allow(File).to receive(:exist?).with(Rails.root.join("lib", "pdf_templates", "sc100.pdf")).and_return(true)

        expect(form.pdf_exists?).to be true
      end
    end

    context "when using S3 storage" do
      let(:s3_service_double) { instance_double(S3::TemplateService) }

      before do
        allow(ENV).to receive(:fetch).with("USE_S3_STORAGE", "false").and_return("true")
        allow(S3::TemplateService).to receive(:new).and_return(s3_service_double)
      end

      it "checks S3 for template existence" do
        allow(s3_service_double).to receive(:template_exists?).with("sc100.pdf").and_return(true)

        expect(form.pdf_exists?).to be true
      end

      it "returns false when template not in S3" do
        allow(s3_service_double).to receive(:template_exists?).with("sc100.pdf").and_return(false)

        expect(form.pdf_exists?).to be false
      end
    end
  end

  describe "#generation_strategy" do
    it "returns :form_filling for fillable PDFs" do
      form = create(:form_definition, fillable: true)
      expect(form.generation_strategy).to eq(:form_filling)
    end

    it "returns :html_generation for non-fillable PDFs" do
      form = create(:form_definition, fillable: false)
      expect(form.generation_strategy).to eq(:html_generation)
    end
  end

  describe "#can_generate_pdf?" do
    context "for fillable forms" do
      let(:form) { create(:form_definition, fillable: true, pdf_filename: "sc100.pdf") }

      it "returns true if PDF exists" do
        allow(form).to receive(:pdf_exists?).and_return(true)
        expect(form.can_generate_pdf?).to be true
      end

      it "returns false if PDF does not exist" do
        allow(form).to receive(:pdf_exists?).and_return(false)
        expect(form.can_generate_pdf?).to be false
      end
    end

    context "for non-fillable forms" do
      let(:form) { create(:form_definition, fillable: false) }

      it "returns true if HTML template exists" do
        allow(form).to receive(:html_template_exists?).and_return(true)
        expect(form.can_generate_pdf?).to be true
      end

      it "returns false if HTML template does not exist" do
        allow(form).to receive(:html_template_exists?).and_return(false)
        expect(form.can_generate_pdf?).to be false
      end
    end
  end

  describe "scopes" do
    let!(:active_form) { create(:form_definition, active: true) }
    let!(:inactive_form) { create(:form_definition, active: false) }

    describe ".active" do
      it "returns only active forms" do
        expect(FormDefinition.active).to include(active_form)
        expect(FormDefinition.active).not_to include(inactive_form)
      end
    end

    describe ".search" do
      let!(:plaintiff_form) { create(:form_definition, code: "SC-100", title: "Plaintiff's Claim") }
      let!(:other_form) { create(:form_definition, code: "SC-200", title: "Different Form") }

      it "finds forms by code" do
        expect(FormDefinition.search("SC-100")).to include(plaintiff_form)
        expect(FormDefinition.search("SC-100")).not_to include(other_form)
      end

      it "finds forms by title (case insensitive)" do
        expect(FormDefinition.search("plaintiff")).to include(plaintiff_form)
      end

      it "returns all forms for blank query" do
        result = FormDefinition.search("")
        expect(result).to include(plaintiff_form, other_form)
      end

      it "returns all forms for nil query" do
        result = FormDefinition.search(nil)
        expect(result).to include(plaintiff_form, other_form)
      end
    end

    describe ".by_popularity" do
      let!(:popular_form) { create(:form_definition) }
      let!(:unpopular_form) { create(:form_definition) }

      before do
        create_list(:submission, 10, form_definition: popular_form)
        create(:submission, form_definition: unpopular_form)
      end

      it "orders by submission count" do
        result = FormDefinition.by_popularity.where(id: [ popular_form.id, unpopular_form.id ])
        expect(result.first).to eq(popular_form)
      end
    end
  end

  describe "edge cases" do
    describe "#sections" do
      let(:form) { create(:form_definition) }

      it "handles form with no field definitions" do
        expect(form.sections).to eq({})
      end

      it "groups fields by section" do
        create(:field_definition, form_definition: form, section: "Personal Info", position: 1)
        create(:field_definition, form_definition: form, section: "Personal Info", position: 2)
        create(:field_definition, form_definition: form, section: "Case Details", position: 1)

        sections = form.sections
        expect(sections.keys).to contain_exactly("Personal Info", "Case Details")
        expect(sections["Personal Info"].size).to eq(2)
      end
    end

    describe "#recommended_next_forms" do
      let(:category) { create(:category) }
      let(:form) { create(:form_definition, category: category) }

      it "handles form with no category" do
        form_without_category = create(:form_definition, category: nil)
        result = form_without_category.recommended_next_forms
        expect(result).to be_an(Array)
      end

      it "handles category with no other forms" do
        result = form.recommended_next_forms
        expect(result).to be_an(Array)
      end

      it "excludes self from recommendations" do
        result = form.recommended_next_forms
        expect(result).not_to include(form)
      end
    end

    describe "#feedback_stats" do
      let(:form) { create(:form_definition) }

      it "handles form with no feedback" do
        stats = form.feedback_stats
        expect(stats[:total]).to eq(0)
        expect(stats[:average_rating]).to eq(0)
      end
    end

    describe "#usage_count" do
      let(:form) { create(:form_definition) }

      it "returns 0 for unused form" do
        expect(form.usage_count).to eq(0)
      end

      it "counts both submissions and session_submissions" do
        create_list(:submission, 3, form_definition: form)
        create_list(:session_submission, 2, form_definition: form)
        expect(form.usage_count).to eq(5)
      end
    end

    describe "FriendlyId" do
      it "normalizes special characters in code" do
        form = create(:form_definition, code: "SC-100 (Rev.)")
        expect(form.slug).to match(/sc-100/)
      end

      it "handles duplicate codes gracefully" do
        form1 = create(:form_definition, code: "SC-100")
        form2 = create(:form_definition, code: "SC-100-V2")
        expect(form1.slug).not_to eq(form2.slug)
      end
    end
  end
end
