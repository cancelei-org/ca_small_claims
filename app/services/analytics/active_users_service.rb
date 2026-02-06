module Analytics
  class ActiveUsersService
    # Consider a user/session "active" if they've had activity within this window
    ACTIVE_THRESHOLD = 15.minutes

    attr_reader :threshold

    def initialize(threshold: ACTIVE_THRESHOLD)
      @threshold = threshold
    end

    # Get count of currently active users (registered + anonymous)
    def active_count
      active_users_count + active_sessions_count
    end

    # Get count of active registered users
    def active_users_count
      active_user_ids.count
    end

    # Get count of active anonymous sessions
    def active_sessions_count
      active_session_ids.count
    end

    # Get list of active registered users with their recent activity
    def active_users
      User.where(id: active_user_ids)
        .select("users.*, MAX(submissions.updated_at) as last_activity")
        .joins(:submissions)
        .where("submissions.updated_at >= ?", threshold.ago)
        .group("users.id")
        .order("last_activity DESC")
        .map do |user|
          {
            type: "registered",
            user_id: user.id,
            email: user.email,
            name: user.full_name || user.email&.split("@")&.first,
            last_activity: user.last_activity,
            active_for: time_diff_in_words(user.last_activity)
          }
        end
    end

    # Get list of active anonymous sessions with their recent activity
    def active_sessions
      Submission.where(user_id: nil)
        .where("submissions.updated_at >= ?", threshold.ago)
        .where.not(session_id: nil)
        .select("session_id, MAX(updated_at) as last_activity")
        .group(:session_id)
        .order("last_activity DESC")
        .map do |record|
          {
            type: "anonymous",
            session_id: record.session_id,
            last_activity: record.last_activity,
            active_for: time_diff_in_words(record.last_activity)
          }
        end
    end

    # Get all active users and sessions combined
    def all_active
      (active_users + active_sessions).sort_by { |a| -a[:last_activity].to_i }
    end

    # Activity breakdown by page/section
    def activity_by_page
      recent_submissions = Submission.where("submissions.updated_at >= ?", threshold.ago)

      {
        total: recent_submissions.count,
        by_form: activity_by_form,
        by_workflow: activity_by_workflow,
        by_status: recent_submissions.group(:status).count
      }
    end

    # Activity by specific form
    def activity_by_form
      Submission.where("submissions.updated_at >= ?", threshold.ago)
        .joins(:form_definition)
        .group("form_definitions.code", "form_definitions.title")
        .count
        .map do |form_info, count|
          code, title = form_info
          {
            form_code: code,
            form_title: title,
            active_users: count
          }
        end
        .sort_by { |f| -f[:active_users] }
    end

    # Activity in workflows vs direct form access
    def activity_by_workflow
      recent_submissions = Submission.where("submissions.updated_at >= ?", threshold.ago)

      {
        workflow: recent_submissions.where.not(workflow_id: nil).count,
        direct: recent_submissions.where(workflow_id: nil).count
      }
    end

    # Recent activity feed (last N actions)
    def recent_activity_feed(limit: 20)
      # Get recent submissions updates
      recent_submissions = Submission.includes(:form_definition, :user)
        .where("submissions.updated_at >= ?", 1.hour.ago)
        .order(updated_at: :desc)
        .limit(limit)

      recent_submissions.map do |submission|
        {
          timestamp: submission.updated_at,
          user: submission.user ? {
            type: "registered",
            name: submission.user.full_name || submission.user.email&.split("@")&.first
          } : {
            type: "anonymous",
            session_id: submission.session_id&.first(8)
          },
          action: determine_action(submission),
          form_code: submission.form_definition.code,
          form_title: submission.form_definition.title,
          status: submission.status
        }
      end
    end

    # Session duration statistics
    def session_durations
      active_subs = Submission.where("submissions.updated_at >= ?", threshold.ago)
        .where.not(created_at: nil)

      durations = active_subs.pluck(:created_at, :updated_at).map do |created, updated|
        ((updated - created) / 60.0).round
      end

      return {} if durations.empty?

      sorted = durations.sort

      {
        count: durations.count,
        avg_minutes: (durations.sum.to_f / durations.count).round,
        median_minutes: sorted[sorted.length / 2],
        min_minutes: sorted.first,
        max_minutes: sorted.last
      }
    end

    # Page views (count of form accesses)
    def page_views
      {
        last_15_min: Submission.where("submissions.updated_at >= ?", 15.minutes.ago).count,
        last_hour: Submission.where("submissions.updated_at >= ?", 1.hour.ago).count,
        last_24_hours: Submission.where("submissions.updated_at >= ?", 24.hours.ago).count
      }
    end

    # Breakdown by user type (registered vs anonymous)
    def user_type_breakdown
      recent_submissions = Submission.where("submissions.updated_at >= ?", threshold.ago)

      {
        registered: recent_submissions.where.not(user_id: nil).select(:user_id).distinct.count,
        anonymous: recent_submissions.where(user_id: nil).select(:session_id).distinct.count
      }
    end

    private

    def active_user_ids
      @active_user_ids ||= Submission.where("submissions.updated_at >= ?", threshold.ago)
        .where.not(user_id: nil)
        .distinct
        .pluck(:user_id)
    end

    def active_session_ids
      @active_session_ids ||= Submission.where("submissions.updated_at >= ?", threshold.ago)
        .where(user_id: nil)
        .where.not(session_id: nil)
        .distinct
        .pluck(:session_id)
    end

    def determine_action(submission)
      if submission.completed_at.present? && submission.updated_at - submission.completed_at < 1.minute
        "completed"
      elsif submission.pdf_generated_at.present? && submission.updated_at - submission.pdf_generated_at < 1.minute
        "downloaded"
      elsif submission.created_at == submission.updated_at
        "started"
      else
        "editing"
      end
    end

    def time_diff_in_words(time)
      diff = Time.current - time
      if diff < 1.minute
        "just now"
      elsif diff < 1.hour
        "#{(diff / 60).round}m ago"
      else
        "#{(diff / 3600).round}h ago"
      end
    end
  end
end
