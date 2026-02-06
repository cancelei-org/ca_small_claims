# frozen_string_literal: true

module Admin
  class FeedbacksController < BaseController
    include Pagy::Backend
    include ActionView::RecordIdentifier

    before_action :set_feedback, only: [
      :show, :update, :start_progress, :acknowledge, :resolve, :close, :reopen,
      :escalate, :de_escalate, :set_priority
    ]

    def index
      @pagy, @feedbacks = pagy(filtered_feedbacks.includes(:form_definition, :user).recent, limit: 20)
      counts = FormFeedback.status_counts
      @open_count = counts[:open]
      @in_progress_count = counts[:in_progress]
      @urgent_count = counts[:urgent_active]
      @forms = FormDefinition.joins(:form_feedbacks).select(:id, :code).distinct.order(:code)

      # For backward compatibility
      @pending_count = @open_count
    end

    def show
      counts = FormFeedback.status_counts
      @open_count = counts[:open]
      @pending_count = @open_count
    end

    def update
      if @feedback.update(feedback_params)
        log_audit_event("update_feedback", target: @feedback, details: feedback_params.to_h)

        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              dom_id(@feedback),
              partial: "admin/feedbacks/feedback_row",
              locals: { feedback: @feedback }
            )
          end
          format.html { redirect_to admin_feedbacks_path, notice: "Feedback updated." }
        end
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              dom_id(@feedback),
              partial: "admin/feedbacks/feedback_row",
              locals: { feedback: @feedback }
            ), status: :unprocessable_entity
          end
          format.html { render :show, status: :unprocessable_entity }
        end
      end
    end

    def start_progress
      @feedback.start_progress!(current_user)
      log_audit_event("start_progress_feedback", target: @feedback)

      respond_to do |format|
        format.turbo_stream { render_feedback_update_stream }
        format.html { redirect_to admin_feedbacks_path, notice: "Feedback marked as in progress." }
      end
    end

    # Legacy action alias
    alias_method :acknowledge, :start_progress

    def resolve
      notes = sanitize_admin_notes(params[:admin_notes])
      @feedback.resolve!(current_user, notes: notes)
      log_audit_event("resolve_feedback", target: @feedback, details: { admin_notes: notes })

      respond_to do |format|
        format.turbo_stream { render_feedback_update_stream }
        format.html { redirect_to admin_feedbacks_path, notice: "Feedback resolved." }
      end
    end

    def close
      notes = sanitize_admin_notes(params[:admin_notes])
      @feedback.close!(current_user, notes: notes)
      log_audit_event("close_feedback", target: @feedback, details: { admin_notes: notes })

      respond_to do |format|
        format.turbo_stream { render_feedback_update_stream }
        format.html { redirect_to admin_feedbacks_path, notice: "Feedback closed." }
      end
    end

    def reopen
      @feedback.reopen!
      log_audit_event("reopen_feedback", target: @feedback)

      respond_to do |format|
        format.turbo_stream { render_feedback_update_stream }
        format.html { redirect_to admin_feedbacks_path, notice: "Feedback reopened." }
      end
    end

    def escalate
      old_priority = @feedback.priority
      @feedback.escalate!
      log_audit_event("escalate_feedback", target: @feedback, details: {
        from_priority: old_priority,
        to_priority: @feedback.priority
      })

      respond_to do |format|
        format.turbo_stream { render_feedback_update_stream }
        format.html { redirect_to admin_feedbacks_path, notice: "Feedback priority escalated to #{@feedback.priority}." }
      end
    end

    def de_escalate
      old_priority = @feedback.priority
      @feedback.de_escalate!
      log_audit_event("de_escalate_feedback", target: @feedback, details: {
        from_priority: old_priority,
        to_priority: @feedback.priority
      })

      respond_to do |format|
        format.turbo_stream { render_feedback_update_stream }
        format.html { redirect_to admin_feedbacks_path, notice: "Feedback priority reduced to #{@feedback.priority}." }
      end
    end

    def set_priority
      old_priority = @feedback.priority
      new_priority = params[:priority]

      if FormFeedback::PRIORITIES.include?(new_priority) && @feedback.set_priority!(new_priority)
        log_audit_event("set_priority_feedback", target: @feedback, details: {
          from_priority: old_priority,
          to_priority: new_priority
        })

        respond_to do |format|
          format.turbo_stream { render_feedback_update_stream }
          format.html { redirect_to admin_feedbacks_path, notice: "Feedback priority set to #{new_priority}." }
        end
      else
        respond_to do |format|
          format.turbo_stream { render_feedback_update_stream }
          format.html { redirect_to admin_feedbacks_path, alert: "Invalid priority." }
        end
      end
    end

    def bulk_start_progress
      ids = validate_bulk_ids(params[:ids])
      count = 0

      FormFeedback.open.where(id: ids).find_each do |feedback|
        feedback.start_progress!(current_user)
        count += 1
      end

      respond_to do |format|
        format.html { redirect_to admin_feedbacks_path, notice: "#{count} feedback(s) marked as in progress." }
        format.json { render json: { success: true, updated_count: count } }
      end
    end

    # Legacy alias
    alias_method :bulk_acknowledge, :bulk_start_progress

    def bulk_resolve
      ids = validate_bulk_ids(params[:ids])
      notes = sanitize_admin_notes(params[:admin_notes])
      count = 0

      FormFeedback.active.where(id: ids).find_each do |feedback|
        feedback.resolve!(current_user, notes: notes)
        count += 1
      end

      respond_to do |format|
        format.html { redirect_to admin_feedbacks_path, notice: "#{count} feedback(s) resolved." }
        format.json { render json: { success: true, resolved_count: count } }
      end
    end

    def bulk_close
      ids = validate_bulk_ids(params[:ids])
      notes = sanitize_admin_notes(params[:admin_notes])
      count = 0

      FormFeedback.where(id: ids).where.not(status: "closed").find_each do |feedback|
        feedback.close!(current_user, notes: notes)
        count += 1
      end

      respond_to do |format|
        format.html { redirect_to admin_feedbacks_path, notice: "#{count} feedback(s) closed." }
        format.json { render json: { success: true, closed_count: count } }
      end
    end

    def bulk_set_priority
      ids = validate_bulk_ids(params[:ids])
      priority = params[:priority]
      count = 0

      if FormFeedback::PRIORITIES.include?(priority)
        FormFeedback.where(id: ids).find_each do |feedback|
          feedback.set_priority!(priority)
          count += 1
        end
      end

      respond_to do |format|
        format.html { redirect_to admin_feedbacks_path, notice: "#{count} feedback(s) priority set to #{priority}." }
        format.json { render json: { success: true, updated_count: count } }
      end
    end

    def bulk_delete
      ids = validate_bulk_ids(params[:ids])
      count = FormFeedback.where(id: ids).delete_all

      respond_to do |format|
        format.html { redirect_to admin_feedbacks_path, notice: "#{count} feedback(s) deleted." }
        format.json { render json: { success: true, deleted_count: count } }
      end
    end

    private

    def set_feedback
      @feedback = FormFeedback.find(params[:id])
    end

    def feedback_params
      params.require(:form_feedback).permit(:admin_notes, :status, :priority)
    end

    def filtered_feedbacks
      feedbacks = FormFeedback.all

      feedbacks = feedbacks.where(form_definition_id: params[:form_id]) if params[:form_id].present?
      feedbacks = feedbacks.where(status: params[:status]) if params[:status].present?
      feedbacks = feedbacks.where(priority: params[:priority]) if params[:priority].present?
      feedbacks = feedbacks.by_issue_type(params[:issue_type]) if params[:issue_type].present?
      feedbacks = feedbacks.where(rating: params[:rating]) if params[:rating].present?

      if (from_date = safe_parse_date(params[:date_from]))
        feedbacks = feedbacks.where("created_at >= ?", from_date.beginning_of_day)
      end

      if (to_date = safe_parse_date(params[:date_to]))
        feedbacks = feedbacks.where("created_at <= ?", to_date.end_of_day)
      end

      # Sort by priority if requested
      feedbacks = feedbacks.by_priority_order if params[:sort] == "priority"

      feedbacks
    end

    def render_feedback_update_stream
      counts = FormFeedback.status_counts

      render turbo_stream: [
        turbo_stream.replace(dom_id(@feedback), partial: "admin/feedbacks/feedback_row", locals: { feedback: @feedback }),
        turbo_stream.update("open-count", counts[:open]),
        turbo_stream.update("in-progress-count", counts[:in_progress]),
        turbo_stream.update("urgent-count", counts[:urgent_active]),
        # Legacy support
        turbo_stream.update("pending-count", counts[:open])
      ]
    end
  end
end
