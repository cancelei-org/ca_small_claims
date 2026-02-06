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

    describe "#profile_for_autofill" do
      it "returns hash of profile data for form autofill" do
        user = create(:user,
          full_name: "Jane Doe",
          address: "123 Main St",
          city: "Sacramento",
          state: "CA",
          zip_code: "95814",
          phone: "555-1234"
        )
        profile = user.profile_for_autofill
        expect(profile[:full_name]).to eq("Jane Doe")
        expect(profile[:address]).to eq("123 Main St")
        expect(profile[:city]).to eq("Sacramento")
        expect(profile[:state]).to eq("CA")
        expect(profile[:zip_code]).to eq("95814")
        expect(profile[:phone]).to eq("555-1234")
      end

      it "excludes nil values" do
        user = create(:user, full_name: "Jane Doe", phone: nil)
        profile = user.profile_for_autofill
        expect(profile).to have_key(:full_name)
        expect(profile).not_to have_key(:phone)
      end
    end

    describe "#form_submissions_for" do
      let(:user) { create(:user) }
      let(:form1) { create(:form_definition) }
      let(:form2) { create(:form_definition) }

      it "returns submissions for specific form" do
        sub1 = create(:submission, user: user, form_definition: form1)
        create(:submission, user: user, form_definition: form2)
        expect(user.form_submissions_for(form1)).to contain_exactly(sub1)
      end
    end

    describe "#recent_submissions" do
      let(:user) { create(:user) }

      it "returns submissions ordered by recent first" do
        old_sub = create(:submission, user: user)
        old_sub.update_column(:updated_at, 2.days.ago)
        new_sub = create(:submission, user: user)
        new_sub.update_column(:updated_at, 1.hour.ago)

        expect(user.recent_submissions.to_a).to eq([ new_sub, old_sub ])
      end

      it "respects limit parameter" do
        create_list(:submission, 5, user: user)
        expect(user.recent_submissions(3).count).to eq(3)
      end
    end

    describe "#migrate_session_data!" do
      let(:user) { create(:user) }
      let(:form) { create(:form_definition) }
      let(:session_id) { "test-session-123" }

      it "migrates session submissions to user submissions" do
        session_sub = create(:session_submission,
          session_id: session_id,
          form_definition: form,
          form_data: { "field1" => "value1" }
        )

        expect {
          user.migrate_session_data!(session_id)
        }.to change { user.submissions.count }.by(1)

        new_sub = user.submissions.find_by(form_definition: form)
        expect(new_sub.form_data).to eq({ "field1" => "value1" })
      end

      it "deletes session submissions after migration" do
        create(:session_submission, session_id: session_id, form_definition: form)

        expect {
          user.migrate_session_data!(session_id)
        }.to change { SessionSubmission.for_session(session_id).count }.by(-1)
      end
    end

    describe "tutorial tracking" do
      let(:user) { create(:user, preferences: {}) }

      describe "#tutorial_completed?" do
        it "returns false if tutorial not completed" do
          expect(user.tutorial_completed?("intro")).to be false
        end

        it "returns true if tutorial is completed" do
          user.complete_tutorial!("intro")
          expect(user.tutorial_completed?("intro")).to be true
        end
      end

      describe "#complete_tutorial!" do
        it "marks tutorial as completed" do
          user.complete_tutorial!("intro")
          expect(user.completed_tutorials).to include("intro")
        end

        it "does not duplicate completed tutorials" do
          user.complete_tutorial!("intro")
          user.complete_tutorial!("intro")
          expect(user.completed_tutorials.count("intro")).to eq(1)
        end
      end

      describe "#completed_tutorials" do
        it "returns empty array for new user" do
          expect(user.completed_tutorials).to eq([])
        end

        it "returns list of completed tutorial IDs" do
          user.complete_tutorial!("intro")
          user.complete_tutorial!("advanced")
          expect(user.completed_tutorials).to contain_exactly("intro", "advanced")
        end
      end
    end
  end
end
