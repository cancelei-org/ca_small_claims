# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analytics::DropOffAnalyzer do
  let(:form_def) { create(:form_definition, code: "SC-100") }
  let(:field1) { create(:field_definition, form_definition: form_def, name: "plaintiff_name", position: 1) }
  let(:field2) { create(:field_definition, form_definition: form_def, name: "defendant_name", position: 2) }
  let(:field3) { create(:field_definition, form_definition: form_def, name: "claim_amount", position: 3, required: true) }

  before do
    travel_to Time.zone.local(2024, 3, 15, 12, 0, 0)
    # Ensure fields exist
    field1
    field2
    field3
  end

  after do
    travel_back
  end

  describe "#initialize" do
    it "uses default date range of 30 days" do
      service = described_class.new
      expect(service.start_date).to eq(30.days.ago.to_date.beginning_of_day)
      expect(service.end_date).to eq(Time.current.to_date.end_of_day)
    end

    it "accepts custom date range" do
      service = described_class.new(
        start_date: "2024-03-01",
        end_date: "2024-03-10"
      )
      expect(service.start_date).to eq(Date.parse("2024-03-01").beginning_of_day)
      expect(service.end_date).to eq(Date.parse("2024-03-10").end_of_day)
    end

    it "accepts form definition filter" do
      service = described_class.new(form_definition_id: form_def.id)
      expect(service.form_definition_id).to eq(form_def.id)
    end
  end

  describe "#abandoned_submissions" do
    before do
      # Abandoned (draft, not updated in 24+ hours)
      create(:submission, form_definition: form_def, status: "draft",
        created_at: 5.days.ago, updated_at: 3.days.ago)
      create(:submission, form_definition: form_def, status: "draft",
        created_at: 4.days.ago, updated_at: 2.days.ago)

      # Not abandoned (draft, updated recently)
      create(:submission, form_definition: form_def, status: "draft",
        created_at: 3.days.ago, updated_at: 10.hours.ago)

      # Not abandoned (completed)
      create(:submission, form_definition: form_def, status: "completed",
        created_at: 5.days.ago, updated_at: 3.days.ago)
    end

    it "returns only abandoned draft submissions" do
      service = described_class.new
      abandoned = service.abandoned_submissions

      expect(abandoned.count).to eq(2)
      expect(abandoned.all? { |s| s.status == "draft" }).to be true
    end
  end

  describe "#abandonment_count" do
    before do
      create_list(:submission, 3, form_definition: form_def, status: "draft",
        created_at: 5.days.ago, updated_at: 3.days.ago)
    end

    it "returns count of abandoned submissions" do
      service = described_class.new
      expect(service.abandonment_count).to eq(3)
    end
  end

  describe "#abandonment_rate" do
    before do
      # 2 abandoned
      create_list(:submission, 2, form_definition: form_def, status: "draft",
        created_at: 5.days.ago, updated_at: 3.days.ago)
      # 3 completed
      create_list(:submission, 3, form_definition: form_def, status: "completed",
        created_at: 5.days.ago)
      # 1 active draft
      create(:submission, form_definition: form_def, status: "draft",
        created_at: 3.days.ago, updated_at: 10.hours.ago)
    end

    it "calculates abandonment rate as percentage" do
      service = described_class.new
      rate = service.abandonment_rate

      # 2 abandoned out of 6 total = 33.3%
      expect(rate).to eq(33.3)
    end

    it "returns 0 when no submissions" do
      Submission.destroy_all
      service = described_class.new
      expect(service.abandonment_rate).to eq(0)
    end
  end

  describe "#last_field_before_drop_off" do
    before do
      # Dropped at plaintiff_name
      create(:submission, form_definition: form_def, status: "draft",
        form_data: { "plaintiff_name" => "John" },
        created_at: 5.days.ago, updated_at: 3.days.ago)

      # Dropped at defendant_name
      create(:submission, form_definition: form_def, status: "draft",
        form_data: { "plaintiff_name" => "Jane", "defendant_name" => "Bob" },
        created_at: 5.days.ago, updated_at: 3.days.ago)

      # Another dropped at defendant_name
      create(:submission, form_definition: form_def, status: "draft",
        form_data: { "plaintiff_name" => "Alice", "defendant_name" => "Charlie" },
        created_at: 5.days.ago, updated_at: 3.days.ago)
    end

    it "identifies last field completed before abandonment" do
      service = described_class.new(form_definition_id: form_def.id)
      last_fields = service.last_field_before_drop_off

      expect(last_fields["defendant_name"]).to eq(2)
      expect(last_fields["plaintiff_name"]).to eq(1)
    end
  end

  describe "#average_time_before_abandonment" do
    before do
      # 10 minute session before abandonment
      create(:submission, form_definition: form_def, status: "draft",
        created_at: 5.days.ago, updated_at: 5.days.ago + 10.minutes)
      # 20 minute session before abandonment
      create(:submission, form_definition: form_def, status: "draft",
        created_at: 5.days.ago, updated_at: 5.days.ago + 20.minutes)
    end

    it "calculates average time in minutes" do
      service = described_class.new
      avg_time = service.average_time_before_abandonment

      expect(avg_time).to eq(15) # (10 + 20) / 2
    end

    it "returns 0 when no abandoned submissions" do
      Submission.destroy_all
      service = described_class.new
      expect(service.average_time_before_abandonment).to eq(0)
    end
  end

  describe "#time_before_drop_off_distribution" do
    before do
      # Various session lengths before abandonment
      create(:submission, form_definition: form_def, status: "draft",
        created_at: 5.days.ago, updated_at: 5.days.ago + 3.minutes)  # 0-5 bucket
      create(:submission, form_definition: form_def, status: "draft",
        created_at: 5.days.ago, updated_at: 5.days.ago + 7.minutes)  # 5-10 bucket
      create(:submission, form_definition: form_def, status: "draft",
        created_at: 5.days.ago, updated_at: 5.days.ago + 25.minutes) # 15-30 bucket
    end

    it "groups times into buckets" do
      service = described_class.new
      distribution = service.time_before_drop_off_distribution

      expect(distribution["0-5 min"]).to eq(1)
      expect(distribution["5-10 min"]).to eq(1)
      expect(distribution["15-30 min"]).to eq(1)
    end

    it "returns empty hash when no abandoned submissions" do
      Submission.destroy_all
      service = described_class.new
      expect(service.time_before_drop_off_distribution).to eq({})
    end
  end

  describe "#abandonment_by_form" do
    let(:form_def2) { create(:form_definition, code: "SC-105", active: true) }

    before do
      # SC-100: 3 abandoned, 5 total
      create_list(:submission, 3, form_definition: form_def, status: "draft",
        created_at: 5.days.ago, updated_at: 3.days.ago)
      create_list(:submission, 2, form_definition: form_def, status: "completed",
        created_at: 5.days.ago)

      # SC-105: 2 abandoned, 10 total
      create_list(:submission, 2, form_definition: form_def2, status: "draft",
        created_at: 5.days.ago, updated_at: 3.days.ago)
      create_list(:submission, 8, form_definition: form_def2, status: "completed",
        created_at: 5.days.ago)
    end

    it "compares abandonment across forms" do
      service = described_class.new
      by_form = service.abandonment_by_form(limit: 10)

      expect(by_form).to be_an(Array)
      expect(by_form.first[:form_code]).to eq("SC-100") # Higher count
      expect(by_form.first[:abandonment_count]).to eq(3)
      expect(by_form.first[:abandonment_rate]).to be > 0
    end
  end

  describe "#completion_percentage_at_abandonment" do
    before do
      # Create submissions with different completion levels
      # This relies on the submission's completion_percentage method
      create(:submission, form_definition: form_def, status: "draft",
        form_data: {},  # 0%
        created_at: 5.days.ago, updated_at: 3.days.ago)
      create(:submission, form_definition: form_def, status: "draft",
        form_data: { "plaintiff_name" => "John" },  # ~33%
        created_at: 5.days.ago, updated_at: 3.days.ago)
    end

    it "distributes abandonment by completion percentage" do
      service = described_class.new(form_definition_id: form_def.id)
      distribution = service.completion_percentage_at_abandonment

      expect(distribution).to be_a(Hash)
    end
  end

  describe "#field_abandonment_stats" do
    before do
      # Dropped at different fields
      create(:submission, form_definition: form_def, status: "draft",
        form_data: { "plaintiff_name" => "John" },
        created_at: 5.days.ago, updated_at: 3.days.ago)
      create(:submission, form_definition: form_def, status: "draft",
        form_data: { "plaintiff_name" => "Jane", "defendant_name" => "Bob" },
        created_at: 5.days.ago, updated_at: 3.days.ago)
    end

    it "returns field-level abandonment statistics" do
      service = described_class.new(form_definition_id: form_def.id)
      stats = service.field_abandonment_stats

      expect(stats).to be_an(Array)
      stats.each do |stat|
        expect(stat).to have_key(:field_name)
        expect(stat).to have_key(:abandonment_count)
        expect(stat).to have_key(:abandonment_percentage)
      end
    end

    it "returns empty array without form_definition_id" do
      service = described_class.new
      expect(service.field_abandonment_stats).to eq([])
    end
  end

  describe "#problematic_fields" do
    before do
      create_list(:submission, 5, form_definition: form_def, status: "draft",
        form_data: { "plaintiff_name" => "John" },
        created_at: 5.days.ago, updated_at: 3.days.ago)
    end

    it "returns top N problematic fields" do
      service = described_class.new(form_definition_id: form_def.id)
      problematic = service.problematic_fields(limit: 3)

      expect(problematic.length).to be <= 3
    end
  end

  describe "#field_suggestions" do
    before do
      # Create high abandonment at required field
      create_list(:submission, 10, form_definition: form_def, status: "draft",
        form_data: { "plaintiff_name" => "John", "defendant_name" => "Bob" },
        created_at: 5.days.ago, updated_at: 3.days.ago)
    end

    it "generates suggestions for problematic fields" do
      service = described_class.new(form_definition_id: form_def.id)
      suggestions = service.field_suggestions

      expect(suggestions).to be_an(Array)
      suggestions.each do |suggestion|
        expect(suggestion).to have_key(:field_name)
        expect(suggestion).to have_key(:suggestions)
      end
    end
  end

  describe "form filtering" do
    let(:form_def2) { create(:form_definition, code: "SC-105") }

    before do
      create_list(:submission, 3, form_definition: form_def, status: "draft",
        created_at: 5.days.ago, updated_at: 3.days.ago)
      create_list(:submission, 5, form_definition: form_def2, status: "draft",
        created_at: 5.days.ago, updated_at: 3.days.ago)
    end

    it "filters to specific form" do
      service = described_class.new(form_definition_id: form_def.id)
      expect(service.abandonment_count).to eq(3)
    end
  end
end
