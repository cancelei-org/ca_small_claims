# frozen_string_literal: true

module Admin
  class ProductFeedbacksController < BaseController
    include Pagy::Backend
    include ActionView::RecordIdentifier

    before_action :set_product_feedback, only: %i[show update update_status update_admin_notes]

    def index
      @pagy, @product_feedbacks = pagy(
        filtered_feedbacks.includes(:user).recent,
        limit: 20
      )

      @counts = {
        total: ProductFeedback.count,
        pending: ProductFeedback.pending.count,
        under_review: ProductFeedback.under_review.count,
        planned: ProductFeedback.planned.count,
        in_progress: ProductFeedback.in_progress.count,
        completed: ProductFeedback.completed.count,
        declined: ProductFeedback.declined.count
      }

      @category_counts = ProductFeedback.group(:category).count
    end

    def show; end

    def update
      if @product_feedback.update(product_feedback_params)
        log_audit_event("update_product_feedback", target: @product_feedback, details: product_feedback_params.to_h)
        notify_user_of_status_change if params[:product_feedback][:status].present?

        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              dom_id(@product_feedback),
              partial: "admin/product_feedbacks/feedback_row",
              locals: { product_feedback: @product_feedback }
            )
          end
          format.html { redirect_to admin_product_feedbacks_path, notice: "Feedback updated." }
        end
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              dom_id(@product_feedback),
              partial: "admin/product_feedbacks/feedback_row",
              locals: { product_feedback: @product_feedback }
            ), status: :unprocessable_entity
          end
          format.html { render :show, status: :unprocessable_entity }
        end
      end
    end

    def update_status
      old_status = @product_feedback.status
      new_status = params[:status]

      if ProductFeedback.statuses.key?(new_status) && @product_feedback.update(status: new_status)
        log_audit_event("update_product_feedback_status", target: @product_feedback, details: {
          from_status: old_status,
          to_status: new_status
        })

        ProductFeedbackMailer.status_changed(@product_feedback, old_status).deliver_later

        respond_to do |format|
          format.turbo_stream { render_feedback_update_stream }
          format.html { redirect_to admin_product_feedbacks_path, notice: "Status updated to #{@product_feedback.status_display_name}." }
        end
      else
        respond_to do |format|
          format.turbo_stream { render_feedback_update_stream }
          format.html { redirect_to admin_product_feedbacks_path, alert: "Invalid status." }
        end
      end
    end

    def update_admin_notes
      notes = sanitize_admin_notes(params[:admin_notes])

      if @product_feedback.update(admin_notes: notes)
        log_audit_event("update_product_feedback_notes", target: @product_feedback)

        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "admin-notes-#{@product_feedback.id}",
              partial: "admin/product_feedbacks/admin_notes",
              locals: { product_feedback: @product_feedback }
            )
          end
          format.html { redirect_to admin_product_feedback_path(@product_feedback), notice: "Notes updated." }
        end
      else
        respond_to do |format|
          format.turbo_stream { head :unprocessable_entity }
          format.html { redirect_to admin_product_feedback_path(@product_feedback), alert: "Could not update notes." }
        end
      end
    end

    def export
      @product_feedbacks = filtered_feedbacks.includes(:user)

      respond_to do |format|
        format.csv do
          send_data generate_csv, filename: "product_feedbacks_#{Date.current}.csv", type: "text/csv"
        end
      end
    end

    private

    def set_product_feedback
      @product_feedback = ProductFeedback.find(params[:id])
    end

    def product_feedback_params
      params.require(:product_feedback).permit(:status, :admin_notes)
    end

    def filtered_feedbacks
      feedbacks = ProductFeedback.all

      feedbacks = feedbacks.by_category(params[:category]) if params[:category].present?
      feedbacks = feedbacks.by_status(params[:status]) if params[:status].present?
      feedbacks = feedbacks.where(user_id: params[:user_id]) if params[:user_id].present?

      if (from_date = safe_parse_date(params[:date_from]))
        feedbacks = feedbacks.where("created_at >= ?", from_date.beginning_of_day)
      end

      if (to_date = safe_parse_date(params[:date_to]))
        feedbacks = feedbacks.where("created_at <= ?", to_date.end_of_day)
      end

      feedbacks = feedbacks.popular if params[:sort] == "votes"

      feedbacks
    end

    def render_feedback_update_stream
      render turbo_stream: [
        turbo_stream.replace(dom_id(@product_feedback), partial: "admin/product_feedbacks/feedback_row", locals: { product_feedback: @product_feedback }),
        turbo_stream.update("pending-count", ProductFeedback.pending.count),
        turbo_stream.update("under-review-count", ProductFeedback.under_review.count),
        turbo_stream.update("planned-count", ProductFeedback.planned.count),
        turbo_stream.update("in-progress-count", ProductFeedback.in_progress.count)
      ]
    end

    def notify_user_of_status_change
      ProductFeedbackMailer.status_changed(@product_feedback, @product_feedback.status_before_last_save).deliver_later
    end

    def generate_csv
      require "csv"

      CSV.generate(headers: true) do |csv|
        csv << %w[ID Category Status Title Description User Email Votes Created Updated]

        @product_feedbacks.find_each do |feedback|
          csv << [
            feedback.id,
            feedback.category_display_name,
            feedback.status_display_name,
            feedback.title,
            feedback.description.truncate(500),
            feedback.user.display_name,
            feedback.user.email,
            feedback.votes_count,
            feedback.created_at.iso8601,
            feedback.updated_at.iso8601
          ]
        end
      end
    end
  end
end
