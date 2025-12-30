# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pdf::TemplateCopier do
  let(:source_dir) { Rails.root.join("tmp/test_source_pdfs") }
  let(:target_dir) { Rails.root.join("tmp/test_target_pdfs") }

  subject(:copier) { described_class.new(source_dir: source_dir, target_dir: target_dir) }

  before do
    FileUtils.mkdir_p(source_dir)
    FileUtils.mkdir_p(target_dir)
  end

  after do
    FileUtils.rm_rf(source_dir)
    FileUtils.rm_rf(target_dir)
  end

  describe "#copy_all!" do
    before do
      # Create test PDF files
      File.write(source_dir.join("sc100.pdf"), "PDF content 1")
      File.write(source_dir.join("sc101.pdf"), "PDF content 2")
      File.write(source_dir.join("fl100.pdf"), "PDF content 3")
    end

    it "copies all PDF files from source to target" do
      copier.copy_all!

      expect(File.exist?(target_dir.join("sc100.pdf"))).to be true
      expect(File.exist?(target_dir.join("sc101.pdf"))).to be true
      expect(File.exist?(target_dir.join("fl100.pdf"))).to be true
    end

    it "returns stats with copied count" do
      stats = copier.copy_all!

      expect(stats[:copied]).to eq(3)
      expect(stats[:skipped]).to eq(0)
      expect(stats[:errors]).to eq(0)
    end

    context "when target files already exist" do
      before do
        File.write(target_dir.join("sc100.pdf"), "Old content")
        # Make target file older
        FileUtils.touch(target_dir.join("sc100.pdf"), mtime: Time.now - 3600)
      end

      it "overwrites older target files" do
        copier.copy_all!

        expect(File.read(target_dir.join("sc100.pdf"))).to eq("PDF content 1")
      end

      it "skips target files that are newer or same age" do
        # Make target file newer
        FileUtils.touch(target_dir.join("sc100.pdf"), mtime: Time.now + 3600)

        stats = copier.copy_all!

        expect(stats[:skipped]).to eq(1)
        expect(stats[:copied]).to eq(2)
      end
    end

    context "when given specific filenames" do
      it "only copies specified files" do
        copier.copy_all!([ "sc100.pdf", "fl100.pdf" ])

        expect(File.exist?(target_dir.join("sc100.pdf"))).to be true
        expect(File.exist?(target_dir.join("fl100.pdf"))).to be true
        expect(File.exist?(target_dir.join("sc101.pdf"))).to be false
      end
    end

    context "when source file does not exist" do
      it "records an error" do
        copier.copy_all!([ "nonexistent.pdf" ])

        expect(copier.stats[:errors]).to eq(1)
        expect(copier.errors.first[:filename]).to eq("nonexistent.pdf")
      end
    end
  end

  describe "#copy_for_category!" do
    before do
      File.write(source_dir.join("sc100.pdf"), "SC content 1")
      File.write(source_dir.join("sc101.pdf"), "SC content 2")
      File.write(source_dir.join("fl100.pdf"), "FL content")
    end

    it "copies only files matching the category prefix" do
      copier.copy_for_category!("sc")

      expect(File.exist?(target_dir.join("sc100.pdf"))).to be true
      expect(File.exist?(target_dir.join("sc101.pdf"))).to be true
      expect(File.exist?(target_dir.join("fl100.pdf"))).to be false
    end
  end

  describe "#copy_single" do
    before do
      File.write(source_dir.join("sc100.pdf"), "PDF content")
    end

    it "copies a single file" do
      result = copier.copy_single("sc100.pdf")

      expect(result).to be true
      expect(File.exist?(target_dir.join("sc100.pdf"))).to be true
    end

    it "returns false for non-existent files" do
      result = copier.copy_single("nonexistent.pdf")

      expect(result).to be false
    end
  end

  describe "#file_exists?" do
    before do
      File.write(target_dir.join("existing.pdf"), "content")
    end

    it "returns true if file exists in target" do
      expect(copier.file_exists?("existing.pdf")).to be true
    end

    it "returns false if file does not exist in target" do
      expect(copier.file_exists?("nonexistent.pdf")).to be false
    end
  end

  describe "target directory creation" do
    let(:nested_target) { Rails.root.join("tmp/nested/deep/target") }

    after { FileUtils.rm_rf(Rails.root.join("tmp/nested")) }

    it "creates target directory if it does not exist" do
      copier = described_class.new(source_dir: source_dir, target_dir: nested_target)
      File.write(source_dir.join("test.pdf"), "content")

      copier.copy_all!

      expect(File.directory?(nested_target)).to be true
    end
  end
end
