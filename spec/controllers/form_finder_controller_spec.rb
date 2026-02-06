# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormFinderController, type: :controller do
  describe "GET #show" do
    it "renders the show template" do
      get :show

      expect(response).to be_successful
      expect(response).to render_template(:show)
    end

    it "initializes engine with first step" do
      get :show

      expect(assigns(:current_step)).to eq(:role)
      expect(assigns(:progress)[:current]).to eq(1)
    end

    it "restores state from session" do
      session[:form_finder] = {
        step: 2,
        answers: { role: "plaintiff" }
      }.with_indifferent_access

      get :show

      expect(assigns(:current_step)).to eq(:situation)
      expect(assigns(:answers)[:role]).to eq("plaintiff")
    end
  end

  describe "POST #update" do
    it "advances to next step" do
      post :update, params: { role: "plaintiff" }

      expect(session[:form_finder][:step]).to eq(2)
      expect(session[:form_finder][:answers][:role]).to eq("plaintiff")
    end

    it "redirects to show for HTML requests" do
      post :update, params: { role: "plaintiff" }

      expect(response).to redirect_to(form_finder_path)
    end

    context "with turbo stream request" do
      it "renders turbo stream response" do
        post :update, params: { role: "plaintiff" }, format: :turbo_stream

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end
    end
  end

  describe "POST #back" do
    before do
      session[:form_finder] = {
        step: 2,
        answers: { role: "plaintiff" }
      }.with_indifferent_access
    end

    it "goes back to previous step" do
      post :back

      expect(session[:form_finder][:step]).to eq(1)
    end

    it "redirects to show for HTML requests" do
      post :back

      expect(response).to redirect_to(form_finder_path)
    end
  end

  describe "POST #restart" do
    before do
      session[:form_finder] = {
        step: 3,
        answers: { role: "plaintiff", situation: "new_case" }
      }.with_indifferent_access
    end

    it "resets to first step" do
      post :restart

      expect(session[:form_finder][:step]).to eq(1)
      expect(session[:form_finder][:answers][:role]).to be_nil
    end

    it "redirects to show for HTML requests" do
      post :restart

      expect(response).to redirect_to(form_finder_path)
    end
  end

  describe "recommendations step" do
    let!(:sc100) { create(:form_definition, code: "SC-100", title: "Plaintiff's Claim") }

    before do
      session[:form_finder] = {
        step: 4,
        answers: { role: "plaintiff", situation: "new_case" }
      }.with_indifferent_access
    end

    it "loads recommendations on final step" do
      get :show

      expect(assigns(:recommendation)).to be_present
      expect(assigns(:recommendation)[:forms]).to be_present
    end
  end
end
