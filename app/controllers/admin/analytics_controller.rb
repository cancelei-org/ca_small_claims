# frozen_string_literal: true

module Admin
  class AnalyticsController < BaseController
    def index
      # Submissions per day (last 14 days)
      @daily_submissions = Submission.where(created_at: 14.days.ago..Time.current)
                                     .group("DATE(created_at)")
                                     .count
                                     .transform_keys { |k| k.strftime("%b %d") }

      # Completion Rate
      total = Submission.count
      completed = Submission.completed.count
      @completion_rate = total > 0 ? (completed.to_f / total * 100).round(1) : 0

      # Popular Forms
      @popular_forms = Submission.group(:form_definition_id)
                                 .order("count_all DESC")
                                 .limit(5)
                                 .count
                                 .transform_keys { |id| FormDefinition.find(id).code }
    end
  end
end
