# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ProductFeedbacks", type: :request do
  let(:user) { create(:user) }

  describe "GET /product_feedbacks" do
    before { sign_in user }

    it "returns http success" do
      get product_feedbacks_path
      expect(response).to have_http_status(:success)
    end

    it "displays product feedbacks" do
      feedbacks = create_list(:product_feedback, 3)
      get product_feedbacks_path
      feedbacks.each do |feedback|
        expect(response.body).to include(feedback.title)
      end
    end

    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        get product_feedbacks_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /product_feedbacks/new" do
    before { sign_in user }

    it "returns http success" do
      get new_product_feedback_path
      expect(response).to have_http_status(:success)
    end

    it "displays the feedback form" do
      get new_product_feedback_path
      expect(response.body).to include("Submit Feedback")
    end

    context "with category param" do
      it "preselects the category" do
        get new_product_feedback_path(category: "bug")
        expect(response.body).to include("bug")
      end
    end
  end

  describe "POST /product_feedbacks" do
    before { sign_in user }

    let(:valid_params) do
      {
        product_feedback: {
          category: "general",
          title: "Great platform",
          description: "I love using this platform for my court forms."
        }
      }
    end

    let(:invalid_params) do
      {
        product_feedback: {
          category: "general",
          title: "",
          description: ""
        }
      }
    end

    context "with valid params" do
      it "creates a new product feedback" do
        expect {
          post product_feedbacks_path, params: valid_params
        }.to change(ProductFeedback, :count).by(1)
      end

      it "associates the feedback with the current user" do
        post product_feedbacks_path, params: valid_params
        expect(ProductFeedback.last.user).to eq(user)
      end

      it "enqueues an admin notification email" do
        expect {
          post product_feedbacks_path, params: valid_params
        }.to have_enqueued_mail(ProductFeedbackMailer, :admin_notification)
      end

      it "redirects to product feedbacks index" do
        post product_feedbacks_path, params: valid_params
        expect(response).to redirect_to(product_feedbacks_path)
      end
    end

    context "with invalid params" do
      it "does not create a product feedback" do
        expect {
          post product_feedbacks_path, params: invalid_params
        }.not_to change(ProductFeedback, :count)
      end

      it "renders the new template with errors" do
        post product_feedbacks_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "rate limiting" do
      before do
        10.times do
          create(:product_feedback, user: user)
        end
      end

      it "prevents creation when rate limit exceeded" do
        expect {
          post product_feedbacks_path, params: valid_params
        }.not_to change(ProductFeedback, :count)
      end
    end
  end

  describe "GET /product_feedbacks/:id" do
    before { sign_in user }

    let(:feedback) { create(:product_feedback) }

    it "returns http success" do
      get product_feedback_path(feedback)
      expect(response).to have_http_status(:success)
    end

    it "displays the feedback details" do
      get product_feedback_path(feedback)
      expect(response.body).to include(feedback.title)
      expect(response.body).to include(feedback.description)
    end
  end

  describe "POST /product_feedbacks/:id/vote" do
    before { sign_in user }

    let(:feedback) { create(:product_feedback) }

    it "creates a vote for the feedback" do
      expect {
        post vote_product_feedback_path(feedback)
      }.to change(ProductFeedbackVote, :count).by(1)
    end

    it "associates the vote with the current user" do
      post vote_product_feedback_path(feedback)
      expect(feedback.votes.last.user).to eq(user)
    end

    it "does not allow duplicate votes" do
      post vote_product_feedback_path(feedback)
      expect {
        post vote_product_feedback_path(feedback)
      }.not_to change(ProductFeedbackVote, :count)
    end

    it "redirects to the feedback" do
      post vote_product_feedback_path(feedback)
      expect(response).to redirect_to(feedback)
    end
  end

  describe "DELETE /product_feedbacks/:id/unvote" do
    before { sign_in user }

    let(:feedback) { create(:product_feedback) }

    context "when user has voted" do
      before { feedback.vote_by(user) }

      it "removes the vote" do
        expect {
          delete unvote_product_feedback_path(feedback)
        }.to change(ProductFeedbackVote, :count).by(-1)
      end

      it "redirects to the feedback" do
        delete unvote_product_feedback_path(feedback)
        expect(response).to redirect_to(feedback)
      end
    end

    context "when user has not voted" do
      it "does not change vote count" do
        expect {
          delete unvote_product_feedback_path(feedback)
        }.not_to change(ProductFeedbackVote, :count)
      end
    end
  end
end
