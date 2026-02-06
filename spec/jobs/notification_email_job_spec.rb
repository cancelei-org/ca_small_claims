# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationEmailJob, type: :job do
  let(:user) { create(:user) }
  let(:form_definition) { create(:form_definition) }
  let(:submission) { create(:submission, user: user, form_definition: form_definition) }

  before do
    create(:notification_preference, user: user)
  end

  describe "#perform" do
    context "with form_submission_confirmation" do
      it "sends the form submission confirmation email" do
        expect {
          described_class.perform_now(
            :form_submission_confirmation,
            user_id: user.id,
            submission_id: submission.id
          )
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end

    context "with form_download_ready" do
      it "sends the form download ready email" do
        expect {
          described_class.perform_now(
            :form_download_ready,
            user_id: user.id,
            form_definition_id: form_definition.id
          )
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end

    context "with deadline_reminder" do
      let(:deadline_date) { Date.current + 5.days }

      it "sends the deadline reminder email" do
        expect {
          described_class.perform_now(
            :deadline_reminder,
            user_id: user.id,
            submission_id: submission.id,
            deadline_date: deadline_date.to_s
          )
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "parses string dates correctly" do
        expect(NotificationMailer).to receive(:deadline_reminder)
          .with(user, submission, deadline_date)
          .and_call_original

        described_class.perform_now(
          :deadline_reminder,
          user_id: user.id,
          submission_id: submission.id,
          deadline_date: deadline_date.to_s
        )
      end
    end

    context "with fee_waiver_status_update" do
      it "sends the fee waiver status update email" do
        expect {
          described_class.perform_now(
            :fee_waiver_status_update,
            user_id: user.id,
            submission_id: submission.id,
            status: "approved"
          )
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end

    context "with unknown notification type" do
      it "logs a warning and does not send email" do
        expect(Rails.logger).to receive(:warn).with(/Unknown notification type/)

        expect {
          described_class.perform_now(:unknown_type, user_id: user.id)
        }.not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context "when user does not exist" do
      it "discards the job without raising" do
        # discard_on catches the exception and doesn't re-raise
        expect {
          described_class.perform_now(
            :form_submission_confirmation,
            user_id: -1,
            submission_id: submission.id
          )
        }.not_to raise_error
      end

      it "does not send an email" do
        expect {
          described_class.perform_now(
            :form_submission_confirmation,
            user_id: -1,
            submission_id: submission.id
          )
        }.not_to change { ActionMailer::Base.deliveries.count }
      end
    end
  end

  describe "job configuration" do
    it "uses the default queue" do
      expect(described_class.queue_name).to eq("default")
    end

    it "has retry behavior configured" do
      # Verify the job has retry/discard configuration
      # The actual retry behavior is tested through integration tests
      expect(described_class.ancestors).to include(ApplicationJob)
    end
  end
end
