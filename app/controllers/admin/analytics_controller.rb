# frozen_string_literal: true

module Admin
  class AnalyticsController < BaseController
    def index
      @period = params[:period] || "30d"
      @start_date = params[:start_date]
      @end_date = params[:end_date]

      @analytics = Analytics::DashboardService.new(
        period: @period,
        start_date: @start_date,
        end_date: @end_date
      )

      @summary = @analytics.summary_stats
      @comparison = @analytics.period_comparison
      @daily_submissions = @analytics.daily_submissions
      @daily_completions = @analytics.daily_completions
      @popular_forms = @analytics.popular_forms(limit: 10)
      @status_breakdown = @analytics.status_breakdown
      @hourly_activity = @analytics.hourly_activity
      @weekly_activity = @analytics.weekly_activity
    end

    def export
      @period = params[:period] || "30d"
      @start_date = params[:start_date]
      @end_date = params[:end_date]
      @format = params[:format]&.to_sym || :csv

      analytics = Analytics::DashboardService.new(
        period: @period,
        start_date: @start_date,
        end_date: @end_date
      )

      begin
        case @format
        when :csv
          data = Reports::Exporter.csv(analytics)
          filename = "analytics_report_#{analytics.start_date.strftime('%Y%m%d')}_#{analytics.end_date.strftime('%Y%m%d')}.csv"
          send_data data, filename: filename, type: "text/csv", disposition: "attachment"
        when :pdf
          data = Reports::Exporter.pdf(analytics)
          filename = "analytics_report_#{analytics.start_date.strftime('%Y%m%d')}_#{analytics.end_date.strftime('%Y%m%d')}.pdf"
          send_data data, filename: filename, type: "application/pdf", disposition: "attachment"
        else
          redirect_to admin_analytics_path, alert: "Unsupported export format: #{@format}"
        end
      rescue NotImplementedError => e
        redirect_to admin_analytics_path, alert: e.message
      rescue StandardError => e
        Rails.logger.error "Export failed: #{e.message}"
        redirect_to admin_analytics_path, alert: "Export failed. Please try again."
      end
    end

    def funnel
      @period = params[:period] || "30d"
      @start_date = params[:start_date]
      @end_date = params[:end_date]
      @form_definition_id = params[:form_id]
      @user_type = params[:user_type]

      calculate_date_range

      @funnel = Analytics::FunnelAnalyzer.new(
        start_date: @start_date,
        end_date: @end_date,
        form_definition_id: @form_definition_id,
        user_type: @user_type
      )

      @stages = @funnel.funnel_stages
      @conversion_rates = @funnel.conversion_rates
      @drop_offs = @funnel.drop_off_points
      @biggest_drop_off = @funnel.biggest_drop_off
      @avg_time = @funnel.average_time_to_complete
      @median_time = @funnel.median_time_to_complete

      # Get form options for filter
      @forms = FormDefinition.active.order(:code)

      # User type comparison if no specific type selected
      @user_type_comparison = @funnel.funnel_by_user_type if @user_type.blank?
    end

    def time_metrics
      @period = params[:period] || "30d"
      @start_date = params[:start_date]
      @end_date = params[:end_date]
      @form_definition_id = params[:form_id]

      calculate_date_range

      @metrics = Analytics::TimeMetrics.new(
        start_date: @start_date,
        end_date: @end_date,
        form_definition_id: @form_definition_id
      )

      @statistics = @metrics.statistics
      @distribution = @metrics.time_distribution(bucket_size: 5)
      @by_form = @metrics.metrics_by_form(limit: 10)
      @trends = @metrics.time_trends(periods: 4, period_length: 7.days)
      @outliers = @metrics.outliers

      # Mode comparison if specific form selected
      @mode_comparison = @metrics.mode_comparison if @form_definition_id.present?

      # Get form options for filter
      @forms = FormDefinition.active.order(:code)
    end

    def drop_off
      @period = params[:period] || "30d"
      @start_date = params[:start_date]
      @end_date = params[:end_date]
      @form_definition_id = params[:form_id]

      calculate_date_range

      @analyzer = Analytics::DropOffAnalyzer.new(
        start_date: @start_date,
        end_date: @end_date,
        form_definition_id: @form_definition_id
      )

      @abandonment_count = @analyzer.abandonment_count
      @abandonment_rate = @analyzer.abandonment_rate
      @avg_time = @analyzer.average_time_before_abandonment
      @time_distribution = @analyzer.time_before_drop_off_distribution
      @completion_distribution = @analyzer.completion_percentage_at_abandonment
      @by_form = @analyzer.abandonment_by_form(limit: 10)

      # Field-level analysis if specific form selected
      if @form_definition_id.present?
        @field_stats = @analyzer.field_abandonment_stats
        @problematic_fields = @analyzer.problematic_fields(limit: 5)
        @suggestions = @analyzer.field_suggestions
      end

      # Get form options for filter
      @forms = FormDefinition.active.order(:code)
    end

    def geographic
      @period = params[:period] || "30d"
      @start_date = params[:start_date]
      @end_date = params[:end_date]

      calculate_date_range

      @analyzer = Analytics::GeographicAnalyzer.new(
        start_date: @start_date,
        end_date: @end_date
      )

      @summary = @analyzer.summary_stats
      @counties = @analyzer.usage_by_county
      @top_counties = @analyzer.top_counties(limit: 10)
      @underserved = @analyzer.underserved_counties(threshold: 5)
      @zero_usage = @analyzer.zero_usage_counties
      @regional = @analyzer.regional_breakdown
    end

    def sentiment
      @period = params[:period] || "30d"
      @start_date = params[:start_date]
      @end_date = params[:end_date]
      @form_definition_id = params[:form_id]

      calculate_date_range

      @analyzer = Analytics::SentimentAnalyzer.new(
        start_date: @start_date,
        end_date: @end_date,
        form_definition_id: @form_definition_id
      )

      @summary = @analyzer.summary_stats
      @sentiment_distribution = @analyzer.sentiment_distribution
      @trends = @analyzer.sentiment_trends(interval: (@end_date - @start_date) / 30)
      @rating_distribution = @analyzer.rating_distribution
      @themes = @analyzer.common_themes(limit: 15)
      @issues = @analyzer.issues_by_sentiment
      @alerts = @analyzer.sentiment_alerts

      # Get form options for filter
      @forms = FormDefinition.active.order(:code)
    end

    private

    # Period mapping to days offset
    PERIOD_DAYS = {
      "7d" => 7,
      "30d" => 30,
      "90d" => 90
    }.freeze

    # Calculate date range based on period parameter
    # Sets @start_date and @end_date instance variables
    def calculate_date_range
      days = PERIOD_DAYS.fetch(@period, 30)
      @start_date ||= days.days.ago
      @end_date ||= Time.current
    end
  end
end
