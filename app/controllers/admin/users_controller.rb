# frozen_string_literal: true

module Admin
  class UsersController < BaseController
    include Pagy::Backend

    before_action :set_user, only: %i[show activity]

    def index
      @pagy, @users = pagy(filtered_users.order(created_at: :desc), limit: 20)

      # Consolidate 3 COUNT queries into 1 for performance
      counts = User.select(
        "COUNT(*) as total_count",
        "COUNT(CASE WHEN guest = false THEN 1 END) as registered_count",
        "COUNT(CASE WHEN guest = true THEN 1 END) as guest_count"
      ).take

      @total_count = counts.total_count.to_i
      @registered_count = counts.registered_count.to_i
      @guest_count = counts.guest_count.to_i
    end

    def show
      # Consolidate 2 COUNT queries into 1 using sanitized SQL for performance
      user_id = @user.id.to_i
      counts = ActiveRecord::Base.connection.select_one(
        ActiveRecord::Base.sanitize_sql_array([
          "SELECT (SELECT COUNT(*) FROM submissions WHERE user_id = ?) as submissions_count, " \
          "(SELECT COUNT(*) FROM form_feedbacks WHERE user_id = ?) as feedbacks_count",
          user_id, user_id
        ])
      )

      @submissions_count = counts["submissions_count"].to_i
      @feedbacks_count = counts["feedbacks_count"].to_i
      @recent_submissions = @user.submissions.includes(:form_definition).recent.limit(5)
    end

    def activity
      page = (params[:page] || 1).to_i
      per_page = 20
      offset = (page - 1) * per_page

      timeline = Users::ActivityTimeline.new(@user, limit: per_page, offset: offset)
      @activities = timeline.activities
      @total_activities = timeline.total_count
      @current_page = page
      @total_pages = (@total_activities.to_f / per_page).ceil

      respond_to do |format|
        format.html
        format.json do
          render json: {
            activities: @activities,
            pagination: {
              current_page: @current_page,
              total_pages: @total_pages,
              total_count: @total_activities
            }
          }
        end
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def filtered_users
      users = User.all

      if params[:search].present?
        search_term = "%#{params[:search]}%"
        users = users.where("email ILIKE ? OR full_name ILIKE ?", search_term, search_term)
      end

      users = filter_by_type(users)
      users = filter_by_admin(users)
      filter_by_date(users)
    end

    def filter_by_type(users)
      case params[:user_type]
      when "registered" then users.registered
      when "guest" then users.guests
      else users
      end
    end

    def filter_by_admin(users)
      case params[:admin_status]
      when "admin" then users.where(admin: true)
      when "regular" then users.where(admin: false)
      else users
      end
    end

    def filter_by_date(users)
      if (from_date = safe_parse_date(params[:date_from]))
        users = users.where("users.created_at >= ?", from_date.beginning_of_day)
      end
      if (to_date = safe_parse_date(params[:date_to]))
        users = users.where("users.created_at <= ?", to_date.end_of_day)
      end
      users
    end
  end
end
