module Analytics
  class DropOffAnalyzer
    attr_reader :start_date, :end_date, :form_definition_id

    def initialize(start_date: 30.days.ago, end_date: Time.current, form_definition_id: nil)
      @start_date = start_date.to_date.beginning_of_day
      @end_date = end_date.to_date.end_of_day
      @form_definition_id = form_definition_id
    end

    # Get abandoned submissions (drafts that haven't been touched in 24+ hours)
    def abandoned_submissions
      @abandoned_submissions ||= base_scope
        .where(status: "draft")
        .where("updated_at < ?", 24.hours.ago)
        .where(created_at: start_date..end_date)
    end

    # Count of abandoned submissions
    def abandonment_count
      abandoned_submissions.count
    end

    # Calculate abandonment rate (abandoned / total started)
    def abandonment_rate
      total_started = base_scope.where(created_at: start_date..end_date).count
      return 0 if total_started.zero?

      ((abandonment_count.to_f / total_started) * 100).round(1)
    end

    # Identify last field completed before abandonment
    # Returns hash: { field_name => count }
    def last_field_before_drop_off
      field_counts = Hash.new(0)

      abandoned_submissions.find_each do |submission|
        last_field = find_last_completed_field(submission)
        field_counts[last_field] += 1 if last_field.present?
      end

      # Sort by count descending
      field_counts.sort_by { |_, count| -count }.to_h
    end

    # Field abandonment rates per form
    # Returns array of hashes with field info and abandonment stats
    def field_abandonment_stats
      return [] if form_definition_id.blank?

      form = FormDefinition.find(form_definition_id)
      fields = form.field_definitions.order(:position)
      total_abandoned = abandonment_count

      return [] if total_abandoned.zero?

      fields.map do |field|
        abandonment_at_field = last_field_before_drop_off[field.name] || 0
        abandonment_percentage = ((abandonment_at_field.to_f / total_abandoned) * 100).round(1)

        {
          field_name: field.name,
          field_label: field.label || field.name,
          position: field.position,
          section: field.section,
          required: field.required,
          field_type: field.field_type,
          abandonment_count: abandonment_at_field,
          abandonment_percentage: abandonment_percentage,
          avg_time_before_drop: average_time_at_field(field.name)
        }
      end.select { |stat| stat[:abandonment_count] > 0 }
        .sort_by { |stat| -stat[:abandonment_percentage] }
    end

    # Most problematic fields (highest abandonment rates)
    def problematic_fields(limit: 5)
      field_abandonment_stats.first(limit)
    end

    # Average time spent before abandonment (in minutes)
    def average_time_before_abandonment
      times = abandoned_submissions.pluck(:created_at, :updated_at).map do |created, updated|
        ((updated - created) / 60.0).round
      end

      return 0 if times.empty?
      (times.sum.to_f / times.count).round
    end

    # Time distribution before drop-off
    def time_before_drop_off_distribution
      times = abandoned_submissions.pluck(:created_at, :updated_at).map do |created, updated|
        ((updated - created) / 60.0).round
      end

      return {} if times.empty?

      # Group into buckets: 0-5, 5-10, 10-15, 15-30, 30-60, 60+
      buckets = {
        "0-5 min" => times.count { |t| t >= 0 && t < 5 },
        "5-10 min" => times.count { |t| t >= 5 && t < 10 },
        "10-15 min" => times.count { |t| t >= 10 && t < 15 },
        "15-30 min" => times.count { |t| t >= 15 && t < 30 },
        "30-60 min" => times.count { |t| t >= 30 && t < 60 },
        "60+ min" => times.count { |t| t >= 60 }
      }

      buckets.select { |_, count| count > 0 }
    end

    # Abandonment by form comparison
    def abandonment_by_form(limit: 10)
      FormDefinition.active
        .joins(:submissions)
        .where(submissions: { status: "draft", created_at: start_date..end_date })
        .where("submissions.updated_at < ?", 24.hours.ago)
        .select("form_definitions.id, form_definitions.code, form_definitions.title, COUNT(submissions.id) as abandonment_count")
        .group("form_definitions.id, form_definitions.code, form_definitions.title")
        .order("abandonment_count DESC")
        .limit(limit)
        .map do |form|
          total_started = Submission.where(form_definition_id: form.id, created_at: start_date..end_date).count
          abandonment_rate = total_started > 0 ? ((form.abandonment_count.to_f / total_started) * 100).round(1) : 0

          {
            form_code: form.code,
            form_title: form.title,
            abandonment_count: form.abandonment_count,
            total_started: total_started,
            abandonment_rate: abandonment_rate
          }
        end
    end

    # Completion percentage distribution for abandoned forms
    def completion_percentage_at_abandonment
      percentages = abandoned_submissions.map(&:completion_percentage)
      return {} if percentages.empty?

      buckets = {
        "0-10%" => percentages.count { |p| p >= 0 && p < 10 },
        "10-25%" => percentages.count { |p| p >= 10 && p < 25 },
        "25-50%" => percentages.count { |p| p >= 25 && p < 50 },
        "50-75%" => percentages.count { |p| p >= 50 && p < 75 },
        "75-90%" => percentages.count { |p| p >= 75 && p < 90 },
        "90-99%" => percentages.count { |p| p >= 90 && p < 100 }
      }

      buckets.select { |_, count| count > 0 }
    end

    # Suggestions for fields that may need simplification
    def field_suggestions
      problematic = problematic_fields(limit: 10)

      problematic.map do |field|
        suggestions = []

        # High abandonment rate
        suggestions << "High abandonment rate (#{field[:abandonment_percentage]}%) - consider simplifying or adding help text" if field[:abandonment_percentage] > 20

        # Required field with high drop-off
        suggestions << "Required field causing significant drop-off - evaluate if it's truly necessary" if field[:required] && field[:abandonment_percentage] > 15

        # Complex field types
        suggestions << "Multiple choice field with high drop-off - review options for clarity" if %w[select checkbox radio].include?(field[:field_type]) && field[:abandonment_percentage] > 10

        next if suggestions.empty?

        {
          field_name: field[:field_name],
          field_label: field[:field_label],
          abandonment_percentage: field[:abandonment_percentage],
          suggestions: suggestions
        }
      end.compact
    end

    private

    def base_scope
      scope = Submission.all
      scope = scope.where(form_definition_id: form_definition_id) if form_definition_id.present?
      scope
    end

    # Find the last field that was completed in a submission
    def find_last_completed_field(submission)
      return nil if submission.form_data.blank?

      # Get all fields for this form in order
      fields = submission.form_definition.field_definitions.order(:position)

      # Find the last field with data
      last_filled = nil
      fields.each do |field|
        value = submission.form_data[field.name]
        last_filled = field.name if value.present?
      end

      last_filled
    end

    # Calculate average time spent before dropping off at a specific field
    def average_time_at_field(field_name)
      submissions = abandoned_submissions.select do |sub|
        find_last_completed_field(sub) == field_name
      end

      return 0 if submissions.empty?

      times = submissions.map { |sub| ((sub.updated_at - sub.created_at) / 60.0).round }
      (times.sum.to_f / times.count).round
    end
  end
end
