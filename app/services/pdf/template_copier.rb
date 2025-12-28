# frozen_string_literal: true

module Pdf
  class TemplateCopier
    attr_reader :source_dir, :target_dir, :stats

    DEFAULT_TARGET_DIR = "lib/pdf_templates"

    def initialize(source_dir:, target_dir: nil)
      @source_dir = Pathname.new(source_dir)
      @target_dir = target_dir ? Pathname.new(target_dir) : Rails.root.join(DEFAULT_TARGET_DIR)
      @stats = { copied: 0, skipped: 0, errors: 0 }
      @errors = []
    end

    def copy_all!(filenames = nil)
      ensure_target_directory!

      files_to_copy = filenames || all_pdf_filenames

      files_to_copy.each do |filename|
        copy_file(filename)
      end

      stats
    end

    def copy_for_category!(prefix)
      pattern = @source_dir.join("#{prefix.downcase}*.pdf")
      files = Dir.glob(pattern).map { |f| File.basename(f) }

      if files.empty?
        Rails.logger.warn "[TemplateCopier] No PDFs found for prefix: #{prefix}"
        return stats
      end

      copy_all!(files)
    end

    def copy_single(filename)
      ensure_target_directory!
      copy_file(filename)
    end

    def file_exists?(filename)
      target_path = @target_dir.join(filename)
      File.exist?(target_path)
    end

    def errors
      @errors.dup
    end

    private

    def all_pdf_filenames
      Dir.glob(@source_dir.join("*.pdf")).map { |f| File.basename(f) }
    end

    def ensure_target_directory!
      FileUtils.mkdir_p(@target_dir) unless File.directory?(@target_dir)
    end

    def copy_file(filename)
      source = @source_dir.join(filename)
      target = @target_dir.join(filename)

      unless File.exist?(source)
        @stats[:errors] += 1
        @errors << { filename: filename, error: "Source file not found" }
        return false
      end

      # Skip if target exists and is newer or same age
      if File.exist?(target) && File.mtime(target) >= File.mtime(source)
        @stats[:skipped] += 1
        return false
      end

      FileUtils.cp(source, target)
      @stats[:copied] += 1
      true
    rescue StandardError => e
      @stats[:errors] += 1
      @errors << { filename: filename, error: e.message }
      Rails.logger.error "[TemplateCopier] Failed to copy #{filename}: #{e.message}"
      false
    end
  end
end
