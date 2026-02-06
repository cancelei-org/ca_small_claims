# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormDependencies::DependencyMapper do
  # Use singleton instance
  subject(:mapper) { described_class.instance }

  let(:sample_config) do
    {
      "dependencies" => {
        "SC-100" => {
          "stage" => "filing",
          "role" => "plaintiff",
          "next" => [
            { "code" => "SC-104", "reason" => "Service of process", "required" => true },
            { "code" => "SC-103", "reason" => "Fee waiver", "required" => false }
          ],
          "previous" => []
        },
        "SC-104" => {
          "stage" => "service",
          "role" => "plaintiff",
          "next" => [],
          "previous" => [
            { "code" => "SC-100", "reason" => "Initial claim" }
          ]
        }
      },
      "stages" => {
        "filing" => {
          "name" => "Filing",
          "description" => "Initial court filing",
          "order" => 1,
          "icon" => "document",
          "color" => "blue"
        },
        "service" => {
          "name" => "Service",
          "description" => "Serving the defendant",
          "order" => 2,
          "icon" => "mail",
          "color" => "green"
        }
      },
      "sequences" => {
        "plaintiff_claim" => {
          "stage" => "filing",
          "forms" => [
            { "code" => "SC-100" },
            { "code" => "SC-104" }
          ]
        }
      }
    }
  end

  before do
    # Stub the config loading
    allow(mapper).to receive(:load_config).and_return(sample_config)
    mapper.reload!
  end

  describe "#dependencies_for" do
    it "returns dependencies for a given form code" do
      deps = mapper.dependencies_for("SC-100")

      expect(deps["stage"]).to eq("filing")
      expect(deps["role"]).to eq("plaintiff")
      expect(deps["next"]).to be_an(Array)
    end

    it "normalizes form codes" do
      # Normalizer removes spaces, so "sc 100" becomes "SC100" not "SC-100"
      deps1 = mapper.dependencies_for("SC-100")
      deps2 = mapper.dependencies_for("sc-100")

      expect(deps1).to eq(deps2)
      expect(deps1["stage"]).to eq("filing")
    end

    it "returns empty hash for unknown form" do
      deps = mapper.dependencies_for("UNKNOWN")
      expect(deps).to eq({})
    end
  end

  describe "#previous_forms" do
    it "returns previous forms for a given form" do
      previous = mapper.previous_forms("SC-104")

      expect(previous).to be_an(Array)
      expect(previous.first["code"]).to eq("SC-100")
      expect(previous.first["reason"]).to eq("Initial claim")
    end

    it "returns empty array when no previous forms" do
      previous = mapper.previous_forms("SC-100")
      expect(previous).to eq([])
    end
  end

  describe "#next_forms" do
    it "returns next forms for a given form" do
      next_forms = mapper.next_forms("SC-100")

      expect(next_forms).to be_an(Array)
      expect(next_forms.size).to eq(2)
      expect(next_forms.map { |f| f["code"] }).to include("SC-104", "SC-103") # rubocop:disable Rails/Pluck
    end

    it "includes reason and required flag" do
      next_forms = mapper.next_forms("SC-100")
      service_form = next_forms.find { |f| f["code"] == "SC-104" }

      expect(service_form["reason"]).to eq("Service of process")
      expect(service_form["required"]).to be true
    end
  end

  describe "#required_next_forms" do
    it "returns only required next forms" do
      required = mapper.required_next_forms("SC-100")

      expect(required.size).to eq(1)
      expect(required.first["code"]).to eq("SC-104")
    end
  end

  describe "#optional_next_forms" do
    it "returns only optional next forms" do
      optional = mapper.optional_next_forms("SC-100")

      expect(optional.size).to eq(1)
      expect(optional.first["code"]).to eq("SC-103")
    end
  end

  describe "#stage_for" do
    it "returns the stage for a form" do
      stage = mapper.stage_for("SC-100")
      expect(stage).to eq("filing")
    end

    it "returns nil for unknown form" do
      stage = mapper.stage_for("UNKNOWN")
      expect(stage).to be_nil
    end
  end

  describe "#role_for" do
    it "returns the role for a form" do
      role = mapper.role_for("SC-100")
      expect(role).to eq("plaintiff")
    end

    it "returns nil for unknown form" do
      role = mapper.role_for("UNKNOWN")
      expect(role).to be_nil
    end
  end

  describe "#stage_info" do
    it "returns stage information" do
      info = mapper.stage_info("filing")

      expect(info["name"]).to eq("Filing")
      expect(info["description"]).to eq("Initial court filing")
      expect(info["order"]).to eq(1)
      expect(info["icon"]).to eq("document")
      expect(info["color"]).to eq("blue")
    end

    it "returns empty hash for unknown stage" do
      info = mapper.stage_info("unknown")
      expect(info).to eq({})
    end
  end

  describe "#all_stages" do
    it "returns all stages sorted by order" do
      stages = mapper.all_stages

      expect(stages.size).to eq(2)
      expect(stages.first["key"]).to eq("filing")
      expect(stages.second["key"]).to eq("service")
    end

    it "includes key in each stage" do
      stages = mapper.all_stages
      expect(stages.all? { |s| s.key?("key") }).to be true
    end
  end

  describe "#forms_by_stage" do
    it "groups forms by their stage" do
      forms = mapper.forms_by_stage

      expect(forms["filing"]).to include("SC-100")
      expect(forms["service"]).to include("SC-104")
    end

    it "skips forms without a stage" do
      config_with_no_stage = sample_config.deep_dup
      config_with_no_stage["dependencies"]["SC-999"] = { "role" => "plaintiff" }
      allow(mapper).to receive(:load_config).and_return(config_with_no_stage)
      mapper.reload!

      forms = mapper.forms_by_stage
      expect(forms.values.flatten).not_to include("SC-999")
    end
  end

  describe "#sequence" do
    it "returns a specific sequence" do
      seq = mapper.sequence("plaintiff_claim")

      expect(seq["stage"]).to eq("filing")
      expect(seq["forms"]).to be_an(Array)
      expect(seq["forms"].size).to eq(2)
    end

    it "returns empty hash for unknown sequence" do
      seq = mapper.sequence("unknown")
      expect(seq).to eq({})
    end
  end

  describe "#all_sequences" do
    it "returns all sequences" do
      sequences = mapper.all_sequences

      expect(sequences).to be_a(Hash)
      expect(sequences.keys).to include("plaintiff_claim")
    end
  end

  describe "#flowchart_for" do
    let!(:sc100) { create(:form_definition, code: "SC-100", title: "Plaintiff's Claim") }
    let!(:sc104) { create(:form_definition, code: "SC-104", title: "Proof of Service") }

    it "returns a flowchart structure" do
      flowchart = mapper.flowchart_for("SC-100")

      expect(flowchart[:current]).to be_a(Hash)
      expect(flowchart[:current][:code]).to eq("SC-100")
      expect(flowchart[:current][:stage]).to eq("filing")
      expect(flowchart[:previous]).to be_an(Array)
      expect(flowchart[:next]).to be_an(Array)
      expect(flowchart[:stage_flow]).to be_an(Array)
    end

    it "enriches next forms with database info" do
      flowchart = mapper.flowchart_for("SC-100")
      next_form = flowchart[:next].first

      expect(next_form["title"]).to eq("Proof of Service")
      expect(next_form["exists"]).to be true
      expect(next_form["path"]).to include("/forms/")
    end
  end

  describe "#related_forms" do
    let!(:sc100) { create(:form_definition, code: "SC-100") }
    let!(:sc104) { create(:form_definition, code: "SC-104") }

    it "combines previous and next forms" do
      related = mapper.related_forms("SC-104")

      expect(related).to be_an(Array)
      expect(related.map { |f| f["code"] }).to include("SC-100") # rubocop:disable Rails/Pluck
    end

    it "marks relationship type" do
      related = mapper.related_forms("SC-104")
      prev_form = related.find { |f| f["code"] == "SC-100" }

      expect(prev_form["relationship"]).to eq("previous")
    end
  end

  describe "#find_sequence_for" do
    it "finds a sequence matching given forms" do
      sequence = mapper.find_sequence_for([ "SC-100", "SC-104" ])

      expect(sequence).to be_an(Array)
      expect(sequence.first).to eq("plaintiff_claim")
    end

    it "returns nil when no sequence matches" do
      sequence = mapper.find_sequence_for([ "UNKNOWN-1", "UNKNOWN-2" ])
      expect(sequence).to be_nil
    end

    it "normalizes form codes before matching" do
      sequence = mapper.find_sequence_for([ "sc-100", "SC-104" ])
      expect(sequence).to be_an(Array)
    end
  end

  describe "#reload!" do
    it "reloads the configuration" do
      expect(mapper).to receive(:load_config).and_return({})
      mapper.reload!
    end
  end

  describe "private methods" do
    describe "#normalize_code" do
      it "uppercases and removes spaces" do
        normalized = mapper.send(:normalize_code, "sc-100")
        expect(normalized).to eq("SC-100")

        normalized = mapper.send(:normalize_code, "sc 100")
        expect(normalized).to eq("SC100")  # Spaces are removed, dash remains
      end
    end

    describe "#enrich_form_reference" do
      let!(:form_def) { create(:form_definition, code: "SC-100", title: "Test Form") }

      it "adds database information to form reference" do
        form_ref = { "code" => "SC-100", "reason" => "Test" }
        enriched = mapper.send(:enrich_form_reference, form_ref)

        expect(enriched["title"]).to eq("Test Form")
        expect(enriched["exists"]).to be true
        expect(enriched["path"]).to include("/forms/")
      end

      it "handles non-existent forms gracefully" do
        form_ref = { "code" => "UNKNOWN", "reason" => "Test" }
        enriched = mapper.send(:enrich_form_reference, form_ref)

        expect(enriched["title"]).to be_nil
        expect(enriched["exists"]).to be false
        expect(enriched["path"]).to be_nil
      end
    end

    describe "#build_stage_flow" do
      it "marks stages as completed, current, or upcoming" do
        flow = mapper.send(:build_stage_flow, "service")

        filing_stage = flow.find { |s| s["key"] == "filing" }
        service_stage = flow.find { |s| s["key"] == "service" }

        expect(filing_stage["status"]).to eq("completed")
        expect(service_stage["status"]).to eq("current")
      end

      it "returns empty array for nil stage" do
        flow = mapper.send(:build_stage_flow, nil)
        expect(flow).to eq([])
      end
    end
  end
end
