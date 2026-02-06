module Reports
  class Exporter
    attr_reader :analytics, :format

    def initialize(analytics:, format: :csv)
      @analytics = analytics
      @format = format
    end

    def generate
      case format
      when :csv
        generate_csv
      when :pdf
        generate_pdf
      else
        raise ArgumentError, "Unsupported format: #{format}"
      end
    end

    private

    def generate_csv
      require "csv"

      CSV.generate(headers: true) do |csv|
        write_csv_header(csv)
        write_summary_statistics(csv)
        write_daily_activity(csv)
        write_popular_forms(csv)
        write_status_breakdown(csv)
        write_hourly_activity(csv)
        write_weekly_activity(csv)
      end
    end

    def write_csv_header(csv)
      csv << [ "Report Type", "Small Claims Analytics Report" ]
      csv << [ "Generated At", Time.current.strftime("%Y-%m-%d %H:%M:%S %Z") ]
      csv << [ "Period", "#{analytics.start_date.strftime('%Y-%m-%d')} to #{analytics.end_date.strftime('%Y-%m-%d')}" ]
      csv << []
    end

    def write_summary_statistics(csv)
      csv << [ "Summary Statistics" ]
      csv << [ "Metric", "Value" ]
      csv << [ "Total Submissions", analytics.total_submissions ]
      csv << [ "Completed Submissions", analytics.completed_submissions ]
      csv << [ "Draft Submissions", analytics.draft_submissions ]
      csv << [ "Completion Rate", "#{analytics.completion_rate}%" ]
      csv << [ "Total Downloads", analytics.total_downloads ]
      csv << [ "Unique Users", analytics.unique_users ]
      csv << [ "Anonymous Sessions", analytics.anonymous_sessions ]
      csv << []
    end

    def write_daily_activity(csv)
      csv << [ "Daily Activity" ]
      csv << [ "Date", "Submissions", "Completions" ]
      daily_subs = analytics.daily_submissions
      daily_comps = analytics.daily_completions
      daily_subs.each do |date, count|
        csv << [ date.strftime("%Y-%m-%d"), count, daily_comps[date] || 0 ]
      end
      csv << []
    end

    def write_popular_forms(csv)
      csv << [ "Popular Forms" ]
      csv << [ "Rank", "Form Code", "Form Title", "Submissions", "Completion Rate", "Trend" ]
      analytics.popular_forms.each_with_index do |form, index|
        csv << [
          index + 1,
          form[:code],
          form[:title],
          form[:count],
          "#{form[:completion_rate]}%",
          form[:trend].to_s.titleize
        ]
      end
      csv << []
    end

    def write_status_breakdown(csv)
      csv << [ "Status Breakdown" ]
      csv << [ "Status", "Count" ]
      breakdown = analytics.status_breakdown
      csv << [ "Draft", breakdown[:draft] || 0 ]
      csv << [ "Completed", breakdown[:completed] || 0 ]
      csv << [ "Submitted", breakdown[:submitted] || 0 ]
      csv << []
    end

    def write_hourly_activity(csv)
      csv << [ "Hourly Activity (24-hour format)" ]
      csv << [ "Hour", "Submissions" ]
      analytics.hourly_activity.each do |hour, count|
        csv << [ "#{hour}:00", count ]
      end
      csv << []
    end

    def write_weekly_activity(csv)
      csv << [ "Weekly Activity" ]
      csv << [ "Day of Week", "Submissions" ]
      analytics.weekly_activity.each do |day, count|
        csv << [ day, count ]
      end
    end

    def generate_pdf
      # PDF generation requires a gem like Prawn
      # For now, return a simple text-based PDF placeholder
      # In production, you'd install 'prawn' gem and generate charts

      raise NotImplementedError, "PDF export requires the 'prawn' gem. Install it with: gem 'prawn'"

      # Example with Prawn (if installed):
      # require 'prawn'
      #
      # Prawn::Document.new do |pdf|
      #   pdf.text "Small Claims Analytics Report", size: 24, style: :bold
      #   pdf.text "Generated: #{Time.current.strftime('%Y-%m-%d %H:%M')}", size: 10
      #   pdf.move_down 20
      #
      #   # Summary table
      #   pdf.text "Summary Statistics", size: 16, style: :bold
      #   pdf.move_down 10
      #   summary_data = [
      #     ["Total Submissions", analytics.total_submissions],
      #     ["Completed", analytics.completed_submissions],
      #     ["Completion Rate", "#{analytics.completion_rate}%"]
      #   ]
      #   pdf.table(summary_data)
      #
      #   # Charts would go here (requires prawn-graph or similar)
      # end.render
    end

    class << self
      # Quick export methods
      def csv(analytics)
        new(analytics: analytics, format: :csv).generate
      end

      def pdf(analytics)
        new(analytics: analytics, format: :pdf).generate
      end
    end
  end
end
