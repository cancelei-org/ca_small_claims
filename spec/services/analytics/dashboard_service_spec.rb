# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analytics::DashboardService do
  let(:user) { create(:user) }
  let(:form_def) { create(:form_definition, code: "SC-100") }

  before do
    # Travel to a fixed date for consistent testing
    travel_to Time.zone.local(2024, 3, 15, 12, 0, 0)
  end

  after do
    travel_back
  end

  describe "#initialize" do
    it "uses default period of 30 days" do
      service = described_class.new
      expect(service.period).to eq("30d")
      expect(service.end_date).to eq(Date.current)
      expect(service.start_date).to eq(Date.current - 29.days)
    end

    it "accepts custom period" do
      service = described_class.new(period: "7d")
      expect(service.period).to eq("7d")
      expect(service.start_date).to eq(Date.current - 6.days)
    end

    it "accepts custom date range" do
      service = described_class.new(
        start_date: "2024-03-01",
        end_date: "2024-03-10"
      )
      expect(service.start_date).to eq(Date.parse("2024-03-01"))
      expect(service.end_date).to eq(Date.parse("2024-03-10"))
    end

    it "handles invalid dates gracefully" do
      service = described_class.new(start_date: "invalid", end_date: "also-invalid")
      expect(service.end_date).to eq(Date.current)
      expect(service.start_date).to be_a(Date)
    end
  end

  describe "#summary_stats" do
    before do
      # Create submissions across different statuses
      create_list(:submission, 5, form_definition: form_def, status: "completed", user: user, created_at: 5.days.ago)
      create_list(:submission, 3, form_definition: form_def, status: "draft", user: user, created_at: 3.days.ago)
      create_list(:submission, 2, form_definition: form_def, status: "completed", user: nil, session_id: "session1", created_at: 2.days.ago)
    end

    it "returns correct summary statistics" do
      service = described_class.new(period: "7d")
      stats = service.summary_stats

      expect(stats[:total_submissions]).to eq(10)
      expect(stats[:completed_submissions]).to eq(7)
      expect(stats[:draft_submissions]).to eq(3)
      expect(stats[:completion_rate]).to eq(70.0)
      expect(stats[:unique_users]).to eq(1)
      expect(stats[:anonymous_sessions]).to eq(1)
    end

    it "handles zero submissions" do
      Submission.destroy_all
      service = described_class.new(period: "7d")
      stats = service.summary_stats

      expect(stats[:total_submissions]).to eq(0)
      expect(stats[:completion_rate]).to eq(0)
    end
  end

  describe "#period_comparison" do
    before do
      # Current period (last 7 days)
      create_list(:submission, 5, form_definition: form_def, status: "completed", created_at: 3.days.ago)

      # Previous period (7-14 days ago)
      create_list(:submission, 3, form_definition: form_def, status: "completed", created_at: 10.days.ago)
    end

    it "calculates percentage changes correctly" do
      service = described_class.new(period: "7d")
      comparison = service.period_comparison

      # 5 vs 3 = 67% increase
      expect(comparison[:submissions_change]).to eq(67)
      expect(comparison[:completions_change]).to eq(67)
    end

    it "handles zero previous period" do
      Submission.where("created_at < ?", 7.days.ago).destroy_all
      service = described_class.new(period: "7d")
      comparison = service.period_comparison

      expect(comparison[:submissions_change]).to eq(0)
    end
  end

  describe "#daily_submissions" do
    before do
      create(:submission, form_definition: form_def, created_at: 3.days.ago)
      create_list(:submission, 2, form_definition: form_def, created_at: 2.days.ago)
      create(:submission, form_definition: form_def, created_at: 1.day.ago)
    end

    it "groups submissions by day" do
      service = described_class.new(period: "7d")
      daily = service.daily_submissions

      expect(daily[3.days.ago.to_date]).to eq(1)
      expect(daily[2.days.ago.to_date]).to eq(2)
      expect(daily[1.day.ago.to_date]).to eq(1)
    end

    it "fills in missing dates with zero" do
      service = described_class.new(period: "7d")
      daily = service.daily_submissions

      expect(daily[5.days.ago.to_date]).to eq(0)
      expect(daily[4.days.ago.to_date]).to eq(0)
      expect(daily.keys.size).to eq(7)
    end
  end

  describe "#daily_completions" do
    before do
      create(:submission, form_definition: form_def, status: "completed", created_at: 2.days.ago)
      create(:submission, form_definition: form_def, status: "draft", created_at: 2.days.ago)
      create(:submission, form_definition: form_def, status: "completed", created_at: 1.day.ago)
    end

    it "only counts completed submissions" do
      service = described_class.new(period: "7d")
      completions = service.daily_completions

      expect(completions[2.days.ago.to_date]).to eq(1)
      expect(completions[1.day.ago.to_date]).to eq(1)
    end
  end

  describe "#popular_forms" do
    let(:form_def2) { create(:form_definition, code: "SC-120") }

    before do
      # SC-100: 5 total (3 completed)
      create_list(:submission, 3, form_definition: form_def, status: "completed", created_at: 2.days.ago)
      create_list(:submission, 2, form_definition: form_def, status: "draft", created_at: 2.days.ago)

      # SC-120: 2 total (1 completed)
      create(:submission, form_definition: form_def2, status: "completed", created_at: 3.days.ago)
      create(:submission, form_definition: form_def2, status: "draft", created_at: 3.days.ago)
    end

    it "returns forms ordered by usage" do
      service = described_class.new(period: "7d")
      popular = service.popular_forms

      expect(popular.first[:code]).to eq("SC-100")
      expect(popular.first[:count]).to eq(5)
      expect(popular.first[:completion_rate]).to eq(60)

      expect(popular.second[:code]).to eq("SC-120")
      expect(popular.second[:count]).to eq(2)
      expect(popular.second[:completion_rate]).to eq(50)
    end

    it "calculates trends correctly" do
      # Add previous period data for SC-100
      create_list(:submission, 2, form_definition: form_def, created_at: 10.days.ago)

      service = described_class.new(period: "7d")
      popular = service.popular_forms

      expect(popular.first[:trend]).to eq(:up)
    end

    it "respects limit parameter" do
      service = described_class.new(period: "7d")
      popular = service.popular_forms(limit: 1)

      expect(popular.size).to eq(1)
    end
  end

  describe "#status_breakdown" do
    before do
      create_list(:submission, 5, form_definition: form_def, status: "completed", created_at: 2.days.ago)
      create_list(:submission, 3, form_definition: form_def, status: "draft", created_at: 2.days.ago)
      create(:submission, form_definition: form_def, status: "submitted", created_at: 2.days.ago)
    end

    it "returns counts by status" do
      service = described_class.new(period: "7d")
      breakdown = service.status_breakdown

      expect(breakdown[:completed]).to eq(5)
      expect(breakdown[:draft]).to eq(3)
      expect(breakdown[:submitted]).to eq(1)
    end
  end

  describe "#hourly_activity" do
    before do
      create(:submission, form_definition: form_def, created_at: Time.zone.local(2024, 3, 14, 9, 0, 0))
      create_list(:submission, 2, form_definition: form_def, created_at: Time.zone.local(2024, 3, 14, 14, 30, 0))
    end

    it "groups by hour of day" do
      service = described_class.new(period: "7d")
      hourly = service.hourly_activity

      expect(hourly[9]).to eq(1)
      expect(hourly[14]).to eq(2)
      expect(hourly[10]).to eq(0)
    end

    it "includes all 24 hours" do
      service = described_class.new(period: "7d")
      hourly = service.hourly_activity

      expect(hourly.keys.size).to eq(24)
      expect(hourly.keys).to match_array((0..23).to_a)
    end
  end

  describe "#weekly_activity" do
    before do
      # Create submissions on different days of the week
      # March 14, 2024 is Thursday (4)
      create(:submission, form_definition: form_def, created_at: Time.zone.local(2024, 3, 14, 12, 0, 0)) # Thursday
      create_list(:submission, 2, form_definition: form_def, created_at: Time.zone.local(2024, 3, 10, 12, 0, 0)) # Sunday
    end

    it "groups by day of week" do
      service = described_class.new(period: "7d")
      weekly = service.weekly_activity

      expect(weekly["Sunday"]).to eq(2)
      expect(weekly["Thursday"]).to eq(1)
      expect(weekly["Monday"]).to eq(0)
    end

    it "includes all 7 days" do
      service = described_class.new(period: "7d")
      weekly = service.weekly_activity

      expect(weekly.keys.size).to eq(7)
    end
  end

  describe "memoization" do
    it "caches results for expensive queries" do
      service = described_class.new(period: "7d")

      # First call
      first_result = service.summary_stats
      # Second call should return same object (memoized)
      second_result = service.summary_stats

      expect(first_result.object_id).to eq(second_result.object_id)
    end
  end
end
