# frozen_string_literal: true

ActiveSupport::Notifications.subscribe("pdf.generate") do |_, start, finish, _, payload|
  duration_ms = ((finish - start) * 1000).round(1)
  data = {
    message: "pdf_generate",
    submission_id: payload[:submission_id],
    duration_ms: duration_ms
  }

  Rails.logger.info(data)
  ActiveSupport::Notifications.instrument("pdf.generate.metrics", data)
end
