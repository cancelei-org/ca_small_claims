# frozen_string_literal: true

module Admin
  class FeedbacksController < BaseController
    include Pagy::Backend

    before_action :set_feedback, only: [ :show, :update, :acknowledge, :resolve ]

    def index
      @pagy, @feedbacks = pagy(filtered_feedbacks.includes(:form_definition, :user).recent, limit: 20)
      @pending_count = FormFeedback.pending.count
      @forms = FormDefinition.joins(:form_feedbacks).distinct.order(:code)
    end

    def show
      @pending_count = FormFeedback.pending.count
    end

    def update
      if @feedback.update(feedback_params)
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

    def acknowledge
      @feedback.acknowledge!

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(dom_id(@feedback), partial: "admin/feedbacks/feedback_row", locals: { feedback: @feedback }),
            turbo_stream.update("pending-count", FormFeedback.pending.count)
          ]
        end
        format.html { redirect_to admin_feedbacks_path, notice: "Feedback acknowledged." }
      end
    end

    def resolve
      @feedback.resolve!(current_user, notes: params[:admin_notes])

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(dom_id(@feedback), partial: "admin/feedbacks/feedback_row", locals: { feedback: @feedback }),
            turbo_stream.update("pending-count", FormFeedback.pending.count)
          ]
        end
        format.html { redirect_to admin_feedbacks_path, notice: "Feedback resolved." }
      end
    end

    private

    def set_feedback
      @feedback = FormFeedback.find(params[:id])
    end

    def feedback_params
      params.require(:form_feedback).permit(:admin_notes, :status)
    end

    def filtered_feedbacks
      feedbacks = FormFeedback.all

      feedbacks = feedbacks.where(form_definition_id: params[:form_id]) if params[:form_id].present?
      feedbacks = feedbacks.where(status: params[:status]) if params[:status].present?
      feedbacks = feedbacks.by_issue_type(params[:issue_type]) if params[:issue_type].present?
      feedbacks = feedbacks.where(rating: params[:rating]) if params[:rating].present?

      if params[:date_from].present?
        feedbacks = feedbacks.where("created_at >= ?", Date.parse(params[:date_from]).beginning_of_day)
      end

      if params[:date_to].present?
        feedbacks = feedbacks.where("created_at <= ?", Date.parse(params[:date_to]).end_of_day)
      end

      feedbacks
    end
  end
end
