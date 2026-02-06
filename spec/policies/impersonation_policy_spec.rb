# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImpersonationPolicy, type: :policy do
  let(:admin) { create(:user, :admin) }
  let(:super_admin) { create(:user, :super_admin) }
  let(:regular_user) { create(:user) }
  let(:target_user) { create(:user) }
  let(:target_admin) { create(:user, :admin) }

  subject { described_class }

  describe "#impersonate?" do
    context "when user is an admin" do
      it "allows impersonating regular users" do
        expect(subject.new(admin, target_user).impersonate?).to be true
      end

      it "denies impersonating other admins" do
        expect(subject.new(admin, target_admin).impersonate?).to be false
      end

      it "denies impersonating self" do
        expect(subject.new(admin, admin).impersonate?).to be false
      end
    end

    context "when user is a super_admin" do
      it "allows impersonating regular users" do
        expect(subject.new(super_admin, target_user).impersonate?).to be true
      end

      it "denies impersonating other admins" do
        expect(subject.new(super_admin, target_admin).impersonate?).to be false
      end

      it "denies impersonating super_admins" do
        other_super_admin = create(:user, :super_admin)
        expect(subject.new(super_admin, other_super_admin).impersonate?).to be false
      end
    end

    context "when user is a regular user" do
      it "denies impersonating anyone" do
        expect(subject.new(regular_user, target_user).impersonate?).to be false
      end
    end

    context "when user is nil" do
      it "denies impersonating" do
        expect(subject.new(nil, target_user).impersonate?).to be false
      end
    end

    context "when target is nil" do
      it "denies impersonating" do
        expect(subject.new(admin, nil).impersonate?).to be false
      end
    end
  end

  describe "#stop_impersonating?" do
    it "returns true for users with impersonation privileges" do
      expect(subject.new(admin, target_user).stop_impersonating?).to be true
      expect(subject.new(super_admin, target_user).stop_impersonating?).to be true
    end

    it "returns false for regular users without impersonation privileges" do
      expect(subject.new(regular_user, target_user).stop_impersonating?).to be false
    end

    it "returns false for nil users (prevents session tampering)" do
      expect(subject.new(nil, nil).stop_impersonating?).to be false
    end
  end

  describe "#index?" do
    it "allows admins to view impersonation logs" do
      expect(subject.new(admin, nil).index?).to be true
    end

    it "allows super_admins to view impersonation logs" do
      expect(subject.new(super_admin, nil).index?).to be true
    end

    it "denies regular users from viewing impersonation logs" do
      expect(subject.new(regular_user, nil).index?).to be false
    end
  end
end
