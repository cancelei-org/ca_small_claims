# frozen_string_literal: true

module Storage
  class Usage
    extend ActiveSupport::NumberHelper

    TARGETS = {
      rails_storage: Rails.root.join("storage"),
      pdf_templates: Rails.root.join("lib", "pdf_templates"),
      tmp: Rails.root.join("tmp")
    }.freeze

    def self.summary
      TARGETS.transform_values { |path| size_for(path) }
    end

    def self.size_for(path)
      return { bytes: 0, human: "0 B" } unless File.directory?(path)

      bytes = Dir.glob(File.join(path, "**", "*")).sum { |f| File.file?(f) ? File.size(f) : 0 }
      { bytes: bytes, human: number_to_human_size(bytes) }
    end
  end
end
