# frozen_string_literal: true

module Admin
  class SubmissionsController < BaseController
    include Pagy::Backend

    before_action :set_submission, only: %i[show update_notes]

    def index
      @pagy, @submissions = pagy(filtered_submissions.includes(:form_definition, :user).recent, limit: 20)
      @forms = FormDefinition.joins(:submissions).select(:id, :code).distinct.order(:code)
      @total_count = Submission.count
      @users_with_submissions = User.joins(:submissions).distinct.count
    end

    def show
      # Read-only view for form data - admin notes editable
    end

    def update_notes
      if @submission.update(admin_notes: params[:admin_notes])
        log_audit_event("update_submission_notes", target: @submission, details: { notes_length: params[:admin_notes]&.length })
        respond_to do |format|
          format.html { redirect_to admin_submission_path(@submission), notice: "Admin notes updated." }
          format.json { render json: { success: true, admin_notes: @submission.admin_notes } }
        end
      else
        respond_to do |format|
          format.html { redirect_to admin_submission_path(@submission), alert: "Failed to update notes." }
          format.json { render json: { success: false, errors: @submission.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    private

    def set_submission
      @submission = Submission.includes(:form_definition, :user, :workflow).find(params[:id])
    end

    def filtered_submissions # rubocop:disable Metrics/AbcSize
      submissions = Submission.all
      submissions = apply_search_filter(submissions)
      submissions = apply_basic_filters(submissions)
      submissions = apply_user_type_filter(submissions)
      apply_date_filters(submissions)
    end

    def apply_search_filter(submissions)
      return submissions unless params[:search].present?

      search_term = params[:search].strip
      if search_term =~ /\A\d+\z/
        submissions.where(id: search_term.to_i)
      else
        submissions.joins(:user).where("users.email ILIKE ?", "%#{search_term}%")
      end
    end

    def apply_basic_filters(submissions)
      submissions = submissions.where(form_definition_id: params[:form_id]) if params[:form_id].present?
      submissions = submissions.where(status: params[:status]) if params[:status].present?
      submissions = submissions.where(user_id: params[:user_id]) if params[:user_id].present?
      submissions
    end

    def apply_user_type_filter(submissions)
      return submissions unless params[:user_type].present?

      case params[:user_type]
      when "registered" then submissions.where.not(user_id: nil)
      when "anonymous" then submissions.where(user_id: nil)
      else submissions
      end
    end

    def apply_date_filters(submissions)
      if (from_date = safe_parse_date(params[:date_from]))
        submissions = submissions.where("submissions.created_at >= ?", from_date.beginning_of_day)
      end
      if (to_date = safe_parse_date(params[:date_to]))
        submissions = submissions.where("submissions.created_at <= ?", to_date.end_of_day)
      end
      submissions
    end
  end
end
