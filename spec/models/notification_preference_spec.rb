# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationPreference, type: :model do
  let(:user) { create(:user) }
  let(:notification_preference) { create(:notification_preference, user: user) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "default values" do
    subject(:preference) { described_class.new }

    it "has email_form_submission enabled by default" do
      expect(preference.email_form_submission).to be true
    end

    it "has email_form_download enabled by default" do
      expect(preference.email_form_download).to be true
    end

    it "has email_deadline_reminders enabled by default" do
      expect(preference.email_deadline_reminders).to be true
    end

    it "has email_fee_waiver_status enabled by default" do
      expect(preference.email_fee_waiver_status).to be true
    end

    it "has email_marketing disabled by default" do
      expect(preference.email_marketing).to be false
    end
  end

  describe "#enabled?" do
    it "returns true for enabled notification types" do
      expect(notification_preference.enabled?(:email_form_submission)).to be true
    end

    it "returns false for disabled notification types" do
      notification_preference.update!(email_form_submission: false)
      expect(notification_preference.enabled?(:email_form_submission)).to be false
    end

    it "works with string keys" do
      expect(notification_preference.enabled?("email_form_submission")).to be true
    end

    it "returns false for unknown notification types" do
      expect(notification_preference.enabled?(:unknown_type)).to be false
    end
  end

  describe "#enable_all_transactional!" do
    before do
      notification_preference.update!(
        email_form_submission: false,
        email_form_download: false,
        email_deadline_reminders: false,
        email_fee_waiver_status: false
      )
    end

    it "enables all transactional notifications" do
      notification_preference.enable_all_transactional!

      expect(notification_preference.email_form_submission).to be true
      expect(notification_preference.email_form_download).to be true
      expect(notification_preference.email_deadline_reminders).to be true
      expect(notification_preference.email_fee_waiver_status).to be true
    end

    it "does not enable marketing notifications" do
      notification_preference.enable_all_transactional!
      expect(notification_preference.email_marketing).to be false
    end
  end

  describe "#disable_all!" do
    it "disables all notifications" do
      notification_preference.disable_all!

      expect(notification_preference.email_form_submission).to be false
      expect(notification_preference.email_form_download).to be false
      expect(notification_preference.email_deadline_reminders).to be false
      expect(notification_preference.email_fee_waiver_status).to be false
      expect(notification_preference.email_marketing).to be false
    end
  end

  describe "#to_settings_hash" do
    it "returns a hash of all notification settings" do
      result = notification_preference.to_settings_hash

      expect(result).to include(
        "email_form_submission" => true,
        "email_form_download" => true,
        "email_deadline_reminders" => true,
        "email_fee_waiver_status" => true,
        "email_marketing" => false
      )
    end
  end

  describe "NOTIFICATION_TYPES constant" do
    it "includes all expected notification types" do
      expect(described_class::NOTIFICATION_TYPES).to contain_exactly(
        "email_form_submission",
        "email_form_download",
        "email_deadline_reminders",
        "email_fee_waiver_status",
        "email_marketing"
      )
    end
  end
end
