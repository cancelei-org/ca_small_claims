# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#current_theme" do
    it "defaults to light" do
      allow(helper).to receive(:user_signed_in?).and_return(false)
      expect(helper.current_theme).to eq("light")
    end

    it "returns theme from session if present" do
      session[:theme_preference] = "dark"
      expect(helper.current_theme).to eq("dark")
    end

    it "returns theme from user if signed in" do
      user_double = double("User", theme_preference: "cupcake")
      allow(helper).to receive(:user_signed_in?).and_return(true)
      allow(helper).to receive(:current_user).and_return(user_double)

      expect(helper.current_theme).to eq("cupcake")
    end
  end

  describe "#dark_theme?" do
    it "returns true for dark themes" do
      expect(helper.dark_theme?("dark")).to be true
      expect(helper.dark_theme?("night")).to be true
    end

    it "returns false for light themes" do
      expect(helper.dark_theme?("light")).to be false
      expect(helper.dark_theme?("cupcake")).to be false
    end
  end

  describe "#all_theme_ids" do
    it "returns a flat array of all theme IDs" do
      ids = helper.all_theme_ids
      expect(ids).to include("light", "dark", "cupcake", "dracula", "high-contrast-light", "high-contrast-dark")
      expect(ids.count).to eq(12) # 5 light + 5 dark + 2 accessibility
    end
  end
end
