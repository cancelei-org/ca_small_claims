# frozen_string_literal: true

require "rails_helper"

RSpec.describe "FormFeedbacks", type: :request do
  let!(:form_def) { create(:form_definition) }
  let(:params) do
    {
      form_feedback: {
        rating: 5,
        issue_types: [ "other" ],
        comment: "Great!"
      }
    }
  end

  describe "POST /form_feedbacks" do
    it "creates feedback" do
      expect {
        post form_feedbacks_path, params: params.merge(form_definition_id: form_def.id)
      }.to change(FormFeedback, :count).by(1)

      expect(response).to redirect_to(form_path(form_def))
    end

    it "responds with turbo stream on success" do
      post form_feedbacks_path, params: params.merge(form_definition_id: form_def.id), headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
      expect(response.body).to include("Thank You!")
    end

    it "handles failure" do
      invalid_params = params.deep_merge(form_feedback: { rating: nil }).merge(form_definition_id: form_def.id)
      expect {
        post form_feedbacks_path, params: invalid_params
      }.not_to change(FormFeedback, :count)

      # It redirects on html failure too
      expect(response).to redirect_to(form_path(form_def))
    end
  end
end
