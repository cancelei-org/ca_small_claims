# frozen_string_literal: true

module Admin
  class SessionSubmissionsController < BaseController
    include Pagy::Backend

    before_action :set_session_submission, only: %i[show recover destroy]

    def index
      @pagy, @session_submissions = pagy(filtered_submissions.includes(:form_definition).order(expires_at: :desc), limit: 20)
      @total_active = SessionSubmission.active.count
      @total_expired = SessionSubmission.expired.count
      @total_count = SessionSubmission.count
    end

    def show
      # View session submission details
    end

    def recover
      if @session_submission.expired?
        @session_submission.extend_expiration!
        respond_to do |format|
          format.html { redirect_to admin_session_submissions_path, notice: "Session recovered. Expiration extended by 72 hours." }
          format.json { render json: { success: true, expires_at: @session_submission.expires_at } }
        end
      else
        respond_to do |format|
          format.html { redirect_to admin_session_submissions_path, alert: "Session is not expired." }
          format.json { render json: { success: false, error: "Session is not expired" }, status: :unprocessable_entity }
        end
      end
    end

    def destroy
      @session_submission.destroy
      respond_to do |format|
        format.html { redirect_to admin_session_submissions_path, notice: "Session submission deleted." }
        format.json { render json: { success: true } }
      end
    end

    def cleanup_expired
      count = SessionSubmission.expired.count
      SessionSubmission.cleanup_expired!
      respond_to do |format|
        format.html { redirect_to admin_session_submissions_path, notice: "#{count} expired sessions cleaned up." }
        format.json { render json: { success: true, deleted_count: count } }
      end
    end

    def bulk_recover
      ids = params[:ids] || []
      recovered_count = 0

      SessionSubmission.expired.where(id: ids).find_each do |session|
        session.extend_expiration!
        recovered_count += 1
      end

      respond_to do |format|
        format.html { redirect_to admin_session_submissions_path, notice: "#{recovered_count} sessions recovered." }
        format.json { render json: { success: true, recovered_count: recovered_count } }
      end
    end

    private

    def set_session_submission
      @session_submission = SessionSubmission.find(params[:id])
    end

    def filtered_submissions
      submissions = SessionSubmission.all
      submissions = submissions.where(session_id: params[:session_id]) if params[:session_id].present?
      submissions = filter_by_status(submissions)
      submissions = filter_by_form(submissions)
      filter_by_date(submissions)
    end

    def filter_by_status(submissions)
      case params[:status]
      when "active" then submissions.active
      when "expired" then submissions.expired
      else submissions
      end
    end

    def filter_by_form(submissions)
      return submissions unless params[:form_id].present?
      submissions.where(form_definition_id: params[:form_id])
    end

    def filter_by_date(submissions)
      if (from_date = safe_parse_date(params[:date_from]))
        submissions = submissions.where("session_submissions.created_at >= ?", from_date.beginning_of_day)
      end
      if (to_date = safe_parse_date(params[:date_to]))
        submissions = submissions.where("session_submissions.created_at <= ?", to_date.end_of_day)
      end
      submissions
    end
  end
end
