# frozen_string_literal: true

require "rails_helper"

RSpec.describe SessionSubmission, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:form_definition) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:session_id) }
    # expires_at is set by callback, so presence validation on create might be tricky
    # but the model has it.
  end

  describe "callbacks" do
    it "sets expiration on create" do
      ss = SessionSubmission.create!(session_id: "test", form_definition: create(:form_definition))
      expect(ss.expires_at).to be_within(1.minute).of(72.hours.from_now)
    end
  end

  describe "scopes" do
    let!(:active) { create(:session_submission, expires_at: 1.day.from_now) }
    let!(:expired) { create(:session_submission, expires_at: 1.day.ago) }

    describe ".for_session" do
      it { expect(SessionSubmission.for_session(active.session_id)).to contain_exactly(active) }
    end

    describe ".active" do
      it { expect(SessionSubmission.active).to contain_exactly(active) }
    end

    describe ".expired" do
      it { expect(SessionSubmission.expired).to contain_exactly(expired) }
    end
  end

  describe "instance methods" do
    describe "#expired?" do
      it "returns true if expired" do
        expect(build(:session_submission, expires_at: 1.minute.ago).expired?).to be true
      end

      it "returns false if not expired" do
        expect(build(:session_submission, expires_at: 1.minute.from_now).expired?).to be false
      end
    end

    describe "#extend_expiration!" do
      it "updates expires_at" do
        ss = create(:session_submission, expires_at: 1.hour.from_now)
        ss.extend_expiration!
        expect(ss.reload.expires_at).to be_within(1.minute).of(72.hours.from_now)
      end
    end
  end

  describe "class methods" do
    describe ".cleanup_expired!" do
      it "deletes expired records" do
        create(:session_submission, expires_at: 1.day.ago)
        create(:session_submission, expires_at: 1.day.from_now)
        expect { SessionSubmission.cleanup_expired! }.to change(SessionSubmission, :count).by(-1)
      end
    end

    describe ".for_form" do
      let(:form) { create(:form_definition) }
      let(:sid) { "test-session" }

      it "finds existing record" do
        existing = create(:session_submission, session_id: sid, form_definition: form)
        expect(SessionSubmission.for_form(sid, form)).to eq(existing)
      end

      it "initializes new record if not found" do
        ss = SessionSubmission.for_form(sid, form)
        expect(ss).to be_new_record
        expect(ss.session_id).to eq(sid)
        expect(ss.form_definition).to eq(form)
      end
    end
  end
end
