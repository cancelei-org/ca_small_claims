# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sessions::StorageManager do
  let(:session_id) { "test-session-123" }
  let(:manager) { described_class.new(session_id) }
  let(:form) { create(:form_definition) }

  describe "#save" do
    it "creates or updates a session submission" do
      expect {
        manager.save(form, { "field1" => "value1" })
      }.to change(SessionSubmission, :count).by(1)

      expect(manager.load(form)["field1"]).to eq("value1")
    end

    it "merges new data with existing data" do
      manager.save(form, { "f1" => "v1" })
      manager.save(form, { "f2" => "v2" })

      data = manager.load(form)
      expect(data).to eq({ "f1" => "v1", "f2" => "v2" })
    end
  end

  describe "#migrate_to_user!" do
    let(:user) { create(:user) }

    it "transfers data to user submissions and clears session" do
      manager.save(form, { "key" => "val" })

      expect {
        manager.migrate_to_user!(user)
      }.to change(user.submissions, :count).by(1).and change(SessionSubmission, :count).by(-1)

      expect(user.submissions.last.form_data["key"]).to eq("val")
    end
  end

  describe "#clear!" do
    it "removes all submissions for the session" do
      manager.save(form, { "a" => "b" })
      manager.clear!
      expect(SessionSubmission.for_session(session_id).count).to eq(0)
    end
  end
end
