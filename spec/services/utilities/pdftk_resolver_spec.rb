# frozen_string_literal: true

require "rails_helper"

RSpec.describe Utilities::PdftkResolver do
  before do
    # Reset cached values before each test
    described_class.reset!
  end

  after do
    # Clean up environment
    ENV.delete("PDFTK_PATH")
    described_class.reset!
  end

  describe ".path" do
    context "when PDFTK_PATH environment variable is set" do
      it "returns the environment path if executable" do
        # Create a temporary executable for testing
        temp_path = Rails.root.join("tmp", "test_pdftk")
        File.write(temp_path, "#!/bin/bash\necho 'pdftk'")
        File.chmod(0o755, temp_path)

        ENV["PDFTK_PATH"] = temp_path.to_s

        expect(described_class.path).to eq(temp_path.to_s)
      ensure
        FileUtils.rm_f(temp_path)
      end
    end

    context "when pdftk is in a standard location" do
      it "returns a path string" do
        expect(described_class.path).to be_a(String)
        expect(described_class.path).not_to be_empty
      end
    end

    context "when pdftk is not found" do
      before do
        allow(File).to receive(:exist?).and_return(false)
        allow(File).to receive(:executable?).and_return(false)
        allow(described_class).to receive(:`).and_return("")
      end

      it 'returns "pdftk" as fallback' do
        expect(described_class.path).to eq("pdftk")
      end
    end
  end

  describe ".available?" do
    it "returns a boolean" do
      expect(described_class.available?).to be_in([ true, false ])
    end

    context "when pdftk exists and is executable" do
      before do
        allow(described_class).to receive(:path).and_return("/usr/bin/pdftk")
        allow(File).to receive(:exist?).with("/usr/bin/pdftk").and_return(true)
        allow(File).to receive(:executable?).with("/usr/bin/pdftk").and_return(true)
      end

      it "returns true" do
        # We need to reset after stubbing to ensure fresh check
        described_class.reset!
        allow(described_class).to receive(:path).and_return("/usr/bin/pdftk")

        # Stub the system check
        allow(described_class).to receive(:system).and_return(true)

        expect(described_class.available?).to be true
      end
    end
  end

  describe ".reset!" do
    it "clears the cached path" do
      # Access path to cache it
      first_path = described_class.path

      # Reset
      described_class.reset!

      # Should re-resolve (result may be same, but cache is cleared)
      expect(described_class.instance_variable_get(:@path)).to be_nil
    end

    it "clears the cached availability" do
      # Access availability to cache it
      described_class.available?

      # Reset
      described_class.reset!

      expect(described_class.instance_variable_get(:@available)).to be_nil
    end
  end

  describe ".info" do
    it "returns a hash with expected keys" do
      info = described_class.info

      expect(info).to be_a(Hash)
      expect(info).to have_key(:available)
      expect(info).to have_key(:path)
      expect(info).to have_key(:version)
      expect(info).to have_key(:source)
    end

    it "includes boolean for available" do
      expect(described_class.info[:available]).to be_in([ true, false ])
    end

    it "includes string for path" do
      expect(described_class.info[:path]).to be_a(String)
    end
  end

  describe ".version" do
    context "when pdftk is not available" do
      before do
        allow(described_class).to receive(:available?).and_return(false)
      end

      it "returns nil" do
        expect(described_class.version).to be_nil
      end
    end
  end

  describe "SEARCH_PATHS" do
    it "includes common pdftk installation paths" do
      expect(described_class::SEARCH_PATHS).to include("/usr/bin/pdftk")
      expect(described_class::SEARCH_PATHS).to include("/usr/bin/pdftk-java")
    end

    it "is frozen" do
      expect(described_class::SEARCH_PATHS).to be_frozen
    end
  end

  describe "instance methods" do
    subject(:resolver) { described_class.new }

    it "delegates path to class method" do
      expect(resolver.path).to eq(described_class.path)
    end

    it "delegates available? to class method" do
      expect(resolver.available?).to eq(described_class.available?)
    end

    it "delegates info to class method" do
      expect(resolver.info).to eq(described_class.info)
    end
  end
end
