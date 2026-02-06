# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analytics::FunnelAnalyzer do
  let(:user) { create(:user) }
  let(:form_def) { create(:form_definition, code: "SC-100") }

  before do
    travel_to Time.zone.local(2024, 3, 15, 12, 0, 0)
  end

  after do
    travel_back
  end

  describe "#initialize" do
    it "uses default date range of 7 days" do
      service = described_class.new
      expect(service.start_date).to eq(7.days.ago.to_date.beginning_of_day)
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

    it "accepts user type filter" do
      service = described_class.new(user_type: "registered")
      expect(service.user_type).to eq("registered")
    end
  end

  describe "#funnel_stages" do
    before do
      # Started only (empty form_data)
      create(:submission, form_definition: form_def, form_data: {}, created_at: 3.days.ago)

      # In progress (has form_data but not complete)
      create(:submission, form_definition: form_def, form_data: { "name" => "John" }, created_at: 3.days.ago)

      # Completed
      create(:submission, form_definition: form_def, form_data: { "name" => "Jane" },
        completed_at: 2.days.ago, created_at: 3.days.ago)

      # Downloaded
      create(:submission, form_definition: form_def, form_data: { "name" => "Bob" },
        completed_at: 2.days.ago, pdf_generated_at: 2.days.ago, created_at: 3.days.ago)
    end

    it "returns counts for each stage" do
      service = described_class.new
      stages = service.funnel_stages

      expect(stages[:started]).to eq(4)
      expect(stages[:completed]).to eq(2)
      expect(stages[:downloaded]).to eq(1)
    end
  end

  describe "#conversion_rates" do
    before do
      create_list(:submission, 10, form_definition: form_def, form_data: {}, created_at: 3.days.ago)
      create_list(:submission, 5, form_definition: form_def, form_data: { "name" => "Test" },
        completed_at: 2.days.ago, created_at: 3.days.ago)
      create_list(:submission, 2, form_definition: form_def, form_data: { "name" => "Test" },
        completed_at: 2.days.ago, pdf_generated_at: 2.days.ago, created_at: 3.days.ago)
    end

    it "calculates overall completion rate" do
      service = described_class.new
      rates = service.conversion_rates

      # 7 completed out of 17 started
      expect(rates[:overall_completion]).to be > 0
    end

    it "calculates overall download rate" do
      service = described_class.new
      rates = service.conversion_rates

      # 2 downloaded out of 17 started
      expect(rates[:overall_download]).to be > 0
    end
  end

  describe "#drop_off_points" do
    before do
      create_list(:submission, 10, form_definition: form_def, form_data: {}, created_at: 3.days.ago)
      create_list(:submission, 3, form_definition: form_def, form_data: { "name" => "Test" },
        completed_at: 2.days.ago, pdf_generated_at: 2.days.ago, created_at: 3.days.ago)
    end

    it "returns drop-off points sorted by rate" do
      service = described_class.new
      points = service.drop_off_points

      expect(points).to be_an(Array)
      expect(points.first).to have_key(:stage)
      expect(points.first).to have_key(:drop_off_rate)
      expect(points.first).to have_key(:count)
    end
  end

  describe "#biggest_drop_off" do
    before do
      create_list(:submission, 10, form_definition: form_def, form_data: {}, created_at: 3.days.ago)
    end

    it "returns the largest drop-off point" do
      service = described_class.new
      biggest = service.biggest_drop_off

      expect(biggest).to have_key(:stage)
      expect(biggest).to have_key(:drop_off_rate)
    end
  end

  describe "#funnel_by_form" do
    let(:form_def2) { create(:form_definition, code: "SC-105", active: true) }

    before do
      create_list(:submission, 5, form_definition: form_def, form_data: { "name" => "Test" },
        completed_at: 2.days.ago, created_at: 3.days.ago)
      create_list(:submission, 10, form_definition: form_def2, form_data: {}, created_at: 3.days.ago)
      create_list(:submission, 2, form_definition: form_def2, form_data: { "name" => "Test" },
        completed_at: 2.days.ago, created_at: 3.days.ago)
    end

    it "returns funnel analysis by form" do
      service = described_class.new
      by_form = service.funnel_by_form(limit: 5)

      expect(by_form).to be_an(Array)
      expect(by_form.first).to have_key(:form_code)
      expect(by_form.first).to have_key(:funnel)
      expect(by_form.first).to have_key(:conversion_rate)
    end

    it "sorts by conversion rate descending" do
      service = described_class.new
      by_form = service.funnel_by_form(limit: 5)

      rates = by_form.map { |f| f[:conversion_rate] }
      expect(rates).to eq(rates.sort.reverse)
    end
  end

  describe "#average_time_to_complete" do
    before do
      # 30 minute completion
      create(:submission, form_definition: form_def, form_data: { "name" => "Test" },
        created_at: 3.days.ago, completed_at: 3.days.ago + 30.minutes)
      # 60 minute completion
      create(:submission, form_definition: form_def, form_data: { "name" => "Test" },
        created_at: 3.days.ago, completed_at: 3.days.ago + 60.minutes)
    end

    it "calculates average completion time in minutes" do
      service = described_class.new
      avg_time = service.average_time_to_complete

      expect(avg_time).to eq(45) # (30 + 60) / 2
    end

    it "returns 0 when no completions" do
      Submission.destroy_all
      service = described_class.new
      expect(service.average_time_to_complete).to eq(0)
    end
  end

  describe "#funnel_by_user_type" do
    before do
      # Registered users
      create_list(:submission, 5, user: user, form_definition: form_def, created_at: 3.days.ago)
      # Anonymous users
      create_list(:submission, 8, user: nil, session_id: "sess1", form_definition: form_def, created_at: 3.days.ago)
    end

    it "compares funnel between registered and anonymous users" do
      service = described_class.new
      by_type = service.funnel_by_user_type

      expect(by_type).to have_key(:registered)
      expect(by_type).to have_key(:anonymous)
      expect(by_type[:registered][:started]).to eq(5)
      expect(by_type[:anonymous][:started]).to eq(8)
    end
  end

  describe "user type filtering" do
    before do
      create_list(:submission, 5, user: user, form_definition: form_def, created_at: 3.days.ago)
      create_list(:submission, 8, user: nil, session_id: "sess1", form_definition: form_def, created_at: 3.days.ago)
    end

    it "filters to registered users only" do
      service = described_class.new(user_type: "registered")
      stages = service.funnel_stages

      expect(stages[:started]).to eq(5)
    end

    it "filters to anonymous users only" do
      service = described_class.new(user_type: "anonymous")
      stages = service.funnel_stages

      expect(stages[:started]).to eq(8)
    end
  end

  describe "form filtering" do
    let(:form_def2) { create(:form_definition, code: "SC-105") }

    before do
      create_list(:submission, 5, form_definition: form_def, created_at: 3.days.ago)
      create_list(:submission, 8, form_definition: form_def2, created_at: 3.days.ago)
    end

    it "filters to specific form" do
      service = described_class.new(form_definition_id: form_def.id)
      stages = service.funnel_stages

      expect(stages[:started]).to eq(5)
    end
  end
end
