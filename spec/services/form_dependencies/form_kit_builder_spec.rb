# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormDependencies::FormKitBuilder do
  subject(:builder) { described_class.instance }

  let(:sample_config) do
    {
      "form_kits" => {
        "plaintiff_starter" => {
          "name" => "Plaintiff Starter Kit",
          "description" => "Essential forms to file a claim",
          "icon" => "gavel",
          "role" => "plaintiff",
          "stage" => "filing",
          "estimated_time" => 30,
          "forms" => [
            { "code" => "SC-100", "required" => true, "order" => 1 },
            { "code" => "SC-103", "required" => false, "order" => 2 }
          ]
        },
        "defendant_response" => {
          "name" => "Defendant Response Kit",
          "description" => "Forms to respond to a claim",
          "icon" => "shield",
          "role" => "defendant",
          "stage" => "response",
          "estimated_time" => 20,
          "forms" => [
            { "code" => "SC-120", "required" => true, "order" => 1 }
          ]
        }
      }
    }
  end

  before do
    allow(builder).to receive(:load_config).and_return(sample_config)
    # Reset singleton state
    builder.instance_variable_set(:@config, sample_config)
  end

  describe "#all_kits" do
    it "returns all available kits" do
      kits = builder.all_kits

      expect(kits).to be_an(Array)
      expect(kits.size).to eq(2)
      expect(kits.map { |k| k[:key] }).to match_array([ "plaintiff_starter", "defendant_response" ]) # rubocop:disable Rails/Pluck
    end

    it "includes kit metadata" do
      kits = builder.all_kits
      plaintiff_kit = kits.find { |k| k[:key] == "plaintiff_starter" }

      expect(plaintiff_kit[:name]).to eq("Plaintiff Starter Kit")
      expect(plaintiff_kit[:description]).to eq("Essential forms to file a claim")
      expect(plaintiff_kit[:icon]).to eq("gavel")
      expect(plaintiff_kit[:role]).to eq("plaintiff")
      expect(plaintiff_kit[:stage]).to eq("filing")
      expect(plaintiff_kit[:estimated_time]).to eq(30)
    end

    it "includes form details" do
      kits = builder.all_kits
      plaintiff_kit = kits.find { |k| k[:key] == "plaintiff_starter" }

      expect(plaintiff_kit[:forms]).to be_an(Array)
      expect(plaintiff_kit[:forms].size).to eq(2)
      expect(plaintiff_kit[:form_count]).to eq(2)
    end
  end

  describe "#kit" do
    it "returns a specific kit by key" do
      kit = builder.kit("plaintiff_starter")

      expect(kit).to be_a(Hash)
      expect(kit[:key]).to eq("plaintiff_starter")
      expect(kit[:name]).to eq("Plaintiff Starter Kit")
    end

    it "returns nil for unknown kit" do
      kit = builder.kit("unknown_kit")
      expect(kit).to be_nil
    end
  end

  describe "#kits_for_role" do
    it "returns kits for a specific role" do
      plaintiff_kits = builder.kits_for_role("plaintiff")

      expect(plaintiff_kits.size).to eq(1)
      expect(plaintiff_kits.first[:key]).to eq("plaintiff_starter")
    end

    it "includes kits with role 'both'" do
      config_with_both = sample_config.deep_dup
      config_with_both["form_kits"]["common_kit"] = {
        "name" => "Common Kit",
        "role" => "both",
        "stage" => "filing",
        "forms" => []
      }
      allow(builder).to receive(:load_config).and_return(config_with_both)
      builder.instance_variable_set(:@config, config_with_both)

      plaintiff_kits = builder.kits_for_role("plaintiff")

      expect(plaintiff_kits.map { |k| k[:key] }).to include("common_kit") # rubocop:disable Rails/Pluck
    end

    it "returns empty array for unknown role" do
      kits = builder.kits_for_role("unknown_role")
      expect(kits).to eq([])
    end
  end

  describe "#kits_for_stage" do
    it "returns kits for a specific stage" do
      filing_kits = builder.kits_for_stage("filing")

      expect(filing_kits.size).to eq(1)
      expect(filing_kits.first[:key]).to eq("plaintiff_starter")
    end

    it "returns empty array for unknown stage" do
      kits = builder.kits_for_stage("unknown_stage")
      expect(kits).to eq([])
    end
  end

  describe "#recommended_kits_for" do
    let!(:sc100) { create(:form_definition, code: "SC-100") }

    before do
      # Stub DependencyMapper
      mapper = instance_double(FormDependencies::DependencyMapper)
      allow(FormDependencies::DependencyMapper).to receive(:instance).and_return(mapper)
      allow(mapper).to receive(:stage_for).and_return("filing")
      allow(mapper).to receive(:role_for).and_return("plaintiff")
      allow(mapper).to receive(:stage_info).and_return({})
      allow(mapper).to receive(:all_stages).and_return([
        { "key" => "filing", "order" => 1 },
        { "key" => "service", "order" => 2 }
      ])
    end

    it "returns recommended kits for a form" do
      kits = builder.recommended_kits_for("SC-100")

      expect(kits).to be_an(Array)
      expect(kits).not_to be_empty
      expect(kits.size).to be <= 3
    end

    it "includes kits that contain the form" do
      kits = builder.recommended_kits_for("SC-100")
      kit_keys = kits.map { |k| k[:key] } # rubocop:disable Rails/Pluck

      expect(kit_keys).to include("plaintiff_starter")
    end
  end

  describe "#kit_containing" do
    it "finds kit containing a specific form" do
      kit = builder.kit_containing("SC-100")

      expect(kit).not_to be_nil
      expect(kit[:key]).to eq("plaintiff_starter")
    end

    it "normalizes form codes" do
      kit1 = builder.kit_containing("SC-100")
      kit2 = builder.kit_containing("sc-100")

      expect(kit1[:key]).to eq(kit2[:key])
    end

    it "returns nil when form not in any kit" do
      kit = builder.kit_containing("UNKNOWN")
      expect(kit).to be_nil
    end
  end

  describe "#build_custom_kit" do
    let!(:sc100) { create(:form_definition, code: "SC-100", title: "Plaintiff's Claim") }
    let!(:sc120) { create(:form_definition, code: "SC-120", title: "Defendant's Claim") }

    it "creates a custom kit from form codes" do
      kit = builder.build_custom_kit([ "SC-100", "SC-120" ])

      expect(kit[:key]).to eq("custom")
      expect(kit[:forms].size).to eq(2)
      expect(kit[:form_count]).to eq(2)
    end

    it "accepts custom kit name" do
      kit = builder.build_custom_kit([ "SC-100" ], name: "My Kit")

      expect(kit[:name]).to eq("My Kit")
    end

    it "includes form details from database" do
      kit = builder.build_custom_kit([ "SC-100" ])
      form = kit[:forms].first

      expect(form[:code]).to eq("SC-100")
      expect(form[:title]).to eq("Plaintiff's Claim")
      expect(form[:exists]).to be true
      expect(form[:path]).to include("/forms/")
    end

    it "handles non-existent forms gracefully" do
      kit = builder.build_custom_kit([ "UNKNOWN" ])
      form = kit[:forms].first

      expect(form[:code]).to eq("UNKNOWN")
      expect(form[:title]).to eq("UNKNOWN")
      expect(form[:exists]).to be false
      expect(form[:path]).to be_nil
    end

    it "estimates time based on form count" do
      kit = builder.build_custom_kit([ "SC-100", "SC-120" ])

      # estimated_time returns a string like "30-45 minutes"
      expect(kit[:estimated_time]).to be_a(String)
      expect(kit[:estimated_time]).to include("minute")
    end

    it "sets completion percentage to 0" do
      kit = builder.build_custom_kit([ "SC-100" ])

      expect(kit[:completion_percentage]).to eq(0)
    end
  end

  describe "private methods" do
    describe "#build_kit" do
      let!(:sc100) { create(:form_definition, code: "SC-100", title: "Plaintiff's Claim") }

      it "enriches kit with form details" do
        kit_config = sample_config["form_kits"]["plaintiff_starter"]
        kit = builder.send(:build_kit, "plaintiff_starter", kit_config)

        expect(kit[:key]).to eq("plaintiff_starter")
        expect(kit[:forms].first[:title]).to eq("Plaintiff's Claim")
      end

      it "calculates form count" do
        kit_config = sample_config["form_kits"]["plaintiff_starter"]
        kit = builder.send(:build_kit, "plaintiff_starter", kit_config)

        expect(kit[:form_count]).to eq(2)
      end
    end

    describe "#kit_contains_form?" do
      it "returns true when kit contains the form" do
        kit = { forms: [ { code: "SC-100" }, { code: "SC-103" } ] }
        result = builder.send(:kit_contains_form?, kit, "SC-100")

        expect(result).to be true
      end

      it "normalizes form codes before checking" do
        kit = { forms: [ { code: "SC-100" } ] }
        result = builder.send(:kit_contains_form?, kit, "sc-100")

        expect(result).to be true
      end

      it "returns false when kit does not contain the form" do
        kit = { forms: [ { code: "SC-100" } ] }
        result = builder.send(:kit_contains_form?, kit, "SC-120")

        expect(result).to be false
      end
    end
  end
end
