# frozen_string_literal: true

class MetricsController < ApplicationController
  before_action :authenticate_admin!

  def show
    render json: {
      cache: {
        hits: Cache::Metrics.hits || 0,
        misses: Cache::Metrics.misses || 0,
        hit_ratio: Cache::Metrics.ratio
      },
      storage: Storage::Usage.summary
    }
  end
end
