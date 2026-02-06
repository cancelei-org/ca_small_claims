# frozen_string_literal: true

module Cache
  class Metrics
    class << self
      attr_accessor :hits, :misses

      def increment_hit
        self.hits = (hits || 0) + 1
      end

      def increment_miss
        self.misses = (misses || 0) + 1
      end

      def ratio
        total = (hits || 0) + (misses || 0)
        return 0 if total.zero?

        (hits.to_f / total * 100).round(2)
      end
    end
  end
end
