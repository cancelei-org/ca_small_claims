# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProductFeedback, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:votes).class_name("ProductFeedbackVote").dependent(:destroy) }
    it { is_expected.to have_many(:voters).through(:votes).source(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(200) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_length_of(:description).is_at_most(5000) }
    it { is_expected.to validate_presence_of(:category) }
    it { is_expected.to validate_presence_of(:status) }
  end

  describe "enums" do
    it do
      expect(described_class.categories).to eq(
        "general" => 0,
        "bug" => 1,
        "feature" => 2,
        "partnership" => 3
      )
    end

    it do
      expect(described_class.statuses).to eq(
        "pending" => 0,
        "under_review" => 1,
        "planned" => 2,
        "in_progress" => 3,
        "completed" => 4,
        "declined" => 5
      )
    end
  end

  describe "scopes" do
    let!(:pending_feedback) { create(:product_feedback, :pending) }
    let!(:completed_feedback) { create(:product_feedback, :completed) }
    let!(:bug_feedback) { create(:product_feedback, :bug) }
    let!(:popular_feedback) { create(:product_feedback, :with_votes, vote_count: 10) }

    describe ".recent" do
      it "orders by created_at desc" do
        results = described_class.recent
        expect(results.first.created_at).to be >= results.last.created_at
      end
    end

    describe ".popular" do
      it "orders by votes_count desc" do
        results = described_class.popular
        expect(results.first).to eq(popular_feedback)
      end
    end

    describe ".by_category" do
      it "filters by category" do
        expect(described_class.by_category(:bug)).to include(bug_feedback)
        expect(described_class.by_category(:bug)).not_to include(pending_feedback)
      end
    end

    describe ".by_status" do
      it "filters by status" do
        expect(described_class.by_status(:pending)).to include(pending_feedback)
        expect(described_class.by_status(:pending)).not_to include(completed_feedback)
      end
    end

    describe ".open" do
      it "returns feedbacks with open statuses" do
        expect(described_class.open).to include(pending_feedback)
        expect(described_class.open).not_to include(completed_feedback)
      end
    end

    describe ".closed" do
      it "returns feedbacks with closed statuses" do
        expect(described_class.closed).to include(completed_feedback)
        expect(described_class.closed).not_to include(pending_feedback)
      end
    end
  end

  describe "rate limiting" do
    let(:user) { create(:user) }

    it "allows up to 10 submissions in 24 hours" do
      9.times do
        create(:product_feedback, user: user)
      end

      feedback = build(:product_feedback, user: user)
      expect(feedback).to be_valid
    end

    it "prevents more than 10 submissions in 24 hours" do
      10.times do
        create(:product_feedback, user: user)
      end

      feedback = build(:product_feedback, user: user)
      expect(feedback).not_to be_valid
      expect(feedback.errors[:base]).to include(/maximum number of feedback submissions/)
    end

    it "allows submissions after 24 hours" do
      10.times do
        create(:product_feedback, user: user, created_at: 25.hours.ago)
      end

      feedback = build(:product_feedback, user: user)
      expect(feedback).to be_valid
    end
  end

  describe "voting" do
    let(:feedback) { create(:product_feedback) }
    let(:user) { create(:user) }

    describe "#voted_by?" do
      it "returns false when user has not voted" do
        expect(feedback.voted_by?(user)).to be false
      end

      it "returns true when user has voted" do
        feedback.vote_by(user)
        expect(feedback.voted_by?(user)).to be true
      end

      it "returns false for nil user" do
        expect(feedback.voted_by?(nil)).to be false
      end
    end

    describe "#vote_by" do
      it "creates a vote for the user" do
        expect { feedback.vote_by(user) }.to change(ProductFeedbackVote, :count).by(1)
      end

      it "returns nil if user already voted" do
        feedback.vote_by(user)
        expect(feedback.vote_by(user)).to be_nil
      end

      it "increments votes_count" do
        expect { feedback.vote_by(user) }.to change { feedback.reload.votes_count }.by(1)
      end
    end

    describe "#unvote_by" do
      before { feedback.vote_by(user) }

      it "removes the vote for the user" do
        expect { feedback.unvote_by(user) }.to change(ProductFeedbackVote, :count).by(-1)
      end

      it "decrements votes_count" do
        expect { feedback.unvote_by(user) }.to change { feedback.reload.votes_count }.by(-1)
      end

      it "returns nil if user has not voted" do
        other_user = create(:user)
        expect(feedback.unvote_by(other_user)).to be_nil
      end
    end
  end

  describe "class methods" do
    describe ".categories_for_select" do
      it "returns categories formatted for select options" do
        options = described_class.categories_for_select
        expect(options).to include(["General Feedback", "general"])
        expect(options).to include(["Bug Report", "bug"])
        expect(options).to include(["Feature Request", "feature"])
        expect(options).to include(["Partnership Inquiry", "partnership"])
      end
    end

    describe ".statuses_for_select" do
      it "returns statuses formatted for select options" do
        options = described_class.statuses_for_select
        expect(options).to include(["Pending Review", "pending"])
        expect(options).to include(["Under Review", "under_review"])
        expect(options).to include(["Completed", "completed"])
      end
    end

    describe ".category_display_name" do
      it "returns human-readable category names" do
        expect(described_class.category_display_name("general")).to eq("General Feedback")
        expect(described_class.category_display_name("bug")).to eq("Bug Report")
        expect(described_class.category_display_name("feature")).to eq("Feature Request")
        expect(described_class.category_display_name("partnership")).to eq("Partnership Inquiry")
      end
    end

    describe ".status_display_name" do
      it "returns human-readable status names" do
        expect(described_class.status_display_name("pending")).to eq("Pending Review")
        expect(described_class.status_display_name("under_review")).to eq("Under Review")
        expect(described_class.status_display_name("completed")).to eq("Completed")
      end
    end

    describe ".status_color" do
      it "returns appropriate badge colors for statuses" do
        expect(described_class.status_color("pending")).to eq("badge-ghost")
        expect(described_class.status_color("under_review")).to eq("badge-info")
        expect(described_class.status_color("completed")).to eq("badge-success")
        expect(described_class.status_color("declined")).to eq("badge-error")
      end
    end
  end

  describe "instance methods" do
    let(:feedback) { create(:product_feedback, :bug, :under_review) }

    describe "#category_display_name" do
      it "returns the human-readable category name" do
        expect(feedback.category_display_name).to eq("Bug Report")
      end
    end

    describe "#status_display_name" do
      it "returns the human-readable status name" do
        expect(feedback.status_display_name).to eq("Under Review")
      end
    end

    describe "#open?" do
      it "returns true for open statuses" do
        %i[pending under_review planned in_progress].each do |status|
          feedback.status = status
          expect(feedback.open?).to be true
        end
      end

      it "returns false for closed statuses" do
        %i[completed declined].each do |status|
          feedback.status = status
          expect(feedback.open?).to be false
        end
      end
    end

    describe "#closed?" do
      it "returns true for closed statuses" do
        %i[completed declined].each do |status|
          feedback.status = status
          expect(feedback.closed?).to be true
        end
      end

      it "returns false for open statuses" do
        %i[pending under_review planned in_progress].each do |status|
          feedback.status = status
          expect(feedback.closed?).to be false
        end
      end
    end
  end
end
