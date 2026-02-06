# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormFinder::Engine do
  describe "#initialize" do
    it "initializes with default state when no session provided" do
      engine = described_class.new

      expect(engine.current_step).to eq(:role)
      expect(engine.current_step_number).to eq(1)
      expect(engine.answers[:role]).to be_nil
    end

    it "initializes with provided session state" do
      session_state = {
        step: 2,
        answers: { role: "plaintiff", situation: nil }
      }.with_indifferent_access

      engine = described_class.new(session_state)

      expect(engine.current_step).to eq(:situation)
      expect(engine.answers[:role]).to eq("plaintiff")
    end
  end

  describe "#start" do
    it "resets state to default" do
      engine = described_class.new({ step: 3, answers: { role: "defendant" } })
      engine.start

      expect(engine.current_step).to eq(:role)
      expect(engine.answers[:role]).to be_nil
    end
  end

  describe "#advance" do
    context "on role step" do
      it "advances when role is selected" do
        engine = described_class.new
        engine.advance(role: "plaintiff")

        expect(engine.current_step).to eq(:situation)
      end

      it "does not advance when role is not selected" do
        engine = described_class.new

        expect(engine.advance).to be false
        expect(engine.current_step).to eq(:role)
      end
    end

    context "on situation step" do
      it "advances when situation is selected" do
        engine = described_class.new({
          step: 2,
          answers: { role: "plaintiff" }
        }.with_indifferent_access)

        engine.advance(situation: "new_case")

        expect(engine.current_step).to eq(:details)
      end

      it "skips details step when not needed" do
        engine = described_class.new({
          step: 2,
          answers: { role: "plaintiff" }
        }.with_indifferent_access)

        engine.advance(situation: "modify_claim")

        expect(engine.current_step).to eq(:recommendations)
      end
    end

    context "on details step" do
      it "advances to recommendations" do
        engine = described_class.new({
          step: 3,
          answers: { role: "plaintiff", situation: "new_case" }
        }.with_indifferent_access)

        engine.advance(multiple_parties: "true", needs_fee_waiver: "false")

        expect(engine.current_step).to eq(:recommendations)
        expect(engine.answers[:multiple_parties]).to be true
        expect(engine.answers[:needs_fee_waiver]).to be false
      end
    end

    context "on recommendations step" do
      it "does not advance past final step" do
        engine = described_class.new({
          step: 4,
          answers: { role: "plaintiff", situation: "new_case" }
        }.with_indifferent_access)

        expect(engine.advance).to be false
        expect(engine.current_step).to eq(:recommendations)
      end
    end
  end

  describe "#go_back" do
    it "moves to previous step" do
      engine = described_class.new({
        step: 2,
        answers: { role: "plaintiff" }
      }.with_indifferent_access)

      engine.go_back

      expect(engine.current_step).to eq(:role)
    end

    it "does not go back on first step" do
      engine = described_class.new

      expect(engine.go_back).to be false
      expect(engine.current_step).to eq(:role)
    end

    it "skips details step backwards when not needed" do
      engine = described_class.new({
        step: 4,
        answers: { role: "plaintiff", situation: "modify_claim" }
      }.with_indifferent_access)

      engine.go_back

      expect(engine.current_step).to eq(:situation)
    end
  end

  describe "#progress" do
    it "returns progress information" do
      engine = described_class.new({
        step: 2,
        answers: { role: "plaintiff" }
      }.with_indifferent_access)

      progress = engine.progress

      expect(progress[:current]).to eq(2)
      expect(progress[:total]).to eq(4)
      expect(progress[:percentage]).to eq(25)
    end
  end

  describe "#needs_details_step?" do
    it "returns true for plaintiff new_case" do
      engine = described_class.new({
        step: 2,
        answers: { role: "plaintiff", situation: "new_case" }
      }.with_indifferent_access)

      expect(engine.needs_details_step?).to be true
    end

    it "returns true for defendant counter_claim" do
      engine = described_class.new({
        step: 2,
        answers: { role: "defendant", situation: "counter_claim" }
      }.with_indifferent_access)

      expect(engine.needs_details_step?).to be true
    end

    it "returns false for other situations" do
      engine = described_class.new({
        step: 2,
        answers: { role: "plaintiff", situation: "modify_claim" }
      }.with_indifferent_access)

      expect(engine.needs_details_step?).to be false
    end
  end

  describe "#to_session" do
    it "returns deep copy of state" do
      engine = described_class.new
      engine.advance(role: "plaintiff")

      session = engine.to_session

      expect(session[:step]).to eq(2)
      expect(session[:answers][:role]).to eq("plaintiff")
    end
  end
end
