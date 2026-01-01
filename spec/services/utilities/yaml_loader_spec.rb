# frozen_string_literal: true

require "rails_helper"

RSpec.describe Utilities::YamlLoader do
  let(:temp_dir) { Rails.root.join("tmp", "yaml_loader_test") }

  before do
    FileUtils.mkdir_p(temp_dir)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe ".load_file" do
    context "with valid YAML file" do
      let(:yaml_path) { temp_dir.join("test.yml") }

      before do
        File.write(yaml_path, <<~YAML)
          form:
            code: SC-100
            title: Test Form
          sections:
            general:
              fields:
                - name: test_field
                  type: text
        YAML
      end

      it "loads and parses YAML with symbolized keys by default" do
        result = described_class.load_file(yaml_path)

        expect(result).to be_a(Hash)
        expect(result[:form]).to be_a(Hash)
        expect(result[:form][:code]).to eq("SC-100")
        expect(result[:sections][:general][:fields]).to be_an(Array)
      end

      it "can load with string keys" do
        result = described_class.load_file(yaml_path, symbolize_names: false)

        expect(result["form"]).to be_a(Hash)
        expect(result["form"]["code"]).to eq("SC-100")
      end
    end

    context "with file containing Date" do
      let(:yaml_path) { temp_dir.join("date_test.yml") }

      before do
        File.write(yaml_path, <<~YAML)
          created_at: 2024-01-15
        YAML
      end

      it "permits Date class by default" do
        result = described_class.load_file(yaml_path)

        expect(result[:created_at]).to be_a(Date)
        expect(result[:created_at]).to eq(Date.new(2024, 1, 15))
      end
    end

    context "with non-existent file" do
      it "raises LoadError" do
        expect {
          described_class.load_file(temp_dir.join("nonexistent.yml"))
        }.to raise_error(Utilities::YamlLoader::LoadError, /File not found/)
      end
    end

    context "with invalid YAML syntax" do
      let(:yaml_path) { temp_dir.join("invalid.yml") }

      before do
        File.write(yaml_path, <<~YAML)
          invalid: yaml: content:
            - bad indentation
          missing: quote
        YAML
      end

      it "raises LoadError with syntax error message" do
        expect {
          described_class.load_file(yaml_path)
        }.to raise_error(Utilities::YamlLoader::LoadError, /YAML syntax error/)
      end
    end
  end

  describe ".safe_load_file" do
    context "with valid file" do
      let(:yaml_path) { temp_dir.join("safe_test.yml") }

      before do
        File.write(yaml_path, "key: value\n")
      end

      it "returns success result with data" do
        result = described_class.safe_load_file(yaml_path)

        expect(result[:success]).to be true
        expect(result[:data]).to eq({ key: "value" })
        expect(result[:error]).to be_nil
      end
    end

    context "with invalid file" do
      it "returns failure result with error" do
        result = described_class.safe_load_file(temp_dir.join("nonexistent.yml"))

        expect(result[:success]).to be false
        expect(result[:data]).to be_nil
        expect(result[:error]).to include("File not found")
      end
    end
  end

  describe ".parse" do
    it "parses valid YAML string" do
      yaml = "name: test\nvalue: 123"
      result = described_class.parse(yaml)

      expect(result).to eq({ name: "test", value: 123 })
    end

    it "parses with string keys when specified" do
      yaml = "name: test"
      result = described_class.parse(yaml, symbolize_names: false)

      expect(result).to eq({ "name" => "test" })
    end

    it "raises LoadError for invalid YAML" do
      expect {
        described_class.parse("invalid: yaml: syntax")
      }.to raise_error(Utilities::YamlLoader::LoadError)
    end
  end

  describe ".safe_parse" do
    it "returns success for valid YAML" do
      result = described_class.safe_parse("key: value")

      expect(result[:success]).to be true
      expect(result[:data]).to eq({ key: "value" })
    end

    it "returns failure for invalid YAML" do
      result = described_class.safe_parse("invalid: yaml: syntax:")

      expect(result[:success]).to be false
      expect(result[:error]).to be_present
    end
  end

  describe ".load_directory" do
    before do
      File.write(temp_dir.join("file1.yml"), "name: first")
      File.write(temp_dir.join("file2.yml"), "name: second")
      File.write(temp_dir.join("not_yaml.txt"), "ignored")
    end

    it "loads all YAML files in directory" do
      result = described_class.load_directory(temp_dir)

      expect(result.keys).to contain_exactly("file1", "file2")
      expect(result["file1"]).to eq({ name: "first" })
      expect(result["file2"]).to eq({ name: "second" })
    end

    it "does not include non-YAML files" do
      result = described_class.load_directory(temp_dir)

      expect(result.keys).not_to include("not_yaml")
    end
  end

  describe ".load_directory_recursive" do
    before do
      FileUtils.mkdir_p(temp_dir.join("subdir"))
      FileUtils.mkdir_p(temp_dir.join("_shared"))

      File.write(temp_dir.join("root.yml"), "level: root")
      File.write(temp_dir.join("subdir", "nested.yml"), "level: nested")
      File.write(temp_dir.join("_shared", "shared.yml"), "level: shared")
    end

    it "loads files recursively" do
      result = described_class.load_directory_recursive(temp_dir)

      expect(result.keys).to include("root", "subdir/nested", "_shared/shared")
    end

    it "respects exclude patterns" do
      result = described_class.load_directory_recursive(temp_dir, exclude: [ "_shared/" ])

      expect(result.keys).to contain_exactly("root", "subdir/nested")
      expect(result.keys).not_to include("_shared/shared")
    end
  end

  describe ".valid?" do
    it "returns true for valid YAML file" do
      path = temp_dir.join("valid.yml")
      File.write(path, "key: value")

      expect(described_class.valid?(path)).to be true
    end

    it "returns false for invalid YAML file" do
      path = temp_dir.join("invalid.yml")
      File.write(path, "invalid: yaml: syntax:")

      expect(described_class.valid?(path)).to be false
    end

    it "returns false for non-existent file" do
      expect(described_class.valid?(temp_dir.join("nonexistent.yml"))).to be false
    end
  end

  describe "DEFAULT_OPTIONS" do
    it "symbolizes names by default" do
      expect(described_class::DEFAULT_OPTIONS[:symbolize_names]).to be true
    end

    it "permits Symbol class" do
      expect(described_class::DEFAULT_PERMITTED_CLASSES).to include(Symbol)
    end

    it "permits Date class" do
      expect(described_class::DEFAULT_PERMITTED_CLASSES).to include(Date)
    end
  end

  describe "instance methods" do
    subject(:loader) { described_class.new }

    let(:yaml_path) { temp_dir.join("instance_test.yml") }

    before do
      File.write(yaml_path, "test: value")
    end

    it "delegates load_file to class method" do
      expect(loader.load_file(yaml_path)).to eq({ test: "value" })
    end

    it "delegates safe_load_file to class method" do
      result = loader.safe_load_file(yaml_path)
      expect(result[:success]).to be true
    end

    it "delegates parse to class method" do
      expect(loader.parse("key: val")).to eq({ key: "val" })
    end

    it "delegates valid? to class method" do
      expect(loader.valid?(yaml_path)).to be true
    end
  end
end
