module Analytics
  class TimeMetrics
    attr_reader :start_date, :end_date, :form_definition_id

    def initialize(start_date: 30.days.ago, end_date: Time.current, form_definition_id: nil)
      @start_date = start_date.to_date.beginning_of_day
      @end_date = end_date.to_date.end_of_day
      @form_definition_id = form_definition_id
    end

    # Get completion times in minutes for all completed submissions
    def completion_times
      @completion_times ||= base_scope
        .where.not(completed_at: nil)
        .where("completed_at >= ? AND completed_at <= ?", start_date, end_date)
        .pluck(:id, Arel.sql("EXTRACT(EPOCH FROM (completed_at - created_at)) / 60"))
        .map { |id, minutes| { id: id, minutes: minutes.to_i } }
    end

    # Statistical metrics
    def statistics
      times = completion_times.pluck(:minutes)
      return {} if times.empty?

      sorted = times.sort

      {
        count: times.count,
        min: sorted.first,
        max: sorted.last,
        mean: (times.sum.to_f / times.count).round(1),
        median: percentile(sorted, 50),
        p25: percentile(sorted, 25),
        p75: percentile(sorted, 75),
        p90: percentile(sorted, 90),
        p95: percentile(sorted, 95),
        p99: percentile(sorted, 99)
      }
    end

    # Time distribution for histogram (grouped into buckets)
    def time_distribution(bucket_size: 5)
      times = completion_times.pluck(:minutes)
      return {} if times.empty?

      max_time = times.max
      buckets = {}

      # Create buckets (0-5, 5-10, 10-15, etc.)
      (0..max_time).step(bucket_size) do |bucket_start|
        bucket_end = bucket_start + bucket_size - 1
        bucket_label = "#{bucket_start}-#{bucket_end} min"
        count = times.count { |t| t >= bucket_start && t < bucket_start + bucket_size }
        buckets[bucket_label] = count if count > 0
      end

      buckets
    end

    # Metrics per form (top N forms by completion count)
    def metrics_by_form(limit: 10)
      FormDefinition.active
        .joins(:submissions)
        .where(submissions: { status: "completed", completed_at: start_date..end_date })
        .select("form_definitions.id, form_definitions.code, form_definitions.title, COUNT(submissions.id) as completion_count")
        .group("form_definitions.id, form_definitions.code, form_definitions.title")
        .order("completion_count DESC")
        .limit(limit)
        .map do |form|
          analyzer = self.class.new(
            start_date: start_date,
            end_date: end_date,
            form_definition_id: form.id
          )
          stats = analyzer.statistics

          {
            form_code: form.code,
            form_title: form.title,
            completion_count: form.completion_count,
            median_time: stats[:median],
            p75_time: stats[:p75],
            p90_time: stats[:p90],
            mean_time: stats[:mean]
          }
        end
    end

    # Track time improvements over time (compare periods)
    def time_trends(periods: 4, period_length: 7.days)
      trends = []

      periods.times do |i|
        period_end = end_date - (i * period_length)
        period_start = period_end - period_length

        analyzer = self.class.new(
          start_date: period_start,
          end_date: period_end,
          form_definition_id: form_definition_id
        )

        stats = analyzer.statistics

        trends.unshift({
          period: "#{period_start.strftime('%b %d')} - #{period_end.strftime('%b %d')}",
          period_start: period_start,
          period_end: period_end,
          count: stats[:count] || 0,
          median: stats[:median] || 0,
          mean: stats[:mean] || 0
        })
      end

      trends
    end

    # Compare wizard vs traditional mode (if workflow_id is present)
    def mode_comparison
      wizard_times = Submission
        .where(form_definition_id: form_definition_id)
        .where.not(workflow_id: nil)
        .where.not(completed_at: nil)
        .where(completed_at: start_date..end_date)
        .pluck(Arel.sql("EXTRACT(EPOCH FROM (completed_at - created_at)) / 60"))
        .map(&:to_i)

      traditional_times = Submission
        .where(form_definition_id: form_definition_id)
        .where(workflow_id: nil)
        .where.not(completed_at: nil)
        .where(completed_at: start_date..end_date)
        .pluck(Arel.sql("EXTRACT(EPOCH FROM (completed_at - created_at)) / 60"))
        .map(&:to_i)

      {
        wizard: {
          count: wizard_times.count,
          median: wizard_times.any? ? percentile(wizard_times.sort, 50) : 0,
          mean: wizard_times.any? ? (wizard_times.sum.to_f / wizard_times.count).round(1) : 0
        },
        traditional: {
          count: traditional_times.count,
          median: traditional_times.any? ? percentile(traditional_times.sort, 50) : 0,
          mean: traditional_times.any? ? (traditional_times.sum.to_f / traditional_times.count).round(1) : 0
        }
      }
    end

    # Fastest and slowest completions
    def outliers
      times = completion_times
      return { fastest: [], slowest: [] } if times.empty?

      sorted = times.sort_by { |t| t[:minutes] }

      {
        fastest: sorted.first(5).map { |t| { submission_id: t[:id], minutes: t[:minutes] } },
        slowest: sorted.last(5).reverse.map { |t| { submission_id: t[:id], minutes: t[:minutes] } }
      }
    end

    private

    def base_scope
      scope = Submission.all
      scope = scope.where(form_definition_id: form_definition_id) if form_definition_id.present?
      scope
    end

    # Calculate percentile from sorted array
    def percentile(sorted_array, percentile)
      return 0 if sorted_array.empty?

      index = (percentile / 100.0) * (sorted_array.length - 1)
      lower = sorted_array[index.floor]
      upper = sorted_array[index.ceil]

      # Linear interpolation
      (lower + (upper - lower) * (index - index.floor)).round
    end
  end
end
