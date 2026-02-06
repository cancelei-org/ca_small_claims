# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, "tutorial tracking" do
  let(:user) { create(:user) }

  describe "#tutorial_completed?" do
    it "returns false when tutorial not completed" do
      expect(user.tutorial_completed?("form_tutorial")).to be false
    end

    it "returns true when tutorial completed" do
      user.complete_tutorial!("form_tutorial")

      expect(user.tutorial_completed?("form_tutorial")).to be true
    end

    it "handles string and symbol keys" do
      user.complete_tutorial!(:form_tutorial)

      expect(user.tutorial_completed?("form_tutorial")).to be true
      expect(user.tutorial_completed?(:form_tutorial)).to be true
    end
  end

  describe "#complete_tutorial!" do
    it "adds tutorial to completed list" do
      user.complete_tutorial!("form_tutorial")

      expect(user.completed_tutorials).to include("form_tutorial")
    end

    it "does not duplicate entries" do
      user.complete_tutorial!("form_tutorial")
      user.complete_tutorial!("form_tutorial")

      expect(user.completed_tutorials.count("form_tutorial")).to eq(1)
    end

    it "persists to database" do
      user.complete_tutorial!("form_tutorial")
      user.reload

      expect(user.tutorial_completed?("form_tutorial")).to be true
    end

    it "tracks multiple tutorials" do
      user.complete_tutorial!("form_tutorial")
      user.complete_tutorial!("another_tutorial")

      expect(user.completed_tutorials).to include("form_tutorial", "another_tutorial")
    end
  end

  describe "#completed_tutorials" do
    it "returns empty array for new user" do
      expect(user.completed_tutorials).to eq([])
    end

    it "returns list of completed tutorial IDs" do
      user.complete_tutorial!("tutorial_1")
      user.complete_tutorial!("tutorial_2")

      expect(user.completed_tutorials).to match_array(%w[tutorial_1 tutorial_2])
    end
  end
end
