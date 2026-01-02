# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Workflows", type: :request do
  let!(:form_def) { create(:form_definition, code: "W-FORM") }
  let!(:workflow) { create(:workflow, name: "Test Workflow", slug: "test-workflow") }
  let!(:step) { create(:workflow_step, workflow: workflow, form_definition: form_def, position: 1) }

  before do
    # Ensure session id logic works
    # SessionStorage uses ensure_session_id in before_action
  end

  describe "GET /workflows" do
    it "returns http success" do
      get workflows_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Test Workflow")
    end
  end

  describe "GET /workflows/:id" do
    it "initializes the engine and redirects to first step or shows show page" do
      get workflow_path(workflow)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Test Workflow")
    end
  end

  describe "POST /workflows/:id/advance" do
    let(:params) { { submission: { "field1" => "value" } } }

    it "advances the workflow" do
      # First request to init session
      get workflow_path(workflow)

      post advance_workflow_path(workflow), params: params

      # Since there is only one step, it might redirect to complete
      expect(response).to redirect_to(complete_workflow_path(workflow))
    end
  end

  describe "GET /workflows/:id/complete" do
    it "shows completion page if complete" do
      # Manually set up completed state would be hard without traversing steps
      # So we traverse
      get workflow_path(workflow)
      post advance_workflow_path(workflow)

      get complete_workflow_path(workflow)
      expect(response).to have_http_status(:success)
    end
  end
end
