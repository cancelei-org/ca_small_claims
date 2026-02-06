# frozen_string_literal: true

module Analytics
  class DashboardService
    attr_reader :start_date, :end_date, :period

    PERIOD_DAYS = {
      "7d" => 7,
      "30d" => 30,
      "90d" => 90
    }.freeze

    def initialize(period: "30d", start_date: nil, end_date: nil)
      @period = period
      @end_date = parse_date(end_date) || Date.current
      @start_date = parse_date(start_date) || calculate_start_date
    end

    def summary_stats
      @summary_stats ||= {
        total_submissions: submissions_in_period.count,
        completed_submissions: submissions_in_period.where(status: "completed").count,
        draft_submissions: submissions_in_period.where(status: "draft").count,
        completion_rate: calculate_completion_rate,
        total_downloads: submissions_in_period.where.not(pdf_generated_at: nil).count,
        unique_users: submissions_in_period.where.not(user_id: nil).distinct.count(:user_id),
        anonymous_sessions: submissions_in_period.where(user_id: nil).distinct.count(:session_id)
      }
    end

    def period_comparison
      @period_comparison ||= begin
        previous_start = @start_date - period_days.days
        previous_end = @start_date - 1.day

        current_count = submissions_in_period.count
        previous_count = Submission.where(created_at: previous_start.beginning_of_day..previous_end.end_of_day).count

        current_completions = submissions_in_period.where(status: "completed").count
        previous_completions = Submission.where(
          created_at: previous_start.beginning_of_day..previous_end.end_of_day,
          status: "completed"
        ).count

        {
          submissions_change: calculate_percentage_change(previous_count, current_count),
          completions_change: calculate_percentage_change(previous_completions, current_completions)
        }
      end
    end

    def daily_submissions
      @daily_submissions ||= submissions_in_period
        .group("DATE(created_at)")
        .count
        .transform_keys { |k| k.is_a?(String) ? Date.parse(k) : k }
        .then { |h| fill_missing_dates(h) }
    end

    def daily_completions
      @daily_completions ||= submissions_in_period
        .where(status: "completed")
        .group("DATE(created_at)")
        .count
        .transform_keys { |k| k.is_a?(String) ? Date.parse(k) : k }
        .then { |h| fill_missing_dates(h) }
    end

    def popular_forms(limit: 10)
      @popular_forms ||= begin
        form_stats = submissions_in_period
          .joins(:form_definition)
          .group("form_definitions.id", "form_definitions.code", "form_definitions.title")
          .select(
            "form_definitions.id",
            "form_definitions.code",
            "form_definitions.title",
            "COUNT(*) as total_count",
            "SUM(CASE WHEN submissions.status = 'completed' THEN 1 ELSE 0 END) as completed_count"
          )
          .order("total_count DESC")
          .limit(limit)

        previous_counts = previous_period_form_counts

        form_stats.map do |row|
          total = row.total_count.to_i
          completed = row.completed_count.to_i
          prev_count = previous_counts[row.id] || 0

          {
            code: row.code,
            title: row.title,
            count: total,
            completion_rate: total.positive? ? (completed.to_f / total * 100).round : 0,
            trend: calculate_trend(prev_count, total)
          }
        end
      end
    end

    def status_breakdown
      @status_breakdown ||= {
        draft: submissions_in_period.where(status: "draft").count,
        completed: submissions_in_period.where(status: "completed").count,
        submitted: submissions_in_period.where(status: "submitted").count
      }
    end

    def hourly_activity
      @hourly_activity ||= begin
        hourly = submissions_in_period
          .group("EXTRACT(HOUR FROM created_at)")
          .count
          .transform_keys(&:to_i)

        (0..23).to_h { |h| [ h, hourly[h] || 0 ] }
      end
    end

    def weekly_activity
      @weekly_activity ||= begin
        daily = submissions_in_period
          .group("EXTRACT(DOW FROM created_at)")
          .count
          .transform_keys(&:to_i)

        day_names = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
        day_names.each_with_index.to_h { |name, i| [ name, daily[i] || 0 ] }
      end
    end

    private

    def submissions_in_period
      @submissions_in_period ||= Submission.where(
        created_at: @start_date.beginning_of_day..@end_date.end_of_day
      )
    end

    def parse_date(date_string)
      return nil if date_string.blank?
      Date.parse(date_string.to_s)
    rescue ArgumentError
      nil
    end

    def calculate_start_date
      @end_date - period_days.days + 1.day
    end

    def period_days
      PERIOD_DAYS[@period] || 30
    end

    def calculate_completion_rate
      total = submissions_in_period.count
      return 0 if total.zero?

      completed = submissions_in_period.where(status: "completed").count
      (completed.to_f / total * 100).round(1)
    end

    def calculate_percentage_change(old_value, new_value)
      return 0 if old_value.zero?
      ((new_value - old_value).to_f / old_value * 100).round
    end

    def calculate_trend(previous, current)
      return :stable if previous == current
      current > previous ? :up : :down
    end

    def fill_missing_dates(hash)
      (@start_date..@end_date).to_h { |date| [ date, hash[date] || 0 ] }
    end

    def previous_period_form_counts
      previous_start = @start_date - period_days.days
      previous_end = @start_date - 1.day

      Submission.where(created_at: previous_start.beginning_of_day..previous_end.end_of_day)
        .group(:form_definition_id)
        .count
    end
  end
end
