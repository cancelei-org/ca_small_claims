# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analytics::GeographicAnalyzer do
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
  end

  describe "#usage_by_county" do
    let(:la_user) { create(:user, city: "Los Angeles") }
    let(:sf_user) { create(:user, city: "San Francisco") }
    let(:sd_user) { create(:user, city: "San Diego") }

    before do
      # Los Angeles - 5 submissions, 3 completed
      create_list(:submission, 3, user: la_user, form_definition: form_def,
        status: "completed", completed_at: 3.days.ago, created_at: 3.days.ago)
      create_list(:submission, 2, user: la_user, form_definition: form_def,
        status: "draft", created_at: 3.days.ago)

      # San Francisco - 3 submissions, 2 completed
      create_list(:submission, 2, user: sf_user, form_definition: form_def,
        status: "completed", completed_at: 3.days.ago, created_at: 3.days.ago)
      create(:submission, user: sf_user, form_definition: form_def,
        status: "draft", created_at: 3.days.ago)

      # San Diego - 1 submission
      create(:submission, user: sd_user, form_definition: form_def,
        status: "draft", created_at: 3.days.ago)
    end

    it "returns usage statistics by county" do
      service = described_class.new
      by_county = service.usage_by_county

      expect(by_county).to be_an(Array)
      expect(by_county.first[:county]).to eq("Los Angeles") # Highest count

      la_county = by_county.find { |c| c[:county] == "Los Angeles" }
      expect(la_county[:submissions]).to eq(5)
      expect(la_county[:completions]).to eq(3)
      expect(la_county[:completion_rate]).to eq(60.0)
    end
  end

  describe "#top_counties" do
    let(:la_user) { create(:user, city: "Los Angeles") }
    let(:sf_user) { create(:user, city: "San Francisco") }

    before do
      create_list(:submission, 10, user: la_user, form_definition: form_def, created_at: 3.days.ago)
      create_list(:submission, 5, user: sf_user, form_definition: form_def, created_at: 3.days.ago)
    end

    it "returns top N counties by usage" do
      service = described_class.new
      top = service.top_counties(limit: 2)

      expect(top.length).to eq(2)
      expect(top.first[:county]).to eq("Los Angeles")
    end
  end

  describe "#underserved_counties" do
    let(:la_user) { create(:user, city: "Los Angeles") }
    let(:modesto_user) { create(:user, city: "Modesto") }

    before do
      create_list(:submission, 10, user: la_user, form_definition: form_def, created_at: 3.days.ago)
      create_list(:submission, 2, user: modesto_user, form_definition: form_def, created_at: 3.days.ago)
    end

    it "identifies counties with low usage" do
      service = described_class.new
      underserved = service.underserved_counties(threshold: 5)

      expect(underserved).to be_an(Array)
      stanislaus = underserved.find { |c| c[:county] == "Stanislaus" }
      expect(stanislaus).to be_present if underserved.any?
    end
  end

  describe "#zero_usage_counties" do
    let(:la_user) { create(:user, city: "Los Angeles") }

    before do
      create_list(:submission, 5, user: la_user, form_definition: form_def, created_at: 3.days.ago)
    end

    it "returns counties with no activity" do
      service = described_class.new
      zero_usage = service.zero_usage_counties

      expect(zero_usage).to be_an(Array)
      expect(zero_usage).not_to include("Los Angeles")
      expect(zero_usage.length).to be > 50 # Most of 58 counties
    end
  end

  describe "#coverage_percentage" do
    let(:la_user) { create(:user, city: "Los Angeles") }
    let(:sf_user) { create(:user, city: "San Francisco") }

    before do
      create(:submission, user: la_user, form_definition: form_def, created_at: 3.days.ago)
      create(:submission, user: sf_user, form_definition: form_def, created_at: 3.days.ago)
    end

    it "calculates percentage of counties with activity" do
      service = described_class.new
      coverage = service.coverage_percentage

      # 2 out of 58 counties = ~3.4%
      expect(coverage).to be_between(3, 4)
    end
  end

  describe "#summary_stats" do
    let(:la_user) { create(:user, city: "Los Angeles") }
    let(:sf_user) { create(:user, city: "San Francisco") }

    before do
      create_list(:submission, 5, user: la_user, form_definition: form_def, created_at: 3.days.ago)
      create_list(:submission, 3, user: sf_user, form_definition: form_def, created_at: 3.days.ago)
    end

    it "returns comprehensive summary statistics" do
      service = described_class.new
      stats = service.summary_stats

      expect(stats[:total_counties]).to eq(58)
      expect(stats[:active_counties]).to eq(2)
      expect(stats[:coverage_percentage]).to be > 0
      expect(stats[:total_submissions]).to eq(8)
      expect(stats[:avg_submissions_per_county]).to eq(4.0)
    end
  end

  describe "#regional_breakdown" do
    let(:la_user) { create(:user, city: "Los Angeles") }
    let(:sf_user) { create(:user, city: "San Francisco") }
    let(:fresno_user) { create(:user, city: "Fresno") }

    before do
      # Southern California
      create_list(:submission, 5, user: la_user, form_definition: form_def, created_at: 3.days.ago)
      # Northern California
      create_list(:submission, 3, user: sf_user, form_definition: form_def, created_at: 3.days.ago)
      # Central California
      create_list(:submission, 2, user: fresno_user, form_definition: form_def, created_at: 3.days.ago)
    end

    it "breaks down usage by region" do
      service = described_class.new
      regional = service.regional_breakdown

      expect(regional).to be_an(Array)
      expect(regional.map { |r| r[:region] }).to include(
        "Northern California",
        "Central California",
        "Southern California"
      )

      southern = regional.find { |r| r[:region] == "Southern California" }
      expect(southern[:submissions]).to eq(5)
    end
  end

  describe "ZIP code mapping" do
    let(:user_with_zip) { create(:user, zip_code: "90210") }

    before do
      create(:submission, user: user_with_zip, form_definition: form_def, created_at: 3.days.ago)
    end

    it "maps ZIP codes to counties" do
      service = described_class.new
      by_county = service.usage_by_county

      la_county = by_county.find { |c| c[:county] == "Los Angeles" }
      expect(la_county).to be_present
    end
  end
end
