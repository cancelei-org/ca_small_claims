# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminPolicy do
  subject { described_class.new(user, :admin) }

  context "when user is an admin" do
    let(:user) { build(:user, :admin) }

    it { is_expected.to permit_action(:access) }
    it { is_expected.to permit_action(:dashboard) }
  end

  context "when user is not an admin" do
    let(:user) { build(:user, admin: false) }

    it { is_expected.to forbid_action(:access) }
    it { is_expected.to forbid_action(:dashboard) }
  end

  context "when user is nil" do
    let(:user) { nil }

    it { is_expected.to forbid_action(:access) }
    it { is_expected.to forbid_action(:dashboard) }
  end
end
