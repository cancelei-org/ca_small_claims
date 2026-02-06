# frozen_string_literal: true

module Burner
  # Analyzes E2E test logs from burner instances
  # Provides parsing, trend analysis, and reporting
  class LogAnalyzer
    LOG_DIR = Rails.root.join("tmp", "burner_e2e_logs")

    TestRun = Struct.new(:instance, :timestamp, :passed, :failed, :skipped,
                         :duration, :failures, :file, keyword_init: true) do
      def success?
        failed.zero?
      end

      def pass_rate
        total = passed + failed
        return 0.0 if total.zero?

        (passed.to_f / total * 100).round(2)
      end
    end

    FailureDetail = Struct.new(:test_name, :error_message, :file, :line, keyword_init: true)

    TrendReport = Struct.new(:instance, :runs, :avg_pass_rate, :avg_duration,
                             :trend, :common_failures, keyword_init: true)

    def initialize(instance = nil)
      @instance = instance
    end

    # Get the latest test run for an instance
    # @param instance [String] burner instance name
    # @return [TestRun, nil]
    def latest(instance = @instance)
      log_files = logs_for(instance)
      return nil if log_files.empty?

      parse_log(log_files.first, instance)
    end

    # Get all test runs for an instance
    # @param instance [String] burner instance name
    # @param limit [Integer] max runs to return
    # @return [Array<TestRun>]
    def all_runs(instance = @instance, limit: 50)
      logs_for(instance).take(limit).map { |f| parse_log(f, instance) }
    end

    # Analyze trends across test runs
    # @param instance [String] burner instance name
    # @param runs [Integer] number of runs to analyze
    # @return [TrendReport]
    def trend_analysis(instance = @instance, runs: 10)
      test_runs = all_runs(instance, limit: runs)
      return nil if test_runs.empty?

      pass_rates = test_runs.map(&:pass_rate)
      durations = test_runs.map(&:duration).compact

      trend = calculate_trend(pass_rates)

      # Find commonly failing tests
      failure_counts = Hash.new(0)
      test_runs.flat_map(&:failures).each do |failure|
        failure_counts[failure.test_name] += 1
      end

      common_failures = failure_counts
        .sort_by { |_, count| -count }
        .take(5)
        .map { |name, count| { test: name, occurrences: count } }

      TrendReport.new(
        instance: instance,
        runs: test_runs.size,
        avg_pass_rate: (pass_rates.sum / pass_rates.size).round(2),
        avg_duration: durations.any? ? (durations.sum / durations.size).round(2) : nil,
        trend: trend,
        common_failures: common_failures
      )
    end

    # Compare test results between two instances
    # @param instance1 [String] first burner instance
    # @param instance2 [String] second burner instance
    # @return [Hash] comparison results
    def compare_instances(instance1, instance2)
      run1 = latest(instance1)
      run2 = latest(instance2)

      return nil unless run1 && run2

      {
        instance1: {
          name: instance1,
          passed: run1.passed,
          failed: run1.failed,
          pass_rate: run1.pass_rate
        },
        instance2: {
          name: instance2,
          passed: run2.passed,
          failed: run2.failed,
          pass_rate: run2.pass_rate
        },
        comparison: {
          pass_rate_diff: (run1.pass_rate - run2.pass_rate).round(2),
          duration_diff: run1.duration && run2.duration ? (run1.duration - run2.duration).round(2) : nil
        }
      }
    end

    # Generate summary report for all instances
    # @return [Hash] summary for all instances
    def summary_report
      %w[ca1 ca2 ca3].each_with_object({}) do |instance, report|
        run = latest(instance)
        next unless run

        report[instance] = {
          timestamp: run.timestamp,
          passed: run.passed,
          failed: run.failed,
          pass_rate: run.pass_rate,
          success: run.success?
        }
      end
    end

    private

    def logs_for(instance)
      pattern = instance ? "#{instance}_*.log" : "*.log"
      Dir.glob(LOG_DIR.join(pattern)).sort_by { |f| File.mtime(f) }.reverse
    end

    def parse_log(file_path, instance)
      content = File.read(file_path)
      filename = File.basename(file_path)

      # Extract timestamp from filename
      timestamp = extract_timestamp(filename)

      # Parse test counts
      passed = count_patterns(content, /\[PASS\]|\✓|(?:^|\s)passed\b/)
      failed = count_patterns(content, /\[FAIL\]|\✗|(?:^|\s)failed\b/)
      skipped = count_patterns(content, /\[SKIP\]|(?:^|\s)skipped\b/)

      # Extract failures
      failures = extract_failures(content)

      # Extract duration
      duration = extract_duration(content)

      TestRun.new(
        instance: instance,
        timestamp: timestamp,
        passed: passed,
        failed: failed,
        skipped: skipped,
        duration: duration,
        failures: failures,
        file: filename
      )
    end

    def extract_timestamp(filename)
      if (match = filename.match(/(\d{8}_\d{6})/))
        Time.strptime(match[1], "%Y%m%d_%H%M%S")
      end
    rescue ArgumentError
      nil
    end

    def count_patterns(content, pattern)
      content.scan(pattern).size
    end

    def extract_failures(content)
      failures = []

      # Playwright format: ✘ [browser] › path/to/test.spec.js:123:45 › Test Name
      content.scan(/[✗✘]\s*\[.*?\]\s*›\s*(.+?):(\d+).*?›\s*(.+)/).each do |file, line, name|
        failures << FailureDetail.new(
          test_name: name.strip,
          file: file.strip,
          line: line.to_i,
          error_message: nil
        )
      end

      # Jest format: ✕ Test Name
      content.scan(/[✕✗]\s+(.+)/).each do |match|
        name = match.first.strip
        next if name.include?("›") # Skip if already parsed as Playwright

        failures << FailureDetail.new(
          test_name: name,
          file: nil,
          line: nil,
          error_message: nil
        )
      end

      failures.uniq { |f| f.test_name }
    end

    def extract_duration(content)
      # Try various duration formats
      patterns = [
        /(\d+(?:\.\d+)?)\s*s(?:econds?)?\s*$/m,
        /finished in\s*(\d+(?:\.\d+)?)\s*s/i,
        /duration:\s*(\d+(?:\.\d+)?)\s*s/i,
        /(\d+(?:\.\d+)?)\s*seconds?\s*total/i
      ]

      patterns.each do |pattern|
        if (match = content.match(pattern))
          return match[1].to_f
        end
      end

      nil
    end

    def calculate_trend(pass_rates)
      return :stable if pass_rates.size < 3

      recent = pass_rates.take(pass_rates.size / 2)
      older = pass_rates.drop(pass_rates.size / 2)

      recent_avg = recent.sum / recent.size
      older_avg = older.sum / older.size

      diff = recent_avg - older_avg

      if diff > 5
        :improving
      elsif diff < -5
        :degrading
      else
        :stable
      end
    end
  end
end
