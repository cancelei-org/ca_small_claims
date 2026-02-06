module Analytics
  class FunnelAnalyzer
    attr_reader :start_date, :end_date, :form_definition_id, :user_type

    def initialize(start_date: 7.days.ago, end_date: Time.current, form_definition_id: nil, user_type: nil)
      @start_date = start_date.to_date.beginning_of_day
      @end_date = end_date.to_date.end_of_day
      @form_definition_id = form_definition_id
      @user_type = user_type # 'registered', 'anonymous', or nil for all
    end

    # Main funnel stages with counts
    def funnel_stages
      @funnel_stages ||= {
        started: started_count,
        in_progress: in_progress_count,
        half_complete: half_complete_count,
        completed: completed_count,
        downloaded: downloaded_count
      }
    end

    # Conversion rates between stages
    def conversion_rates
      stages = funnel_stages

      {
        start_to_progress: calculate_rate(stages[:in_progress], stages[:started]),
        progress_to_half: calculate_rate(stages[:half_complete], stages[:in_progress]),
        half_to_complete: calculate_rate(stages[:completed], stages[:half_complete]),
        complete_to_download: calculate_rate(stages[:downloaded], stages[:completed]),
        overall_completion: calculate_rate(stages[:completed], stages[:started]),
        overall_download: calculate_rate(stages[:downloaded], stages[:started])
      }
    end

    # Drop-off points (inverse of conversion rates)
    def drop_off_points
      rates = conversion_rates

      [
        { stage: "Started → In Progress", drop_off_rate: 100 - rates[:start_to_progress], count: funnel_stages[:started] - funnel_stages[:in_progress] },
        { stage: "In Progress → 50% Complete", drop_off_rate: 100 - rates[:progress_to_half], count: funnel_stages[:in_progress] - funnel_stages[:half_complete] },
        { stage: "50% → Completed", drop_off_rate: 100 - rates[:half_to_complete], count: funnel_stages[:half_complete] - funnel_stages[:completed] },
        { stage: "Completed → Downloaded", drop_off_rate: 100 - rates[:complete_to_download], count: funnel_stages[:completed] - funnel_stages[:downloaded] }
      ].sort_by { |point| -point[:drop_off_rate] }
    end

    # Biggest drop-off point
    def biggest_drop_off
      drop_off_points.first
    end

    # Funnel by form (top N forms)
    def funnel_by_form(limit: 10)
      FormDefinition.active.limit(limit).map do |form|
        analyzer = self.class.new(
          start_date: start_date,
          end_date: end_date,
          form_definition_id: form.id,
          user_type: user_type
        )

        {
          form_code: form.code,
          form_title: form.title,
          funnel: analyzer.funnel_stages,
          conversion_rate: analyzer.conversion_rates[:overall_completion]
        }
      end.sort_by { |f| -f[:conversion_rate] }
    end

    # Average time to complete (in minutes)
    def average_time_to_complete
      completed_submissions = base_scope
        .where.not(completed_at: nil)
        .where("completed_at >= ? AND completed_at <= ?", start_date, end_date)

      return 0 if completed_submissions.empty?

      total_minutes = completed_submissions.sum do |submission|
        ((submission.completed_at - submission.created_at) / 60.0).round
      end

      (total_minutes.to_f / completed_submissions.count).round
    end

    # Median time to complete (in minutes)
    def median_time_to_complete
      times = base_scope
        .where.not(completed_at: nil)
        .where("completed_at >= ? AND completed_at <= ?", start_date, end_date)
        .pluck(Arel.sql("EXTRACT(EPOCH FROM (completed_at - created_at)) / 60"))
        .map(&:to_i)

      return 0 if times.empty?

      sorted = times.sort
      len = sorted.length
      (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
    end

    # Funnel comparison by user type
    def funnel_by_user_type
      {
        registered: self.class.new(
          start_date: start_date,
          end_date: end_date,
          form_definition_id: form_definition_id,
          user_type: "registered"
        ).funnel_stages,
        anonymous: self.class.new(
          start_date: start_date,
          end_date: end_date,
          form_definition_id: form_definition_id,
          user_type: "anonymous"
        ).funnel_stages
      }
    end

    private

    def base_scope
      scope = Submission.where(created_at: start_date..end_date)
      scope = scope.where(form_definition_id: form_definition_id) if form_definition_id.present?
      scope = apply_user_type_filter(scope) if user_type.present?
      scope
    end

    def apply_user_type_filter(scope)
      case user_type
      when "registered"
        scope.where.not(user_id: nil)
      when "anonymous"
        scope.where(user_id: nil)
      else
        scope
      end
    end

    # Count of submissions that were started (created)
    def started_count
      base_scope.count
    end

    # Count with any form data (at least one field filled)
    def in_progress_count
      base_scope.where("form_data::text != '{}'").count
    end

    # Count that reached 50% completion
    # Note: This requires calculating completion_percentage for each record
    # For performance, we approximate by checking if half of fields have data
    def half_complete_count
      # Get submissions where at least half of the form fields have data
      base_scope.count { |s| s.completion_percentage >= 50 }
    end

    # Count of completed submissions
    def completed_count
      base_scope.where.not(completed_at: nil).count
    end

    # Count of downloaded PDFs
    def downloaded_count
      base_scope.where.not(pdf_generated_at: nil).count
    end

    def calculate_rate(numerator, denominator)
      return 0 if denominator.zero?
      ((numerator.to_f / denominator) * 100).round(1)
    end
  end
end
