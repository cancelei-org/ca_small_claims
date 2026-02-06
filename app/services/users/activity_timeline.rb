# frozen_string_literal: true

module Users
  class ActivityTimeline
    ACTIVITY_TYPES = %w[submission_created submission_updated submission_completed
                        feedback_submitted profile_updated account_created].freeze

    attr_reader :user, :limit, :offset

    def initialize(user, limit: 50, offset: 0)
      @user = user
      @limit = limit
      @offset = offset
    end

    def activities
      @activities ||= build_activities.sort_by { |a| -a[:timestamp].to_i }[offset, limit] || []
    end

    def total_count
      @total_count ||= build_activities.size
    end

    private

    def build_activities
      @all_activities ||= [
        *submission_activities,
        *feedback_activities,
        *account_activity
      ]
    end

    def submission_activities
      user.submissions.map do |submission|
        activities = []

        # Created activity
        activities << {
          type: "submission_created",
          timestamp: submission.created_at,
          title: "Started form #{submission.form_definition.code}",
          description: submission.form_definition.title,
          metadata: {
            submission_id: submission.id,
            form_code: submission.form_definition.code,
            status: submission.status
          }
        }

        # Completed activity (if different from created)
        if submission.completed_at.present? && submission.completed_at != submission.created_at
          activities << {
            type: "submission_completed",
            timestamp: submission.completed_at,
            title: "Completed form #{submission.form_definition.code}",
            description: "Form submission marked as complete",
            metadata: {
              submission_id: submission.id,
              form_code: submission.form_definition.code,
              completion_percentage: submission.completion_percentage
            }
          }
        end

        # Updated activity (significant updates only)
        if submission.updated_at > submission.created_at + 1.minute &&
           submission.updated_at != submission.completed_at
          activities << {
            type: "submission_updated",
            timestamp: submission.updated_at,
            title: "Updated form #{submission.form_definition.code}",
            description: "Progress: #{submission.completion_percentage}%",
            metadata: {
              submission_id: submission.id,
              form_code: submission.form_definition.code,
              completion_percentage: submission.completion_percentage
            }
          }
        end

        activities
      end.flatten
    end

    def feedback_activities
      user.form_feedbacks.map do |feedback|
        {
          type: "feedback_submitted",
          timestamp: feedback.created_at,
          title: "Submitted feedback for #{feedback.form_definition.code}",
          description: "Rating: #{feedback.rating}/5 - #{feedback.issue_type_labels.first}",
          metadata: {
            feedback_id: feedback.id,
            form_code: feedback.form_definition.code,
            rating: feedback.rating,
            status: feedback.status
          }
        }
      end
    end

    def account_activity
      activities = []

      # Account creation
      activities << {
        type: "account_created",
        timestamp: user.created_at,
        title: "Account created",
        description: user.guest? ? "Guest account" : "Registered account",
        metadata: {
          user_id: user.id,
          guest: user.guest?
        }
      }

      # Profile updated (if profile was edited after creation)
      if user.updated_at > user.created_at + 1.minute && user.profile_complete?
        activities << {
          type: "profile_updated",
          timestamp: user.updated_at,
          title: "Profile updated",
          description: "Profile information saved",
          metadata: {
            user_id: user.id,
            profile_complete: user.profile_complete?
          }
        }
      end

      activities
    end
  end
end
