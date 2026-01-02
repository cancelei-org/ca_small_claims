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

  describe "instance methods" do
    let(:workflow) { create(:workflow) }
    let!(:step1) { create(:workflow_step, workflow: workflow, position: 1) }
    let!(:step2) { create(:workflow_step, workflow: workflow, position: 2) }

    describe "#first_step" do
      it { expect(workflow.first_step).to eq(step1) }
    end

    describe "#step_at" do
      it { expect(workflow.step_at(2)).to eq(step2) }
    end

    describe "#next_step" do
      it { expect(workflow.next_step(1)).to eq(step2) }
      it { expect(workflow.next_step(2)).to be_nil }
    end

    describe "#previous_step" do
      it { expect(workflow.previous_step(2)).to eq(step1) }
      it { expect(workflow.previous_step(1)).to be_nil }
    end

    describe "#total_steps" do
      it { expect(workflow.total_steps).to eq(2) }
    end
  end
end
