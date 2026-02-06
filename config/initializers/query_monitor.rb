# frozen_string_literal: true

THRESHOLD_MS = (ENV["SLOW_QUERY_THRESHOLD_MS"] || 200).to_i
ALERT_THRESHOLD_MS = (ENV["SLOW_QUERY_ALERT_THRESHOLD_MS"] || THRESHOLD_MS * 2).to_i

ActiveSupport::Notifications.subscribe("sql.active_record") do |_, start, finish, _, payload|
  duration_ms = (finish - start) * 1000
  next if duration_ms < THRESHOLD_MS
  next if payload[:cached]

  data = {
    message: "slow_query",
    duration_ms: duration_ms.round(1),
    sql: payload[:sql]&.truncate(500),
    name: payload[:name]
  }

  ActiveSupport::Notifications.instrument("sql.slow", data)
  Rails.logger.warn(data)

  if duration_ms >= ALERT_THRESHOLD_MS && defined?(Sentry)
    Sentry.capture_message(
      "Slow query (#{duration_ms.round(1)}ms)",
      level: "warning",
      extra: data
    )
  end
end
