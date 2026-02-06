# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImpersonationLog, type: :model do
  let(:admin) { create(:user, :admin) }
  let(:target_user) { create(:user) }

  describe "associations" do
    it { is_expected.to belong_to(:admin).class_name("User") }
    it { is_expected.to belong_to(:target_user).class_name("User") }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:started_at) }
    it { is_expected.to validate_length_of(:reason).is_at_most(500) }
  end

  describe "scopes" do
    let!(:active_log) do
      create(:impersonation_log, admin: admin, target_user: target_user, started_at: 1.hour.ago, ended_at: nil)
    end
    let!(:completed_log) do
      create(:impersonation_log, admin: admin, target_user: target_user, started_at: 2.hours.ago, ended_at: 1.hour.ago)
    end

    describe ".active" do
      it "returns only logs without ended_at" do
        expect(described_class.active).to contain_exactly(active_log)
      end
    end

    describe ".completed" do
      it "returns only logs with ended_at" do
        expect(described_class.completed).to contain_exactly(completed_log)
      end
    end

    describe ".recent" do
      it "orders by started_at descending" do
        # active_log has started_at 1 hour ago, completed_log has started_at 2 hours ago
        expect(described_class.recent.first).to eq(active_log)
      end
    end

    describe ".by_admin" do
      let(:other_admin) { create(:user, :admin) }
      let!(:other_log) do
        create(:impersonation_log, admin: other_admin, target_user: target_user)
      end

      it "returns only logs for the specified admin" do
        expect(described_class.by_admin(admin)).to contain_exactly(active_log, completed_log)
      end
    end
  end

  describe "#active?" do
    it "returns true when ended_at is nil" do
      log = build(:impersonation_log, ended_at: nil)
      expect(log.active?).to be true
    end

    it "returns false when ended_at is set" do
      log = build(:impersonation_log, ended_at: Time.current)
      expect(log.active?).to be false
    end
  end

  describe "#duration" do
    it "returns nil when started_at is nil" do
      log = build(:impersonation_log, started_at: nil)
      expect(log.duration).to be_nil
    end

    it "calculates duration from started_at to ended_at" do
      log = build(:impersonation_log, started_at: 2.hours.ago, ended_at: 1.hour.ago)
      expect(log.duration).to be_within(1.second).of(1.hour)
    end

    it "calculates duration from started_at to now for active sessions" do
      log = build(:impersonation_log, started_at: 30.minutes.ago, ended_at: nil)
      expect(log.duration).to be_within(1.second).of(30.minutes)
    end
  end

  describe "#duration_in_words" do
    it 'returns "ongoing" for active sessions' do
      log = build(:impersonation_log, ended_at: nil)
      expect(log.duration_in_words).to eq("ongoing")
    end

    it 'returns "less than a minute" for very short sessions' do
      log = build(:impersonation_log, started_at: 30.seconds.ago, ended_at: Time.current)
      expect(log.duration_in_words).to eq("less than a minute")
    end

    it "returns minutes for sessions under an hour" do
      log = build(:impersonation_log, started_at: 15.minutes.ago, ended_at: Time.current)
      expect(log.duration_in_words).to match(/15 minutes/)
    end

    it "returns hours and minutes for longer sessions" do
      log = build(:impersonation_log, started_at: (2.hours + 30.minutes).ago, ended_at: Time.current)
      expect(log.duration_in_words).to match(/hour/)
    end
  end

  describe "#end_session!" do
    it "sets ended_at for active sessions" do
      log = create(:impersonation_log, admin: admin, target_user: target_user, ended_at: nil)
      expect { log.end_session! }.to change { log.reload.ended_at }.from(nil)
    end

    it "does not change ended_at for already ended sessions" do
      original_ended_at = 1.hour.ago
      log = create(:impersonation_log, admin: admin, target_user: target_user, ended_at: original_ended_at)
      log.end_session!
      expect(log.reload.ended_at).to be_within(1.second).of(original_ended_at)
    end
  end
end
