# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analytics::ActiveUsersService do
  let(:user) { create(:user) }
  let(:user2) { create(:user) }
  let(:form_def) { create(:form_definition, code: "SC-100") }
  let(:workflow) { create(:workflow) }

  before do
    travel_to Time.zone.local(2024, 3, 15, 12, 0, 0)
  end

  after do
    travel_back
  end

  describe "#initialize" do
    it "uses default threshold of 15 minutes" do
      service = described_class.new
      expect(service.threshold).to eq(15.minutes)
    end

    it "accepts custom threshold" do
      service = described_class.new(threshold: 30.minutes)
      expect(service.threshold).to eq(30.minutes)
    end
  end

  describe "#active_count" do
    before do
      # Active registered user
      create(:submission, user: user, form_definition: form_def, updated_at: 5.minutes.ago)
      # Active anonymous session
      create(:submission, user: nil, session_id: "session1", form_definition: form_def, updated_at: 3.minutes.ago)
      # Inactive (too old)
      create(:submission, user: user2, form_definition: form_def, updated_at: 20.minutes.ago)
    end

    it "returns total count of active users and sessions" do
      service = described_class.new
      expect(service.active_count).to eq(2)
    end
  end

  describe "#active_users_count" do
    before do
      create(:submission, user: user, form_definition: form_def, updated_at: 5.minutes.ago)
      create(:submission, user: user2, form_definition: form_def, updated_at: 10.minutes.ago)
      create(:submission, user: nil, session_id: "session1", form_definition: form_def, updated_at: 3.minutes.ago)
    end

    it "counts only registered users" do
      service = described_class.new
      expect(service.active_users_count).to eq(2)
    end
  end

  describe "#active_sessions_count" do
    before do
      create(:submission, user: nil, session_id: "session1", form_definition: form_def, updated_at: 5.minutes.ago)
      create(:submission, user: nil, session_id: "session2", form_definition: form_def, updated_at: 3.minutes.ago)
      create(:submission, user: user, form_definition: form_def, updated_at: 3.minutes.ago)
    end

    it "counts only anonymous sessions" do
      service = described_class.new
      expect(service.active_sessions_count).to eq(2)
    end
  end

  describe "#active_users" do
    before do
      create(:submission, user: user, form_definition: form_def, updated_at: 5.minutes.ago)
    end

    it "returns active registered users with activity info" do
      service = described_class.new
      users = service.active_users

      expect(users.length).to eq(1)
      expect(users.first[:type]).to eq("registered")
      expect(users.first[:user_id]).to eq(user.id)
      expect(users.first[:active_for]).to be_present
    end
  end

  describe "#active_sessions" do
    before do
      create(:submission, user: nil, session_id: "session123", form_definition: form_def, updated_at: 5.minutes.ago)
    end

    it "returns active anonymous sessions with activity info" do
      service = described_class.new
      sessions = service.active_sessions

      expect(sessions.length).to eq(1)
      expect(sessions.first[:type]).to eq("anonymous")
      expect(sessions.first[:session_id]).to eq("session123")
      expect(sessions.first[:active_for]).to be_present
    end
  end

  describe "#all_active" do
    before do
      create(:submission, user: user, form_definition: form_def, updated_at: 5.minutes.ago)
      create(:submission, user: nil, session_id: "session1", form_definition: form_def, updated_at: 3.minutes.ago)
    end

    it "combines and sorts all active users and sessions" do
      service = described_class.new
      all = service.all_active

      expect(all.length).to eq(2)
      # Most recent first (session1 at 3 minutes ago)
      expect(all.first[:type]).to eq("anonymous")
    end
  end

  describe "#activity_by_page" do
    before do
      create(:submission, form_definition: form_def, status: "draft", updated_at: 5.minutes.ago)
      create(:submission, form_definition: form_def, status: "completed", updated_at: 3.minutes.ago)
    end

    it "returns activity breakdown" do
      service = described_class.new
      activity = service.activity_by_page

      expect(activity[:total]).to eq(2)
      expect(activity[:by_status]).to eq({ "draft" => 1, "completed" => 1 })
    end
  end

  describe "#activity_by_form" do
    let(:form_def2) { create(:form_definition, code: "SC-105") }

    before do
      create_list(:submission, 3, form_definition: form_def, updated_at: 5.minutes.ago)
      create(:submission, form_definition: form_def2, updated_at: 5.minutes.ago)
    end

    it "groups activity by form" do
      service = described_class.new
      by_form = service.activity_by_form

      expect(by_form.first[:form_code]).to eq("SC-100")
      expect(by_form.first[:active_users]).to eq(3)
    end
  end

  describe "#activity_by_workflow" do
    before do
      create(:submission, form_definition: form_def, workflow: workflow, updated_at: 5.minutes.ago)
      create_list(:submission, 2, form_definition: form_def, workflow: nil, updated_at: 5.minutes.ago)
    end

    it "distinguishes workflow vs direct access" do
      service = described_class.new
      by_workflow = service.activity_by_workflow

      expect(by_workflow[:workflow]).to eq(1)
      expect(by_workflow[:direct]).to eq(2)
    end
  end

  describe "#recent_activity_feed" do
    before do
      create(:submission, user: user, form_definition: form_def, updated_at: 10.minutes.ago)
      create(:submission, user: nil, session_id: "sess1", form_definition: form_def, updated_at: 5.minutes.ago)
    end

    it "returns recent activity feed" do
      service = described_class.new
      feed = service.recent_activity_feed(limit: 10)

      expect(feed.length).to eq(2)
      expect(feed.first[:form_code]).to eq("SC-100")
    end
  end

  describe "#session_durations" do
    before do
      # 10 minute session
      create(:submission, form_definition: form_def,
        created_at: 20.minutes.ago,
        updated_at: 10.minutes.ago)
      # 5 minute session
      create(:submission, form_definition: form_def,
        created_at: 10.minutes.ago,
        updated_at: 5.minutes.ago)
    end

    it "calculates session duration statistics" do
      service = described_class.new
      durations = service.session_durations

      expect(durations[:count]).to eq(2)
      expect(durations[:avg_minutes]).to be > 0
      expect(durations[:median_minutes]).to be > 0
    end

    it "handles empty results" do
      Submission.destroy_all
      service = described_class.new
      expect(service.session_durations).to eq({})
    end
  end

  describe "#page_views" do
    before do
      create(:submission, form_definition: form_def, updated_at: 10.minutes.ago)
      create(:submission, form_definition: form_def, updated_at: 30.minutes.ago)
      create(:submission, form_definition: form_def, updated_at: 2.hours.ago)
    end

    it "returns page views by time window" do
      service = described_class.new
      views = service.page_views

      expect(views[:last_15_min]).to eq(1)
      expect(views[:last_hour]).to eq(2)
      expect(views[:last_24_hours]).to eq(3)
    end
  end

  describe "#user_type_breakdown" do
    before do
      create(:submission, user: user, form_definition: form_def, updated_at: 5.minutes.ago)
      create(:submission, user: nil, session_id: "s1", form_definition: form_def, updated_at: 5.minutes.ago)
      create(:submission, user: nil, session_id: "s2", form_definition: form_def, updated_at: 5.minutes.ago)
    end

    it "breaks down by user type" do
      service = described_class.new
      breakdown = service.user_type_breakdown

      expect(breakdown[:registered]).to eq(1)
      expect(breakdown[:anonymous]).to eq(2)
    end
  end
end
