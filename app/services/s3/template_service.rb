# frozen_string_literal: true

module S3
  class TemplateService
    class DownloadError < StandardError; end
    class UploadError < StandardError; end

    attr_reader :s3_client, :bucket, :prefix, :cache_dir

    def initialize
      config = Rails.application.config.s3_config

      @s3_client = Aws::S3::Client.new(
        endpoint: config[:endpoint],
        region: config[:region],
        access_key_id: config[:access_key_id],
        secret_access_key: config[:secret_access_key],
        force_path_style: config[:force_path_style]
      )

      @bucket = config[:bucket]
      @prefix = config[:prefix]
      @cache_dir = Rails.root.join("tmp", "cached_templates")

      ensure_cache_directory
    end

    # Download template to local cache and return path
    # Uses TTL-based caching (24 hours)
    def download_template(pdf_filename)
      cache_path = cached_template_path(pdf_filename)

      # Return cached if exists and fresh
      if cache_fresh?(cache_path)
        Rails.logger.debug "S3: Using cached template #{pdf_filename}"
        return cache_path
      end

      # Download from S3
      Rails.logger.info "S3: Downloading template #{pdf_filename}"
      s3_key = template_key(pdf_filename)

      begin
        s3_client.get_object(
          bucket: bucket,
          key: s3_key,
          response_target: cache_path.to_s
        )

        cache_path
      rescue Aws::S3::Errors::NoSuchKey
        raise DownloadError, "Template not found in S3: #{pdf_filename}"
      rescue Aws::S3::Errors::ServiceError => e
        raise DownloadError, "S3 download failed: #{e.message}"
      end
    end

    # Upload a single template to S3
    def upload_template(local_path, pdf_filename)
      s3_key = template_key(pdf_filename)

      begin
        File.open(local_path, "rb") do |file|
          s3_client.put_object(
            bucket: bucket,
            key: s3_key,
            body: file,
            content_type: "application/pdf",
            metadata: {
              uploaded_at: Time.current.iso8601,
              source: "rails_upload"
            }
          )
        end

        Rails.logger.info "S3: Uploaded #{pdf_filename}"
        true
      rescue Aws::S3::Errors::ServiceError => e
        raise UploadError, "S3 upload failed for #{pdf_filename}: #{e.message}"
      end
    end

    # Upload all templates from lib/pdf_templates/
    # Returns { success: count, failed: [errors], skipped: count }
    def bulk_upload_templates(source_dir = Rails.root.join("lib", "pdf_templates"))
      results = { success: 0, failed: [], skipped: 0 }

      Dir.glob(source_dir.join("*.pdf")).each do |file_path|
        pdf_filename = File.basename(file_path)

        # Skip symlinks - follow them first
        if File.symlink?(file_path)
          real_path = File.realpath(file_path)
          unless File.exist?(real_path)
            results[:failed] << { file: pdf_filename, error: "Broken symlink" }
            next
          end
          file_path = real_path
        end

        begin
          upload_template(file_path, pdf_filename)
          results[:success] += 1
        rescue UploadError => e
          results[:failed] << { file: pdf_filename, error: e.message }
        end
      end

      results
    end

    # Check if template exists in S3
    def template_exists?(pdf_filename)
      s3_client.head_object(bucket: bucket, key: template_key(pdf_filename))
      true
    rescue Aws::S3::Errors::NotFound
      false
    end

    # Clear local cache (useful for deployments)
    def clear_cache
      FileUtils.rm_rf(cache_dir)
      ensure_cache_directory
      Rails.logger.info "S3: Cleared template cache"
    end

    # Get S3 URL for a template (for debugging/verification)
    def template_url(pdf_filename)
      endpoint = Rails.application.config.s3_config[:endpoint]
      return nil unless endpoint

      host = endpoint.gsub(%r{^https?://}, "")
      "https://#{bucket}.#{host}/#{template_key(pdf_filename)}"
    end

    private

    def template_key(pdf_filename)
      "#{prefix}/#{pdf_filename}"
    end

    def cached_template_path(pdf_filename)
      cache_dir.join(pdf_filename)
    end

    def cache_fresh?(path, ttl = 24.hours)
      return false unless File.exist?(path)

      File.mtime(path) > ttl.ago
    end

    def ensure_cache_directory
      FileUtils.mkdir_p(cache_dir) unless Dir.exist?(cache_dir)
    end
  end
end
