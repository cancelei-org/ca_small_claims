# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormFinder::Recommender do
  let!(:sc100) { create(:form_definition, code: "SC-100", title: "Plaintiff's Claim") }
  let!(:sc100a) { create(:form_definition, code: "SC-100A", title: "Other Plaintiffs or Defendants") }
  let!(:sc103) { create(:form_definition, code: "SC-103", title: "Fee Waiver") }
  let!(:sc114) { create(:form_definition, code: "SC-114", title: "Request to Amend Claim") }
  let!(:sc120) { create(:form_definition, code: "SC-120", title: "Defendant's Claim") }
  let!(:sc120a) { create(:form_definition, code: "SC-120A", title: "Other Plaintiffs (Defendant's Claim)") }
  let!(:sc132) { create(:form_definition, code: "SC-132", title: "Acknowledgment of Satisfaction") }
  let!(:sc221) { create(:form_definition, code: "SC-221", title: "Subpoena") }
  let!(:sc223) { create(:form_definition, code: "SC-223", title: "Request for Payment Plan") }
  let!(:sc225) { create(:form_definition, code: "SC-225", title: "Order on Payment Plan") }
  let!(:sc300) { create(:form_definition, code: "SC-300", title: "Petition for Writ") }
  let!(:sc108) { create(:form_definition, code: "SC-108", title: "Request to Correct Judgment") }
  let!(:ej001) { create(:form_definition, code: "EJ-001", title: "Abstract of Judgment") }

  describe "#recommend" do
    context "plaintiff starting new case" do
      it "recommends SC-100" do
        recommender = described_class.new(role: "plaintiff", situation: "new_case")
        result = recommender.recommend

        expect(result[:forms].map(&:code)).to include("SC-100")
        expect(result[:next_steps]).to be_present
      end

      it "includes SC-100A when multiple parties" do
        recommender = described_class.new(
          role: "plaintiff",
          situation: "new_case",
          multiple_parties: true
        )
        result = recommender.recommend

        expect(result[:forms].map(&:code)).to include("SC-100", "SC-100A")
      end

      it "includes SC-103 when fee waiver needed" do
        recommender = described_class.new(
          role: "plaintiff",
          situation: "new_case",
          needs_fee_waiver: true
        )
        result = recommender.recommend

        expect(result[:forms].map(&:code)).to include("SC-100", "SC-103")
      end

      it "includes workflow reference" do
        workflow = create(:workflow, slug: "plaintiff_claim")
        recommender = described_class.new(role: "plaintiff", situation: "new_case")
        result = recommender.recommend

        expect(result[:workflow]).to eq(workflow)
      end
    end

    context "plaintiff modifying claim" do
      it "recommends SC-114" do
        recommender = described_class.new(role: "plaintiff", situation: "modify_claim")
        result = recommender.recommend

        expect(result[:forms].map(&:code)).to eq([ "SC-114" ])
      end
    end

    context "plaintiff subpoenaing witness" do
      it "recommends SC-221" do
        recommender = described_class.new(role: "plaintiff", situation: "subpoena_witness")
        result = recommender.recommend

        expect(result[:forms].map(&:code)).to eq([ "SC-221" ])
      end
    end

    context "defendant responding only" do
      it "returns empty forms with info message" do
        recommender = described_class.new(role: "defendant", situation: "respond_only")
        result = recommender.recommend

        expect(result[:forms]).to be_empty
        expect(result[:info]).to be_present
        expect(result[:next_steps]).to be_present
      end
    end

    context "defendant filing counter-claim" do
      it "recommends SC-120" do
        recommender = described_class.new(role: "defendant", situation: "counter_claim")
        result = recommender.recommend

        expect(result[:forms].map(&:code)).to include("SC-120")
      end

      it "includes SC-120A when multiple parties" do
        recommender = described_class.new(
          role: "defendant",
          situation: "counter_claim",
          multiple_parties: true
        )
        result = recommender.recommend

        expect(result[:forms].map(&:code)).to include("SC-120", "SC-120A")
      end
    end

    context "judgment holder recording payment" do
      it "recommends SC-132" do
        recommender = described_class.new(role: "judgment_holder", situation: "record_payment")
        result = recommender.recommend

        expect(result[:forms].map(&:code)).to eq([ "SC-132" ])
      end
    end

    context "judgment holder enforcing judgment" do
      it "recommends EJ-001" do
        recommender = described_class.new(role: "judgment_holder", situation: "enforce_judgment")
        result = recommender.recommend

        expect(result[:forms].map(&:code)).to eq([ "EJ-001" ])
      end
    end

    context "judgment holder correcting judgment" do
      it "recommends SC-108" do
        recommender = described_class.new(role: "judgment_holder", situation: "correct_judgment")
        result = recommender.recommend

        expect(result[:forms].map(&:code)).to eq([ "SC-108" ])
      end
    end

    context "judgment debtor requesting payment plan" do
      it "recommends SC-223" do
        recommender = described_class.new(role: "judgment_debtor", situation: "payment_plan")
        result = recommender.recommend

        expect(result[:forms].map(&:code)).to eq([ "SC-223" ])
      end
    end

    context "judgment debtor modifying payments" do
      it "recommends SC-225" do
        recommender = described_class.new(role: "judgment_debtor", situation: "modify_payments")
        result = recommender.recommend

        expect(result[:forms].map(&:code)).to eq([ "SC-225" ])
      end
    end

    context "judgment debtor appealing" do
      it "recommends SC-300 with info" do
        recommender = described_class.new(role: "judgment_debtor", situation: "appeal")
        result = recommender.recommend

        expect(result[:forms].map(&:code)).to eq([ "SC-300" ])
        expect(result[:info]).to be_present
      end
    end

    context "unknown combination" do
      it "returns empty recommendation with help message" do
        recommender = described_class.new(role: "unknown", situation: "unknown")
        result = recommender.recommend

        expect(result[:forms]).to be_empty
        expect(result[:info]).to include("couldn't find")
      end
    end
  end
end
