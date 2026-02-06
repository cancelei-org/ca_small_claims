# frozen_string_literal: true

module Cache
  # Caches frequently-read form metadata to reduce database load.
  class FormMetadataCache
    DEFAULT_TTL = 5.minutes
    KEY = "forms:metadata"

    def self.fetch(ttl: DEFAULT_TTL)
      Rails.cache.fetch(KEY, expires_in: ttl) do
        FormDefinition.active
          .includes(:category)
          .ordered
          .pluck(:code, :title, :category_id)
      end
    end

    def self.invalidate!
      Rails.cache.delete(KEY)
    end
  end
end
