# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflow, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:category).optional }
    it { is_expected.to have_many(:workflow_steps).dependent(:destroy) }
    it { is_expected.to have_many(:form_definitions).through(:workflow_steps) }
    it { is_expected.to have_many(:submissions).dependent(:nullify) }
  end

  describe "validations" do
    subject { build(:workflow) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_uniqueness_of(:slug) }
  end

  describe "scopes" do
    let!(:category) { create(:category, slug: "small-claims") }
    let!(:active_workflow) { create(:workflow, active: true, category: category, position: 2) }
    let!(:inactive_workflow) { create(:workflow, active: false) }
    let!(:other_workflow) { create(:workflow, active: true, position: 1, name: "Alpha") }

    describe ".active" do
      it "returns only active workflows" do
        expect(Workflow.active).to include(active_workflow, other_workflow)
        expect(Workflow.active).not_to include(inactive_workflow)
      end
    end

    describe ".by_category" do
      it "returns workflows by category slug" do
        expect(Workflow.by_category("small-claims")).to contain_exactly(active_workflow)
      end
    end

    describe ".by_category_id" do
      it "returns workflows by category id" do
        expect(Workflow.by_category_id(category.id)).to contain_exactly(active_workflow)
      end
    end

    describe ".ordered" do
      it "orders by position then name" do
        Workflow.delete_all
        w1 = create(:workflow, position: 2, name: "Bravo")
        w2 = create(:workflow, position: 1, name: "Zulu")
        w3 = create(:workflow, position: 1, name: "Alpha")

        expect(Workflow.ordered.to_a).to eq([ w3, w2, w1 ])
      end
    end
  end

  describe "instance methods" do
    let(:workflow) { create(:workflow, slug: "test-workflow") }
    let!(:step1) { create(:workflow_step, workflow: workflow, position: 1, required: true) }
    let!(:step2) { create(:workflow_step, workflow: workflow, position: 2, required: false) }
    let!(:step3) { create(:workflow_step, workflow: workflow, position: 3, required: true) }

    describe "#first_step" do
      it { expect(workflow.first_step).to eq(step1) }

      it "returns nil for empty workflow" do
        empty_workflow = create(:workflow)
        expect(empty_workflow.first_step).to be_nil
      end
    end

    describe "#step_at" do
      it { expect(workflow.step_at(2)).to eq(step2) }
      it { expect(workflow.step_at(99)).to be_nil }
    end

    describe "#next_step" do
      it { expect(workflow.next_step(1)).to eq(step2) }
      it { expect(workflow.next_step(2)).to eq(step3) }
      it { expect(workflow.next_step(3)).to be_nil }
    end

    describe "#previous_step" do
      it { expect(workflow.previous_step(3)).to eq(step2) }
      it { expect(workflow.previous_step(2)).to eq(step1) }
      it { expect(workflow.previous_step(1)).to be_nil }
    end

    describe "#total_steps" do
      it { expect(workflow.total_steps).to eq(3) }

      it "returns 0 for empty workflow" do
        expect(create(:workflow).total_steps).to eq(0)
      end
    end

    describe "#required_steps" do
      it "returns only required steps" do
        expect(workflow.required_steps).to contain_exactly(step1, step3)
      end
    end

    describe "#to_param" do
      it "returns slug for URL generation" do
        expect(workflow.to_param).to eq("test-workflow")
      end
    end
  end
end
