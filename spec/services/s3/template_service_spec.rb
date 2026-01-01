# frozen_string_literal: true

require "rails_helper"

RSpec.describe S3::TemplateService, type: :service do
  let(:service) { described_class.new }
  let(:s3_client_double) { instance_double(Aws::S3::Client) }
  let(:test_pdf_filename) { "sc100.pdf" }
  let(:cache_path) { Rails.root.join("tmp", "cached_templates", test_pdf_filename) }
  let(:configured_bucket) { Rails.application.config.s3_config[:bucket] }
  let(:configured_prefix) { Rails.application.config.s3_config[:prefix] }

  before do
    # Stub S3 client initialization
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client_double)

    # Clean up cache before each test
    FileUtils.rm_rf(Rails.root.join("tmp", "cached_templates"))
  end

  after do
    # Clean up cache after each test
    FileUtils.rm_rf(Rails.root.join("tmp", "cached_templates"))
  end

  describe "#download_template" do
    context "when template does not exist in cache" do
      it "downloads from S3 and caches locally" do
        expect(s3_client_double).to receive(:get_object).with(
          bucket: configured_bucket,
          key: "#{configured_prefix}/#{test_pdf_filename}",
          response_target: cache_path.to_s
        )

        result = service.download_template(test_pdf_filename)

        expect(result).to eq(cache_path)
      end
    end

    context "when template exists in cache and is fresh" do
      before do
        # Create a fresh cached file
        FileUtils.mkdir_p(cache_path.dirname)
        FileUtils.touch(cache_path)
      end

      it "returns cached path without downloading" do
        expect(s3_client_double).not_to receive(:get_object)

        result = service.download_template(test_pdf_filename)

        expect(result).to eq(cache_path)
      end
    end

    context "when template exists in cache but is stale" do
      before do
        # Create a stale cached file (older than 24 hours)
        FileUtils.mkdir_p(cache_path.dirname)
        FileUtils.touch(cache_path)
        stale_time = 25.hours.ago.to_time
        File.utime(stale_time, stale_time, cache_path)
      end

      it "downloads fresh version from S3" do
        expect(s3_client_double).to receive(:get_object)

        service.download_template(test_pdf_filename)
      end
    end

    context "when template not found in S3" do
      it "raises DownloadError" do
        allow(s3_client_double).to receive(:get_object).and_raise(
          Aws::S3::Errors::NoSuchKey.new(nil, "Not found")
        )

        expect {
          service.download_template(test_pdf_filename)
        }.to raise_error(S3::TemplateService::DownloadError, /not found in S3/)
      end
    end

    context "when S3 service error occurs" do
      it "raises DownloadError with message" do
        allow(s3_client_double).to receive(:get_object).and_raise(
          Aws::S3::Errors::ServiceError.new(nil, "Service unavailable")
        )

        expect {
          service.download_template(test_pdf_filename)
        }.to raise_error(S3::TemplateService::DownloadError, /S3 download failed/)
      end
    end
  end

  describe "#upload_template" do
    let(:local_path) { Rails.root.join("spec", "fixtures", "files", "test_template.pdf") }

    before do
      # Create a test PDF file
      FileUtils.mkdir_p(local_path.dirname)
      File.write(local_path, "%PDF-1.4 test content")
    end

    after do
      FileUtils.rm_f(local_path)
    end

    it "uploads template to S3 with correct metadata" do
      expect(s3_client_double).to receive(:put_object) do |args|
        expect(args[:bucket]).to eq(configured_bucket)
        expect(args[:key]).to eq("#{configured_prefix}/#{test_pdf_filename}")
        expect(args[:content_type]).to eq("application/pdf")
        expect(args[:metadata]).to include(:uploaded_at, :source)
      end

      result = service.upload_template(local_path, test_pdf_filename)

      expect(result).to be true
    end

    context "when S3 upload fails" do
      it "raises UploadError" do
        allow(s3_client_double).to receive(:put_object).and_raise(
          Aws::S3::Errors::ServiceError.new(nil, "Upload failed")
        )

        expect {
          service.upload_template(local_path, test_pdf_filename)
        }.to raise_error(S3::TemplateService::UploadError)
      end
    end
  end

  describe "#template_exists?" do
    context "when template exists" do
      it "returns true" do
        allow(s3_client_double).to receive(:head_object).and_return(true)

        expect(service.template_exists?(test_pdf_filename)).to be true
      end
    end

    context "when template does not exist" do
      it "returns false" do
        allow(s3_client_double).to receive(:head_object).and_raise(
          Aws::S3::Errors::NotFound.new(nil, "Not found")
        )

        expect(service.template_exists?(test_pdf_filename)).to be false
      end
    end
  end

  describe "#clear_cache" do
    before do
      # Create some cached files
      FileUtils.mkdir_p(cache_path.dirname)
      FileUtils.touch(cache_path)
    end

    it "removes all cached templates" do
      expect(File.exist?(cache_path)).to be true

      service.clear_cache

      expect(File.exist?(cache_path)).to be false
    end

    it "recreates the cache directory" do
      service.clear_cache

      expect(Dir.exist?(Rails.root.join("tmp", "cached_templates"))).to be true
    end
  end

  describe "#template_url" do
    context "when endpoint is configured" do
      before do
        allow(Rails.application.config).to receive(:s3_config).and_return(
          endpoint: "https://s3.example.com",
          bucket: configured_bucket,
          prefix: configured_prefix
        )
      end

      it "returns the correct S3 URL" do
        url = service.template_url(test_pdf_filename)

        expect(url).to include(configured_bucket)
        expect(url).to include("#{configured_prefix}/#{test_pdf_filename}")
      end
    end

    context "when endpoint is not configured" do
      it "returns nil" do
        url = service.template_url(test_pdf_filename)

        expect(url).to be_nil
      end
    end
  end
end
