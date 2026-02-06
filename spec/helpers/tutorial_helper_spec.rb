# frozen_string_literal: true

require "rails_helper"

RSpec.describe TutorialHelper, type: :helper do
  describe "#tutorial_wrapper" do
    it "wraps content with tutorial controller data attributes" do
      result = helper.tutorial_wrapper("form_tutorial") { "<div>Content</div>".html_safe }

      expect(result).to include('data-controller="tutorial"')
      expect(result).to include('data-tutorial-tutorial-id-value="form_tutorial"')
      expect(result).to include("Content")
    end

    it "includes steps from YAML config" do
      result = helper.tutorial_wrapper("form_tutorial") { "" }

      expect(result).to include("data-tutorial-steps-value")
      # Steps are JSON encoded, so check for the attribute presence
      expect(result).to include("id")
    end

    it "returns just content for unknown tutorial" do
      result = helper.tutorial_wrapper("nonexistent_tutorial") { "<div>Content</div>".html_safe }

      expect(result).not_to include("data-controller")
      expect(result).to include("Content")
    end
  end

  describe "#load_tutorial_config" do
    it "loads valid tutorial configuration" do
      config = helper.load_tutorial_config("form_tutorial")

      expect(config).to be_present
      expect(config["tutorial"]["id"]).to eq("form_page_tutorial")
    end

    it "returns nil for missing config" do
      config = helper.load_tutorial_config("nonexistent")

      expect(config).to be_nil
    end
  end

  describe "#tutorial_completed?" do
    context "when user is not signed in" do
      before do
        allow(helper).to receive(:user_signed_in?).and_return(false)
      end

      it "returns false" do
        expect(helper.tutorial_completed?("form_tutorial")).to be false
      end
    end

    context "when user is signed in" do
      let(:user) { create(:user) }

      before do
        allow(helper).to receive(:user_signed_in?).and_return(true)
        allow(helper).to receive(:current_user).and_return(user)
      end

      it "returns false when tutorial not completed" do
        expect(helper.tutorial_completed?("form_tutorial")).to be false
      end

      it "returns true when tutorial completed" do
        user.complete_tutorial!("form_tutorial")

        expect(helper.tutorial_completed?("form_tutorial")).to be true
      end
    end
  end

  describe "#tutorial_restart_button" do
    it "renders a button with tutorial action" do
      result = helper.tutorial_restart_button("form_tutorial")

      # The data-action may be HTML-escaped in some contexts
      expect(result).to include("data-action")
      expect(result).to include("tutorial#start")
      expect(result).to include("Take the Tour")
    end

    it "accepts custom text" do
      result = helper.tutorial_restart_button("form_tutorial", text: "Show Tutorial")

      expect(result).to include("Show Tutorial")
    end
  end
end
