# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:submissions).dependent(:destroy) }
    it { is_expected.to have_many(:form_feedbacks).dependent(:nullify) }
    it { is_expected.to have_many(:resolved_feedbacks).class_name("FormFeedback").with_foreign_key("resolved_by_id").dependent(:nullify) }
  end

  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_presence_of(:password) }
  end

  describe "scopes" do
    let!(:registered) { create(:user, guest: false) }
    let!(:guest) { create(:user, guest: true) }

    describe ".guests" do
      it { expect(User.guests).to contain_exactly(guest) }
    end

    describe ".registered" do
      it { expect(User.registered).to contain_exactly(registered) }
    end
  end

  describe "callbacks" do
    it "sets guest_token before create if guest" do
      user = User.new(email: "guest@example.com", password: "password", guest: true)
      user.save!
      expect(user.guest_token).not_to be_nil
    end

    it "does not set guest_token if not guest" do
      user = User.new(email: "user@example.com", password: "password", guest: false)
      user.save!
      expect(user.guest_token).to be_nil
    end
  end

  describe "instance methods" do
    let(:user) { build(:user, full_name: "Jane Doe", email: "jane@example.com") }

    describe "#display_name" do
      it "returns full_name if present" do
        expect(user.display_name).to eq("Jane Doe")
      end

      it "returns email prefix if full_name is blank" do
        user.full_name = nil
        expect(user.display_name).to eq("jane")
      end
    end

    describe "#admin?" do
      it "returns true if admin is true" do
        user.admin = true
        expect(user.admin?).to be true
      end

      it "returns false if admin is false" do
        user.admin = false
        expect(user.admin?).to be false
      end
    end

    describe "#profile_complete?" do
      it "returns true if required fields are present" do
        user.assign_attributes(
          address: "123 St",
          city: "Sac",
          zip_code: "95814"
        )
        expect(user.profile_complete?).to be true
      end

      it "returns false if fields are missing" do
        user.address = nil
        expect(user.profile_complete?).to be false
      end
    end
  end
end
