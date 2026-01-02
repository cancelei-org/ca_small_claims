# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormFeedbackPolicy do
  let(:feedback) { build(:form_feedback) }
  subject { described_class.new(user, feedback) }

  context "when user is an admin" do
    let(:user) { build(:user, :admin) }

    it { is_expected.to permit_actions([ :index, :show, :update, :acknowledge, :resolve ]) }
    it { is_expected.to permit_action(:create) }
  end

  context "when user is not an admin" do
    let(:user) { build(:user, admin: false) }

    it { is_expected.to forbid_actions([ :index, :show, :update, :acknowledge, :resolve ]) }
    it { is_expected.to permit_action(:create) }
  end

  context "when user is nil" do
    let(:user) { nil }

    it { is_expected.to forbid_actions([ :index, :show, :update, :acknowledge, :resolve ]) }
    it { is_expected.to permit_action(:create) }
  end

  describe "Scope" do
    let(:scope) { FormFeedback.all }
    let!(:f1) { create(:form_feedback) }
    subject { described_class::Scope.new(user, scope).resolve }

    context "when user is an admin" do
      let(:user) { create(:user, :admin) }
      it { expect(subject).to include(f1) }
    end

    context "when user is not an admin" do
      let(:user) { create(:user, admin: false) }
      it { expect(subject).to be_empty }
    end
  end
end
