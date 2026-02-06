# frozen_string_literal: true

ActiveSupport::Notifications.subscribe("cache_read.active_support") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  if event.payload[:hit]
    Cache::Metrics.increment_hit
  else
    Cache::Metrics.increment_miss
  end
end
