# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProductFeedbackVote, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:product_feedback).counter_cache(:votes_count) }
  end

  describe "validations" do
    subject { create(:product_feedback_vote) }

    it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:product_feedback_id).with_message("can only vote once per feedback") }
  end

  describe "counter_cache" do
    let(:feedback) { create(:product_feedback) }
    let(:user) { create(:user) }

    it "increments votes_count when vote is created" do
      expect {
        create(:product_feedback_vote, user: user, product_feedback: feedback)
      }.to change { feedback.reload.votes_count }.by(1)
    end

    it "decrements votes_count when vote is destroyed" do
      vote = create(:product_feedback_vote, user: user, product_feedback: feedback)
      expect {
        vote.destroy
      }.to change { feedback.reload.votes_count }.by(-1)
    end
  end
end
