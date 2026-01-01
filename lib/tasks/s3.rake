# frozen_string_literal: true

namespace :s3 do
  desc "Upload all PDF templates to S3"
  task upload_templates: :environment do
    puts "Starting bulk upload to S3..."
    puts "Bucket: #{Rails.application.config.s3_config[:bucket]}"
    puts "Prefix: #{Rails.application.config.s3_config[:prefix]}"
    puts

    service = S3::TemplateService.new
    source_dir = Rails.root.join("lib", "pdf_templates")

    # Count files first
    total_files = Dir.glob(source_dir.join("*.pdf")).count
    puts "Found #{total_files} PDF templates to upload"
    puts

    # Progress tracking
    uploaded = 0
    start_time = Time.current

    Dir.glob(source_dir.join("*.pdf")).each_with_index do |file_path, index|
      pdf_filename = File.basename(file_path)

      # Resolve symlinks
      file_path = File.realpath(file_path) if File.symlink?(file_path)

      begin
        service.upload_template(file_path, pdf_filename)
        uploaded += 1

        if (index + 1) % 50 == 0 || (index + 1) == total_files
          elapsed = Time.current - start_time
          rate = uploaded / elapsed.to_f
          remaining = (total_files - uploaded) / rate

          puts "[#{uploaded}/#{total_files}] Uploaded #{pdf_filename} (#{rate.round(1)} files/sec, ~#{remaining.round(0)}s remaining)"
        end
      rescue S3::TemplateService::UploadError => e
        puts "FAILED: #{pdf_filename} - #{e.message}"
      end
    end

    elapsed = Time.current - start_time
    puts
    puts "Upload complete!"
    puts "  Success: #{uploaded}/#{total_files}"
    puts "  Failed: #{total_files - uploaded}"
    puts "  Duration: #{elapsed.round(1)}s"
    puts "  Rate: #{(uploaded / elapsed).round(1)} files/sec"
  end

  desc "Verify all templates exist in S3"
  task verify_templates: :environment do
    puts "Verifying templates in S3..."
    puts

    service = S3::TemplateService.new
    missing = []
    found = 0

    FormDefinition.find_each do |form|
      if service.template_exists?(form.pdf_filename)
        found += 1
      else
        missing << { code: form.code, file: form.pdf_filename }
      end
    end

    puts "Verification complete:"
    puts "  Found: #{found}"
    puts "  Missing: #{missing.count}"

    if missing.any?
      puts
      puts "Missing templates:"
      missing.each { |m| puts "  - #{m[:code]}: #{m[:file]}" }
      exit 1
    else
      puts
      puts "All templates verified successfully!"
    end
  end

  desc "Clear local template cache"
  task clear_cache: :environment do
    puts "Clearing local template cache..."
    S3::TemplateService.new.clear_cache
    puts "Cache cleared."
  end

  desc "Download a single template for testing"
  task :download_template, [ :pdf_filename ] => :environment do |_t, args|
    pdf_filename = args[:pdf_filename] || "sc100.pdf"

    puts "Downloading #{pdf_filename}..."
    service = S3::TemplateService.new

    begin
      path = service.download_template(pdf_filename)

      puts "Downloaded to: #{path}"
      puts "File size: #{File.size(path)} bytes"
      puts "File exists: #{File.exist?(path)}"
    rescue S3::TemplateService::DownloadError => e
      puts "ERROR: #{e.message}"
      exit 1
    end
  end

  desc "Show S3 configuration"
  task show_config: :environment do
    config = Rails.application.config.s3_config

    puts "S3 Configuration:"
    puts "  Endpoint: #{config[:endpoint]}"
    puts "  Region: #{config[:region]}"
    puts "  Bucket: #{config[:bucket]}"
    puts "  Prefix: #{config[:prefix]}"
    puts "  Access Key: #{config[:access_key_id]&.first(10)}..." if config[:access_key_id]
    puts "  USE_S3_STORAGE: #{ENV.fetch('USE_S3_STORAGE', 'false')}"
  end
end
