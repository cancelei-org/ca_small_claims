# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormFinderHelper, type: :helper do
  describe "#situation_options_for" do
    context "for plaintiff role" do
      it "returns plaintiff situation options" do
        options = helper.situation_options_for("plaintiff")

        expect(options).to be_an(Array)
        expect(options).not_to be_empty
      end

      it "includes new_case option" do
        options = helper.situation_options_for("plaintiff")
        new_case = options.find { |opt| opt[:value] == "new_case" }

        expect(new_case).to be_present
        expect(new_case[:label]).to eq("Start a new small claims case")
        expect(new_case[:description]).to include("File a claim")
        expect(new_case[:icon]).to eq("plus-circle")
      end

      it "includes modify_claim option" do
        options = helper.situation_options_for("plaintiff")
        modify = options.find { |opt| opt[:value] == "modify_claim" }

        expect(modify).to be_present
        expect(modify[:label]).to eq("Modify my existing claim")
      end

      it "includes subpoena_witness option" do
        options = helper.situation_options_for("plaintiff")
        subpoena = options.find { |opt| opt[:value] == "subpoena_witness" }

        expect(subpoena).to be_present
        expect(subpoena[:label]).to eq("Get a witness to appear")
      end
    end

    context "for defendant role" do
      it "returns defendant situation options" do
        options = helper.situation_options_for("defendant")

        expect(options).to be_an(Array)
        expect(options).not_to be_empty
      end

      it "includes respond_only option" do
        options = helper.situation_options_for("defendant")
        respond = options.find { |opt| opt[:value] == "respond_only" }

        expect(respond).to be_present
        expect(respond[:label]).to eq("Just respond to the claim")
        expect(respond[:description]).to include("no forms needed")
      end

      it "includes counter_claim option" do
        options = helper.situation_options_for("defendant")
        counter = options.find { |opt| opt[:value] == "counter_claim" }

        expect(counter).to be_present
        expect(counter[:label]).to eq("File a counter-claim")
      end
    end

    context "for judgment_holder role" do
      it "returns judgment holder situation options" do
        options = helper.situation_options_for("judgment_holder")

        expect(options).to be_an(Array)
        expect(options).not_to be_empty
      end

      it "includes record_payment option" do
        options = helper.situation_options_for("judgment_holder")
        record = options.find { |opt| opt[:value] == "record_payment" }

        expect(record).to be_present
        expect(record[:label]).to eq("Record that I was paid")
      end

      it "includes enforce_judgment option" do
        options = helper.situation_options_for("judgment_holder")
        enforce = options.find { |opt| opt[:value] == "enforce_judgment" }

        expect(enforce).to be_present
        expect(enforce[:label]).to eq("Collect the money owed")
      end

      it "includes correct_judgment option" do
        options = helper.situation_options_for("judgment_holder")
        correct = options.find { |opt| opt[:value] == "correct_judgment" }

        expect(correct).to be_present
      end
    end

    context "for judgment_debtor role" do
      it "returns judgment debtor situation options" do
        options = helper.situation_options_for("judgment_debtor")

        expect(options).to be_an(Array)
        expect(options).not_to be_empty
      end

      it "includes payment_plan option" do
        options = helper.situation_options_for("judgment_debtor")
        payment = options.find { |opt| opt[:value] == "payment_plan" }

        expect(payment).to be_present
        expect(payment[:label]).to eq("Request a payment plan")
      end

      it "includes modify_payments option" do
        options = helper.situation_options_for("judgment_debtor")
        modify = options.find { |opt| opt[:value] == "modify_payments" }

        expect(modify).to be_present
      end

      it "includes appeal option" do
        options = helper.situation_options_for("judgment_debtor")
        appeal = options.find { |opt| opt[:value] == "appeal" }

        expect(appeal).to be_present
        expect(appeal[:label]).to eq("Appeal the decision")
      end
    end

    context "for unknown role" do
      it "returns empty array" do
        options = helper.situation_options_for("unknown_role")
        expect(options).to eq([])
      end
    end
  end

  describe "#render_situation_icon" do
    before do
      # Include IconHelper since render_situation_icon uses icon() method
      helper.extend(IconHelper)
    end

    it "renders plus-circle icon" do
      result = helper.render_situation_icon("plus-circle")
      expect(result).to include("<svg")
      expect(result).to include("w-6 h-6")
    end

    it "renders edit icon" do
      result = helper.render_situation_icon("edit")
      expect(result).to include("<svg")
    end

    it "renders user-plus icon" do
      result = helper.render_situation_icon("user-plus")
      expect(result).to include("<svg")
    end

    it "renders message-circle icon" do
      result = helper.render_situation_icon("message-circle")
      expect(result).to include("<svg")
    end

    it "renders refresh icon" do
      result = helper.render_situation_icon("refresh")
      expect(result).to include("<svg")
    end

    it "renders check icon as check_circle" do
      result = helper.render_situation_icon("check")
      expect(result).to include("<svg")
    end

    it "renders dollar icon as dollar_sign" do
      result = helper.render_situation_icon("dollar")
      expect(result).to include("<svg")
    end

    it "renders alert icon as alert_circle" do
      result = helper.render_situation_icon("alert")
      expect(result).to include("<svg")
    end

    it "renders calendar icon" do
      result = helper.render_situation_icon("calendar")
      expect(result).to include("<svg")
    end

    it "renders alert-triangle icon" do
      result = helper.render_situation_icon("alert-triangle")
      expect(result).to include("<svg")
    end

    it "falls back to question_circle for unknown icon" do
      result = helper.render_situation_icon("unknown_icon")
      expect(result).to include("<svg")
    end
  end

  describe "SITUATION_OPTIONS constant" do
    it "defines options for all four roles" do
      expect(described_class::SITUATION_OPTIONS.keys).to match_array([
        "plaintiff",
        "defendant",
        "judgment_holder",
        "judgment_debtor"
      ])
    end

    it "freezes the constant" do
      expect(described_class::SITUATION_OPTIONS).to be_frozen
    end

    it "includes required fields for each option" do
      described_class::SITUATION_OPTIONS.each do |role, options|
        options.each do |option|
          expect(option).to have_key(:value), "Option in #{role} missing :value"
          expect(option).to have_key(:label), "Option in #{role} missing :label"
          expect(option).to have_key(:description), "Option in #{role} missing :description"
          expect(option).to have_key(:icon), "Option in #{role} missing :icon"
        end
      end
    end
  end

  describe "SITUATION_ICON_MAP constant" do
    it "maps all icon names to symbols" do
      expected_mappings = {
        "plus-circle" => :plus_circle,
        "edit" => :edit,
        "user-plus" => :user_plus,
        "message-circle" => :message_circle,
        "refresh" => :refresh,
        "check" => :check_circle,
        "dollar" => :dollar_sign,
        "alert" => :alert_circle,
        "calendar" => :calendar,
        "alert-triangle" => :alert_triangle
      }

      expect(described_class::SITUATION_ICON_MAP).to eq(expected_mappings)
    end

    it "freezes the constant" do
      expect(described_class::SITUATION_ICON_MAP).to be_frozen
    end
  end
end
