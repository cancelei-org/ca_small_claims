# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Metrics", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  describe "GET /metrics" do
    context "as an admin user" do
      before do
        login_as(admin_user, scope: :user)
      end

      it "returns http success" do
        get metrics_path

        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("application/json")
      end

      it "returns cache metrics" do
        allow(Cache::Metrics).to receive(:hits).and_return(100)
        allow(Cache::Metrics).to receive(:misses).and_return(20)
        allow(Cache::Metrics).to receive(:ratio).and_return(0.833)

        get metrics_path

        json = JSON.parse(response.body)
        expect(json["cache"]["hits"]).to eq(100)
        expect(json["cache"]["misses"]).to eq(20)
        expect(json["cache"]["hit_ratio"]).to eq(0.833)
      end

      it "handles nil cache metrics gracefully" do
        allow(Cache::Metrics).to receive(:hits).and_return(nil)
        allow(Cache::Metrics).to receive(:misses).and_return(nil)
        allow(Cache::Metrics).to receive(:ratio).and_return(nil)

        get metrics_path

        json = JSON.parse(response.body)
        expect(json["cache"]["hits"]).to eq(0)
        expect(json["cache"]["misses"]).to eq(0)
      end

      it "returns storage metrics" do
        storage_summary = {
          total_size_mb: 150.5,
          file_count: 42,
          oldest_file: 30.days.ago
        }
        allow(Storage::Usage).to receive(:summary).and_return(storage_summary)

        get metrics_path

        json = JSON.parse(response.body)
        expect(json["storage"]["total_size_mb"]).to eq(150.5)
        expect(json["storage"]["file_count"]).to eq(42)
      end
    end

    context "as a regular user" do
      before do
        login_as(regular_user, scope: :user)
      end

      it "denies access" do
        get metrics_path

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Admin access required")
      end
    end

    context "as a guest" do
      it "redirects to sign in" do
        get metrics_path

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
