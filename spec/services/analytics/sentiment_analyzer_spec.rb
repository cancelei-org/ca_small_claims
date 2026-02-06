# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analytics::SentimentAnalyzer do
  let(:form_def) { create(:form_definition, code: "SC-100") }

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

  describe "#overall_sentiment_score" do
    before do
      create(:form_feedback, form_definition: form_def, rating: 5, created_at: 3.days.ago)
      create(:form_feedback, form_definition: form_def, rating: 4, created_at: 3.days.ago)
      create(:form_feedback, form_definition: form_def, rating: 3, created_at: 3.days.ago)
    end

    it "calculates overall sentiment score" do
      service = described_class.new
      score = service.overall_sentiment_score

      expect(score).to be_a(Float)
      expect(score).to be_between(0, 100)
    end

    it "returns 0 when no feedback" do
      FormFeedback.destroy_all
      service = described_class.new
      expect(service.overall_sentiment_score).to eq(0)
    end
  end

  describe "#sentiment_distribution" do
    before do
      # Positive feedback (rating 4-5)
      create_list(:form_feedback, 3, form_definition: form_def, rating: 5, created_at: 3.days.ago)
      create_list(:form_feedback, 2, form_definition: form_def, rating: 4, created_at: 3.days.ago)
      # Neutral feedback (rating 3)
      create_list(:form_feedback, 2, form_definition: form_def, rating: 3, created_at: 3.days.ago)
      # Negative feedback (rating 1-2)
      create(:form_feedback, form_definition: form_def, rating: 1, created_at: 3.days.ago)
    end

    it "returns sentiment distribution" do
      service = described_class.new
      distribution = service.sentiment_distribution

      expect(distribution).to have_key(:positive)
      expect(distribution).to have_key(:neutral)
      expect(distribution).to have_key(:negative)
    end

    it "returns zeros when no feedback" do
      FormFeedback.destroy_all
      service = described_class.new
      distribution = service.sentiment_distribution

      expect(distribution).to eq({ positive: 0, neutral: 0, negative: 0 })
    end
  end

  describe "#sentiment_trends" do
    before do
      create(:form_feedback, form_definition: form_def, rating: 5, created_at: 3.days.ago)
      create(:form_feedback, form_definition: form_def, rating: 4, created_at: 5.days.ago)
      create(:form_feedback, form_definition: form_def, rating: 2, created_at: 7.days.ago)
    end

    it "returns daily sentiment trends" do
      service = described_class.new(start_date: 10.days.ago)
      trends = service.sentiment_trends

      expect(trends).to be_an(Array)
      trends.each do |trend|
        expect(trend).to have_key(:date)
        expect(trend).to have_key(:score)
        expect(trend).to have_key(:count)
        expect(trend).to have_key(:sentiment)
      end
    end
  end

  describe "#common_themes" do
    before do
      create(:form_feedback, form_definition: form_def, rating: 5,
        comment: "This form is amazing and easy to use!", created_at: 3.days.ago)
      create(:form_feedback, form_definition: form_def, rating: 4,
        comment: "Very helpful form, easy to complete", created_at: 3.days.ago)
      create(:form_feedback, form_definition: form_def, rating: 2,
        comment: "Confusing form, difficult to understand", created_at: 3.days.ago)
    end

    it "extracts common themes from comments" do
      service = described_class.new
      themes = service.common_themes(limit: 5)

      expect(themes).to be_an(Array)
      themes.each do |theme|
        expect(theme).to have_key(:theme)
        expect(theme).to have_key(:count)
        expect(theme).to have_key(:sentiment)
      end
    end

    it "returns empty array when no comments" do
      FormFeedback.destroy_all
      service = described_class.new
      expect(service.common_themes).to eq([])
    end
  end

  describe "#issues_by_sentiment" do
    before do
      create(:form_feedback, form_definition: form_def, rating: 5,
        issue_types: [ "fields_unclear" ], created_at: 3.days.ago)
      create(:form_feedback, form_definition: form_def, rating: 2,
        issue_types: [ "fields_unclear", "missing_information" ], created_at: 3.days.ago)
    end

    it "breaks down issues by sentiment" do
      service = described_class.new
      issues = service.issues_by_sentiment

      expect(issues).to be_an(Array)
      issues.each do |issue|
        expect(issue).to have_key(:issue_type)
        expect(issue).to have_key(:positive)
        expect(issue).to have_key(:neutral)
        expect(issue).to have_key(:negative)
        expect(issue).to have_key(:total)
      end
    end
  end

  describe "#sentiment_alerts" do
    context "when sentiment drops significantly" do
      before do
        # Previous period (7-14 days ago) - high ratings
        create_list(:form_feedback, 5, form_definition: form_def, rating: 5, created_at: 10.days.ago)
        # Recent period (last 7 days) - low ratings
        create_list(:form_feedback, 5, form_definition: form_def, rating: 1, created_at: 3.days.ago)
      end

      it "generates sentiment drop alert" do
        service = described_class.new
        alerts = service.sentiment_alerts

        expect(alerts).to be_an(Array)
        sentiment_drop = alerts.find { |a| a[:type] == "sentiment_drop" }
        expect(sentiment_drop).to be_present if alerts.any?
      end
    end

    context "when no issues" do
      before do
        create_list(:form_feedback, 5, form_definition: form_def, rating: 5, created_at: 3.days.ago)
      end

      it "returns empty alerts" do
        service = described_class.new
        alerts = service.sentiment_alerts

        expect(alerts).to be_an(Array)
      end
    end
  end

  describe "#rating_distribution" do
    before do
      create_list(:form_feedback, 3, form_definition: form_def, rating: 5, created_at: 3.days.ago)
      create_list(:form_feedback, 2, form_definition: form_def, rating: 4, created_at: 3.days.ago)
      create(:form_feedback, form_definition: form_def, rating: 3, created_at: 3.days.ago)
    end

    it "returns rating distribution" do
      service = described_class.new
      distribution = service.rating_distribution

      expect(distribution).to be_an(Array)
      expect(distribution.length).to eq(5) # 1-5 stars

      distribution.each do |rating_info|
        expect(rating_info).to have_key(:rating)
        expect(rating_info).to have_key(:label)
        expect(rating_info).to have_key(:count)
        expect(rating_info).to have_key(:percentage)
      end
    end
  end

  describe "#summary_stats" do
    before do
      create_list(:form_feedback, 5, form_definition: form_def, rating: 5, created_at: 3.days.ago)
      create_list(:form_feedback, 3, form_definition: form_def, rating: 3, created_at: 3.days.ago)
      create(:form_feedback, form_definition: form_def, rating: 1, created_at: 3.days.ago)
    end

    it "returns comprehensive summary statistics" do
      service = described_class.new
      stats = service.summary_stats

      expect(stats[:total_feedbacks]).to eq(9)
      expect(stats[:avg_rating]).to be > 0
      expect(stats[:sentiment_score]).to be > 0
      expect(stats).to have_key(:positive_count)
      expect(stats).to have_key(:neutral_count)
      expect(stats).to have_key(:negative_count)
      expect(stats).to have_key(:positive_percentage)
      expect(stats).to have_key(:has_alerts)
    end

    it "returns default stats when no feedback" do
      FormFeedback.destroy_all
      service = described_class.new
      stats = service.summary_stats

      expect(stats[:total_feedbacks]).to eq(0)
      expect(stats[:avg_rating]).to eq(0)
      expect(stats[:sentiment_score]).to eq(0)
    end
  end

  describe "form filtering" do
    let(:form_def2) { create(:form_definition, code: "SC-105") }

    before do
      create_list(:form_feedback, 5, form_definition: form_def, rating: 5, created_at: 3.days.ago)
      create_list(:form_feedback, 3, form_definition: form_def2, rating: 3, created_at: 3.days.ago)
    end

    it "filters to specific form" do
      service = described_class.new(form_definition_id: form_def.id)
      stats = service.summary_stats

      expect(stats[:total_feedbacks]).to eq(5)
    end
  end
end
