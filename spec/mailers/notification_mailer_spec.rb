# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationMailer, type: :mailer do
  let(:user) { create(:user, email: "test@example.com", full_name: "John Doe") }
  let(:form_definition) { create(:form_definition, code: "SC-100", title: "Plaintiff's Claim and ORDER to Go to Small Claims Court") }
  let(:submission) { create(:submission, user: user, form_definition: form_definition, status: "completed") }

  before do
    # Ensure user has notification preferences enabled
    create(:notification_preference, user: user)
  end

  describe "#form_submission_confirmation" do
    let(:mail) { described_class.form_submission_confirmation(user, submission) }

    it "renders the headers" do
      expect(mail.subject).to eq("Your SC-100 form has been submitted")
      expect(mail.to).to eq([ "test@example.com" ])
    end

    it "renders the body" do
      expect(mail.body.encoded).to include("Form Submission Confirmed")
      expect(mail.body.encoded).to include("SC-100")
      expect(mail.body.encoded).to include("John Doe")
    end

    it "includes both HTML and text parts" do
      expect(mail.parts.map(&:content_type)).to include("text/html; charset=UTF-8", "text/plain; charset=UTF-8")
    end

    context "when user cannot receive emails" do
      let(:user) { create(:user, :guest) }

      it "returns nil" do
        expect(mail.message).to be_a(ActionMailer::Base::NullMail)
      end
    end

    context "when user has notifications disabled" do
      before do
        user.notification_preference.update!(email_form_submission: false)
      end

      it "returns nil" do
        expect(mail.message).to be_a(ActionMailer::Base::NullMail)
      end
    end
  end

  describe "#form_download_ready" do
    let(:mail) { described_class.form_download_ready(user, form_definition) }

    it "renders the headers" do
      expect(mail.subject).to eq("Your SC-100 form is ready for download")
      expect(mail.to).to eq([ "test@example.com" ])
    end

    it "renders the body" do
      expect(mail.body.encoded).to include("Your Form is Ready for Download")
      expect(mail.body.encoded).to include("SC-100")
    end

    context "when user has form download notifications disabled" do
      before do
        user.notification_preference.update!(email_form_download: false)
      end

      it "returns nil" do
        expect(mail.message).to be_a(ActionMailer::Base::NullMail)
      end
    end
  end

  describe "#deadline_reminder" do
    let(:deadline_date) { Date.current + 5.days }
    let(:mail) { described_class.deadline_reminder(user, submission, deadline_date) }

    it "renders the headers" do
      expect(mail.subject).to include("deadline")
      expect(mail.to).to eq([ "test@example.com" ])
    end

    it "renders the body" do
      expect(mail.body.encoded).to include("Deadline")
      expect(mail.body.encoded).to include("SC-100")
    end

    context "when deadline is urgent (3 days or less)" do
      let(:deadline_date) { Date.current + 2.days }

      it "includes URGENT in subject" do
        expect(mail.subject).to include("URGENT")
      end
    end

    context "when deadline has passed" do
      let(:deadline_date) { Date.current - 1.day }

      it "includes URGENT and passed in subject" do
        expect(mail.subject).to include("URGENT")
        expect(mail.subject).to include("passed")
      end
    end

    context "when user has deadline notifications disabled" do
      before do
        user.notification_preference.update!(email_deadline_reminders: false)
      end

      it "returns nil" do
        expect(mail.message).to be_a(ActionMailer::Base::NullMail)
      end
    end
  end

  describe "#fee_waiver_status_update" do
    context "when status is approved" do
      let(:mail) { described_class.fee_waiver_status_update(user, submission, "approved") }

      it "renders the headers" do
        expect(mail.subject).to eq("Fee Waiver Application Status: Approved")
        expect(mail.to).to eq([ "test@example.com" ])
      end

      it "includes approval message" do
        expect(mail.body.encoded).to include("approved")
        expect(mail.body.encoded).to include("Court filing fees will be waived")
      end
    end

    context "when status is denied" do
      let(:mail) { described_class.fee_waiver_status_update(user, submission, "denied") }

      it "includes denial message" do
        expect(mail.subject).to include("Denied")
        expect(mail.body.encoded).to include("not approved")
      end
    end

    context "when status is pending_review" do
      let(:mail) { described_class.fee_waiver_status_update(user, submission, "pending_review") }

      it "includes pending message" do
        expect(mail.subject).to include("Pending Review")
        expect(mail.body.encoded).to include("being reviewed")
      end
    end

    context "when user has fee waiver notifications disabled" do
      before do
        user.notification_preference.update!(email_fee_waiver_status: false)
      end

      it "returns nil" do
        mail = described_class.fee_waiver_status_update(user, submission, "approved")
        expect(mail.message).to be_a(ActionMailer::Base::NullMail)
      end
    end
  end
end
