# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    def index
      @stats = calculate_stats
      @forms_needing_attention = forms_needing_attention
      @recent_feedbacks = FormFeedback.recent.includes(:form_definition, :user).limit(10)
      @pending_count = FormFeedback.pending.count

      # Active users tracking
      @active_users_service = Analytics::ActiveUsersService.new
      @active_users_count = @active_users_service.active_count
      @active_users_breakdown = @active_users_service.user_type_breakdown
      @recent_activity = @active_users_service.recent_activity_feed(limit: 10)
      @activity_by_form = @active_users_service.activity_by_form.first(5)
    end

    private

    def calculate_stats
      # Combine multiple COUNT queries into a single aggregated query
      # This reduces 6 database round-trips to 1
      stats = FormFeedback.select(
        "COUNT(*) as total_feedbacks",
        "COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_feedbacks",
        "COUNT(CASE WHEN status = 'acknowledged' THEN 1 END) as acknowledged_feedbacks",
        "COUNT(CASE WHEN status = 'resolved' AND resolved_at >= '#{Time.current.beginning_of_day.to_fs(:db)}' THEN 1 END) as resolved_today",
        "COUNT(CASE WHEN rating <= 2 AND status NOT IN ('resolved', 'closed') THEN 1 END) as low_rated_unresolved",
        "AVG(rating) as average_rating"
      ).take

      {
        total_feedbacks: stats.total_feedbacks.to_i,
        pending_feedbacks: stats.pending_feedbacks.to_i,
        acknowledged_feedbacks: stats.acknowledged_feedbacks.to_i,
        resolved_today: stats.resolved_today.to_i,
        low_rated_unresolved: stats.low_rated_unresolved.to_i,
        average_rating: stats.average_rating&.round(1) || 0
      }
    end

    def forms_needing_attention
      FormDefinition
        .joins(:form_feedbacks)
        .where(form_feedbacks: { status: %w[pending acknowledged] })
        .select("form_definitions.id, form_definitions.code, form_definitions.title, COUNT(form_feedbacks.id) as feedback_count")
        .group("form_definitions.id, form_definitions.code, form_definitions.title")
        .order("feedback_count DESC")
        .limit(10)
    end
  end
end
