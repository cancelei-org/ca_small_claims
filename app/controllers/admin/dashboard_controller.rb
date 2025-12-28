# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    def index
      @stats = calculate_stats
      @forms_needing_attention = forms_needing_attention
      @recent_feedbacks = FormFeedback.recent.includes(:form_definition, :user).limit(10)
      @pending_count = FormFeedback.pending.count
    end

    private

    def calculate_stats
      {
        total_feedbacks: FormFeedback.count,
        pending_feedbacks: FormFeedback.pending.count,
        acknowledged_feedbacks: FormFeedback.acknowledged.count,
        resolved_today: FormFeedback.resolved.where("resolved_at >= ?", Time.current.beginning_of_day).count,
        low_rated_unresolved: FormFeedback.low_rated.unresolved.count,
        average_rating: FormFeedback.average(:rating)&.round(1) || 0
      }
    end

    def forms_needing_attention
      FormDefinition
        .joins(:form_feedbacks)
        .where(form_feedbacks: { status: %w[pending acknowledged] })
        .select("form_definitions.*, COUNT(form_feedbacks.id) as feedback_count")
        .group("form_definitions.id")
        .order("feedback_count DESC")
        .limit(10)
    end
  end
end
