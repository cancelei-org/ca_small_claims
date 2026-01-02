# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Accessibility", type: :system, js: true do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:form_def) { create(:form_definition, :with_fields, code: "SC-100") }
  let(:workflow) { create(:workflow) }
  let!(:step) { create(:workflow_step, workflow: workflow, form_definition: form_def) }
  let(:submission) { create(:submission, form_definition: form_def, user: user) }

  before do
    driven_by :chrome
  end

  describe "Public Pages" do
    it "homepage is accessible" do
      visit root_path
      expect_page_to_be_accessible
    end

    it "about page is accessible" do
      visit about_path
      expect_page_to_be_accessible
    end

    it "help page is accessible" do
      visit help_path
      expect_page_to_be_accessible
    end

    it "forms index is accessible" do
      visit forms_path
      expect_page_to_be_accessible
    end

    it "workflows index is accessible" do
      visit workflows_path
      expect_page_to_be_accessible
    end
  end

  describe "Authenticated User Pages" do
    before { login_as(user, scope: :user) }

    it "form show page is accessible" do
      visit form_path(form_def.code)
      expect_page_to_be_accessible
    end

    it "workflow show page is accessible" do
      visit workflow_path(workflow)
      expect_page_to_be_accessible
    end

    it "submissions index is accessible" do
      visit submissions_path
      expect_page_to_be_accessible
    end

    it "submission show page is accessible" do
      visit submission_path(submission)
      expect_page_to_be_accessible
    end

    it "profile page is accessible" do
      visit profile_path
      expect_page_to_be_accessible
    end
  end

  describe "Admin Pages" do
    before { login_as(admin, scope: :user) }

    it "admin dashboard is accessible" do
      visit admin_root_path
      expect_page_to_be_accessible
    end

    it "admin feedbacks index is accessible" do
      visit admin_feedbacks_path
      expect_page_to_be_accessible
    end

    it "admin analytics index is accessible" do
      visit admin_analytics_path
      expect_page_to_be_accessible
    end
  end
end
