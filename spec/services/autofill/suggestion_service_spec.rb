# frozen_string_literal: true

require "rails_helper"

RSpec.describe Autofill::SuggestionService do
  let(:user) { create(:user, :with_profile) }
  let(:service) { described_class.new(user) }

  describe "#suggestions_for" do
    context "when shared_field_key matches name pattern" do
      it "returns suggestion with user's full name for plaintiff:name" do
        suggestions = service.suggestions_for("plaintiff:name")

        expect(suggestions).to be_an(Array)
        expect(suggestions.length).to eq(1)
        expect(suggestions.first[:value]).to eq(user.full_name)
        expect(suggestions.first[:label]).to eq("Your name")
        expect(suggestions.first[:source]).to eq("profile")
      end

      it "returns suggestion for defendant:name" do
        suggestions = service.suggestions_for("defendant:name")

        expect(suggestions.first[:value]).to eq(user.full_name)
      end

      it "returns suggestion for claimant:name" do
        suggestions = service.suggestions_for("claimant:name")

        expect(suggestions.first[:value]).to eq(user.full_name)
      end
    end

    context "when shared_field_key matches address pattern" do
      it "returns suggestion with user's address for plaintiff:street" do
        suggestions = service.suggestions_for("plaintiff:street")

        expect(suggestions.first[:value]).to eq(user.address)
        expect(suggestions.first[:label]).to eq("Your address")
      end

      it "returns suggestion for defendant:address" do
        suggestions = service.suggestions_for("defendant:address")

        expect(suggestions.first[:value]).to eq(user.address)
      end
    end

    context "when shared_field_key matches city pattern" do
      it "returns suggestion with user's city" do
        suggestions = service.suggestions_for("plaintiff:city")

        expect(suggestions.first[:value]).to eq(user.city)
        expect(suggestions.first[:label]).to eq("Your city")
      end
    end

    context "when shared_field_key matches state pattern" do
      it "returns suggestion with user's state" do
        suggestions = service.suggestions_for("plaintiff:state")

        expect(suggestions.first[:value]).to eq(user.state)
        expect(suggestions.first[:label]).to eq("Your state")
      end
    end

    context "when shared_field_key matches zip pattern" do
      it "returns suggestion with user's zip code" do
        suggestions = service.suggestions_for("plaintiff:zip")

        expect(suggestions.first[:value]).to eq(user.zip_code)
        expect(suggestions.first[:label]).to eq("Your ZIP code")
      end
    end

    context "when shared_field_key matches phone pattern" do
      it "returns suggestion with user's phone" do
        suggestions = service.suggestions_for("plaintiff:phone")

        expect(suggestions.first[:value]).to eq(user.phone)
        expect(suggestions.first[:label]).to eq("Your phone")
      end

      it "returns suggestion for tel pattern" do
        suggestions = service.suggestions_for("contact:tel")

        expect(suggestions.first[:value]).to eq(user.phone)
      end
    end

    context "when shared_field_key matches date_of_birth pattern" do
      it "returns formatted date for dob pattern" do
        suggestions = service.suggestions_for("plaintiff:dob")

        # date_of_birth is encrypted as text, so format_value returns it as-is or formatted
        expected_value = if user.date_of_birth.respond_to?(:strftime)
                           user.date_of_birth.strftime("%m/%d/%Y")
        else
                           user.date_of_birth.to_s
        end
        expect(suggestions.first[:value]).to eq(expected_value)
        expect(suggestions.first[:label]).to eq("Your date of birth")
      end

      it "returns suggestion for date_of_birth pattern" do
        suggestions = service.suggestions_for("person:date_of_birth")

        expected_value = if user.date_of_birth.respond_to?(:strftime)
                           user.date_of_birth.strftime("%m/%d/%Y")
        else
                           user.date_of_birth.to_s
        end
        expect(suggestions.first[:value]).to eq(expected_value)
      end
    end

    context "when shared_field_key is blank" do
      it "returns empty array for nil" do
        expect(service.suggestions_for(nil)).to eq([])
      end

      it "returns empty array for empty string" do
        expect(service.suggestions_for("")).to eq([])
      end
    end

    context "when shared_field_key does not match any pattern" do
      it "returns empty array" do
        expect(service.suggestions_for("unknown:field")).to eq([])
      end
    end

    context "when user profile data is missing" do
      let(:user) { create(:user, full_name: nil, address: nil) }

      it "returns empty array when profile field is nil" do
        expect(service.suggestions_for("plaintiff:name")).to eq([])
      end
    end

    context "when user is nil" do
      let(:service) { described_class.new(nil) }

      it "returns empty array" do
        expect(service.suggestions_for("plaintiff:name")).to eq([])
      end
    end
  end

  describe "#has_suggestions?" do
    it "returns true when suggestions exist" do
      expect(service.has_suggestions?("plaintiff:name")).to be true
    end

    it "returns false when no suggestions exist" do
      expect(service.has_suggestions?("unknown:field")).to be false
    end

    it "returns false for blank shared_field_key" do
      expect(service.has_suggestions?(nil)).to be false
    end
  end
end
