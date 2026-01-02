# frozen_string_literal: true

# S3 Configuration for IDRIVE PDF Template Storage
Rails.application.config.s3_config = {
  endpoint: ENV["IDRIVE_ENDPOINT"],
  region: ENV.fetch("IDRIVE_REGION_CODE", "us-west-2"),
  access_key_id: ENV["IDRIVE_ACCESS_KEY_ID"],
  secret_access_key: ENV["IDRIVE_SECRET_ASSET_KEY"],
  bucket: ENV.fetch("S3_BUCKET_NAME", "ca-small-claims-pdfs"),
  force_path_style: true, # Required for IDRIVE S3 compatibility
  prefix: "#{Rails.env}/templates"
}

# Validate S3 credentials on boot in production
Rails.logger.warn "S3 credentials not configured - PDF generation will fail if USE_S3_STORAGE=true" if Rails.env.production? && Rails.application.config.s3_config[:access_key_id].blank?
