# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analytics::TimeMetrics do
  let(:form_def) { create(:form_definition, code: "SC-100", active: true) }
  let(:workflow) { create(:workflow) }

  before do
    travel_to Time.zone.local(2024, 3, 15, 12, 0, 0)
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

  describe "#completion_times" do
    before do
      # 15 minute completion
      create(:submission, form_definition: form_def, status: "completed",
        created_at: 3.days.ago, completed_at: 3.days.ago + 15.minutes)
      # 30 minute completion
      create(:submission, form_definition: form_def, status: "completed",
        created_at: 3.days.ago, completed_at: 3.days.ago + 30.minutes)
      # Draft (not completed)
      create(:submission, form_definition: form_def, status: "draft",
        created_at: 3.days.ago)
    end

    it "returns completion times for completed submissions" do
      service = described_class.new
      times = service.completion_times

      expect(times.length).to eq(2)
      expect(times.first).to have_key(:id)
      expect(times.first).to have_key(:minutes)
    end
  end

  describe "#statistics" do
    before do
      # Various completion times
      [ 10, 15, 20, 25, 30, 35, 40, 45, 60, 90 ].each do |mins|
        create(:submission, form_definition: form_def, status: "completed",
          created_at: 3.days.ago, completed_at: 3.days.ago + mins.minutes)
      end
    end

    it "calculates statistical metrics" do
      service = described_class.new
      stats = service.statistics

      expect(stats[:count]).to eq(10)
      expect(stats[:min]).to eq(10)
      expect(stats[:max]).to eq(90)
      expect(stats).to have_key(:mean)
      expect(stats).to have_key(:median)
      expect(stats).to have_key(:p25)
      expect(stats).to have_key(:p75)
      expect(stats).to have_key(:p90)
      expect(stats).to have_key(:p95)
      expect(stats).to have_key(:p99)
    end

    it "returns empty hash when no completions" do
      Submission.destroy_all
      service = described_class.new
      expect(service.statistics).to eq({})
    end
  end

  describe "#time_distribution" do
    before do
      # Various completion times
      [ 3, 7, 12, 18, 25 ].each do |mins|
        create(:submission, form_definition: form_def, status: "completed",
          created_at: 3.days.ago, completed_at: 3.days.ago + mins.minutes)
      end
    end

    it "groups times into buckets" do
      service = described_class.new
      distribution = service.time_distribution(bucket_size: 10)

      expect(distribution).to be_a(Hash)
      expect(distribution.keys.first).to match(/\d+-\d+ min/)
    end

    it "returns empty hash when no completions" do
      Submission.destroy_all
      service = described_class.new
      expect(service.time_distribution).to eq({})
    end
  end

  describe "#metrics_by_form" do
    let(:form_def2) { create(:form_definition, code: "SC-105", active: true) }

    before do
      # SC-100 - 5 completions
      5.times do
        create(:submission, form_definition: form_def, status: "completed",
          created_at: 3.days.ago, completed_at: 3.days.ago + 20.minutes)
      end
      # SC-105 - 3 completions
      3.times do
        create(:submission, form_definition: form_def2, status: "completed",
          created_at: 3.days.ago, completed_at: 3.days.ago + 30.minutes)
      end
    end

    it "returns metrics per form" do
      service = described_class.new
      by_form = service.metrics_by_form(limit: 5)

      expect(by_form).to be_an(Array)
      expect(by_form.first[:form_code]).to eq("SC-100") # More completions

      by_form.each do |form_metrics|
        expect(form_metrics).to have_key(:form_code)
        expect(form_metrics).to have_key(:completion_count)
        expect(form_metrics).to have_key(:median_time)
        expect(form_metrics).to have_key(:mean_time)
      end
    end
  end

  describe "#time_trends" do
    before do
      # Create completions across different periods
      [ 3, 10, 17, 24 ].each do |days_ago|
        create(:submission, form_definition: form_def, status: "completed",
          created_at: days_ago.days.ago, completed_at: days_ago.days.ago + 20.minutes)
      end
    end

    it "returns time trends over periods" do
      service = described_class.new
      trends = service.time_trends(periods: 4, period_length: 7.days)

      expect(trends).to be_an(Array)
      expect(trends.length).to eq(4)

      trends.each do |trend|
        expect(trend).to have_key(:period)
        expect(trend).to have_key(:count)
        expect(trend).to have_key(:median)
        expect(trend).to have_key(:mean)
      end
    end
  end

  describe "#mode_comparison" do
    before do
      # Wizard mode completions
      3.times do
        create(:submission, form_definition: form_def, workflow: workflow, status: "completed",
          created_at: 3.days.ago, completed_at: 3.days.ago + 15.minutes)
      end
      # Traditional mode completions
      2.times do
        create(:submission, form_definition: form_def, workflow: nil, status: "completed",
          created_at: 3.days.ago, completed_at: 3.days.ago + 25.minutes)
      end
    end

    it "compares wizard vs traditional completion times" do
      service = described_class.new(form_definition_id: form_def.id)
      comparison = service.mode_comparison

      expect(comparison).to have_key(:wizard)
      expect(comparison).to have_key(:traditional)

      expect(comparison[:wizard][:count]).to eq(3)
      expect(comparison[:traditional][:count]).to eq(2)

      # Wizard should be faster
      expect(comparison[:wizard][:median]).to be < comparison[:traditional][:median]
    end
  end

  describe "#outliers" do
    before do
      # Very fast
      create(:submission, form_definition: form_def, status: "completed",
        created_at: 3.days.ago, completed_at: 3.days.ago + 5.minutes)
      # Normal
      create(:submission, form_definition: form_def, status: "completed",
        created_at: 3.days.ago, completed_at: 3.days.ago + 20.minutes)
      # Very slow
      create(:submission, form_definition: form_def, status: "completed",
        created_at: 3.days.ago, completed_at: 3.days.ago + 120.minutes)
    end

    it "identifies fastest and slowest completions" do
      service = described_class.new
      outliers = service.outliers

      expect(outliers).to have_key(:fastest)
      expect(outliers).to have_key(:slowest)

      expect(outliers[:fastest].first[:minutes]).to eq(5)
      expect(outliers[:slowest].first[:minutes]).to eq(120)
    end

    it "returns empty arrays when no completions" do
      Submission.destroy_all
      service = described_class.new
      outliers = service.outliers

      expect(outliers[:fastest]).to eq([])
      expect(outliers[:slowest]).to eq([])
    end
  end

  describe "form filtering" do
    let(:form_def2) { create(:form_definition, code: "SC-105") }

    before do
      create_list(:submission, 5, form_definition: form_def, status: "completed",
        created_at: 3.days.ago, completed_at: 3.days.ago + 20.minutes)
      create_list(:submission, 3, form_definition: form_def2, status: "completed",
        created_at: 3.days.ago, completed_at: 3.days.ago + 30.minutes)
    end

    it "filters to specific form" do
      service = described_class.new(form_definition_id: form_def.id)
      times = service.completion_times

      expect(times.length).to eq(5)
    end
  end
end
