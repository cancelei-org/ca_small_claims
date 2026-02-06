# frozen_string_literal: true

# E2E Testing Tasks for Burner Instances
# Runs Playwright tests against isolated Docker burner instances
#
# Usage:
#   bin/rails burner:e2e[ca1]              # Run all E2E tests on ca1
#   bin/rails burner:e2e[ca1,mobile]       # Run mobile E2E tests on ca1
#   bin/rails burner:e2e_smoke[ca1]        # Quick smoke test
#   bin/rails burner:e2e_analyze[ca1]      # Analyze test logs

namespace :burner do
  namespace :e2e do
    E2E_LOG_DIR = Rails.root.join("tmp", "burner_e2e_logs")

    desc "Run E2E tests against a burner instance"
    task :run, [ :instance, :suite ] => :environment do |_t, args|
      instance = validate_instance(args[:instance])
      suite = args[:suite] || "all"

      ensure_instance_running(instance)

      base_url = "http://localhost:#{port_for(instance)}"
      log_file = E2E_LOG_DIR.join("#{instance}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.log")
      FileUtils.mkdir_p(E2E_LOG_DIR)

      puts "Running E2E tests on #{instance} (#{base_url})..."
      puts "Suite: #{suite}"
      puts "Logging to: #{log_file}"
      puts "-" * 60

      test_command = build_test_command(suite, base_url)

      success = system(
        { "BASE_URL" => base_url, "BURNER_INSTANCE" => instance },
        "#{test_command} 2>&1 | tee #{log_file}"
      )

      analyze_results(log_file)

      exit(success ? 0 : 1)
    end

    desc "Run smoke tests against a burner instance"
    task :smoke, [ :instance ] => :environment do |_t, args|
      instance = validate_instance(args[:instance])
      ensure_instance_running(instance)

      base_url = "http://localhost:#{port_for(instance)}"

      puts "Running smoke tests on #{instance}..."
      puts "-" * 60

      results = []

      # Test 1: Health check
      results << run_smoke_test("Health Check") do
        response = `curl -s -o /dev/null -w '%{http_code}' #{base_url}/up 2>/dev/null`.strip
        response == "200"
      end

      # Test 2: Home page loads
      results << run_smoke_test("Home Page") do
        response = `curl -s -o /dev/null -w '%{http_code}' #{base_url}/ 2>/dev/null`.strip
        response == "200"
      end

      # Test 3: Forms index accessible
      results << run_smoke_test("Forms Index") do
        response = `curl -s -o /dev/null -w '%{http_code}' #{base_url}/forms 2>/dev/null`.strip
        %w[200 302].include?(response)
      end

      # Test 4: Help page loads
      results << run_smoke_test("Help Page") do
        response = `curl -s -o /dev/null -w '%{http_code}' #{base_url}/help 2>/dev/null`.strip
        response == "200"
      end

      # Test 5: Assets served
      results << run_smoke_test("Assets Serving") do
        html = `curl -s #{base_url}/ 2>/dev/null`
        html.include?("stylesheet") || html.include?("javascript")
      end

      puts "-" * 60
      passed = results.count(true)
      total = results.size
      puts "Results: #{passed}/#{total} passed"

      exit(passed == total ? 0 : 1)
    end

    desc "Analyze E2E test logs for a burner instance"
    task :analyze, [ :instance ] => :environment do |_t, args|
      instance = validate_instance(args[:instance])

      log_files = Dir.glob(E2E_LOG_DIR.join("#{instance}_*.log")).sort.reverse
      if log_files.empty?
        puts "No log files found for #{instance}"
        exit 0
      end

      latest_log = log_files.first
      puts "Analyzing: #{latest_log}"
      puts "-" * 60

      analyze_results(latest_log, verbose: true)
    end

    desc "Run accessibility tests on burner instance"
    task :accessibility, [ :instance ] => :environment do |_t, args|
      instance = validate_instance(args[:instance])
      ensure_instance_running(instance)

      base_url = "http://localhost:#{port_for(instance)}"

      puts "Running accessibility tests on #{instance}..."

      success = system(
        { "BASE_URL" => base_url },
        "npx playwright test tests/e2e/accessibility/ --reporter=list"
      )

      exit(success ? 0 : 1)
    end

    desc "Run mobile tests on burner instance"
    task :mobile, [ :instance ] => :environment do |_t, args|
      instance = validate_instance(args[:instance])
      ensure_instance_running(instance)

      base_url = "http://localhost:#{port_for(instance)}"

      puts "Running mobile tests on #{instance}..."

      success = system(
        { "BASE_URL" => base_url },
        "npx playwright test tests/e2e/mobile/ --reporter=list"
      )

      exit(success ? 0 : 1)
    end

    desc "Run security tests on burner instance"
    task :security, [ :instance ] => :environment do |_t, args|
      instance = validate_instance(args[:instance])
      ensure_instance_running(instance)

      base_url = "http://localhost:#{port_for(instance)}"

      puts "Running security tests on #{instance}..."

      success = system(
        { "BASE_URL" => base_url },
        "npx playwright test tests/e2e/security/ --reporter=list"
      )

      exit(success ? 0 : 1)
    end

    desc "Generate E2E test report for burner instance"
    task :report, [ :instance ] => :environment do |_t, args|
      instance = validate_instance(args[:instance])

      log_files = Dir.glob(E2E_LOG_DIR.join("#{instance}_*.log")).sort.reverse.take(10)
      if log_files.empty?
        puts "No log files found for #{instance}"
        exit 0
      end

      report = {
        instance: instance,
        generated_at: Time.current.iso8601,
        runs: []
      }

      log_files.each do |log_file|
        run_data = parse_log_file(log_file)
        report[:runs] << run_data
      end

      output_file = Rails.root.join("tmp", "burner_e2e_reports", "#{instance}_report.json")
      FileUtils.mkdir_p(output_file.dirname)
      File.write(output_file, JSON.pretty_generate(report))

      puts "Report saved to: #{output_file}"
      puts "\nSummary:"
      puts "  Total runs: #{report[:runs].size}"

      if report[:runs].any?
        latest = report[:runs].first
        puts "  Latest run: #{latest[:timestamp]}"
        puts "  Passed: #{latest[:passed]}"
        puts "  Failed: #{latest[:failed]}"
        puts "  Skipped: #{latest[:skipped]}"
      end
    end

    desc "Clean old E2E logs"
    task :clean_logs, [ :days ] => :environment do |_t, args|
      days = (args[:days] || 7).to_i
      cutoff = Time.current - days.days

      old_files = Dir.glob(E2E_LOG_DIR.join("*.log")).select do |f|
        File.mtime(f) < cutoff
      end

      if old_files.empty?
        puts "No log files older than #{days} days"
      else
        old_files.each { |f| File.delete(f) }
        puts "Deleted #{old_files.size} old log files"
      end
    end

    private

    BURNER_INSTANCES = %w[ca1 ca2 ca3].freeze
    BURNER_PORTS = { "ca1" => 3011, "ca2" => 3012, "ca3" => 3013 }.freeze

    def validate_instance(instance)
      instance ||= "ca1"
      abort "Invalid instance: #{instance}. Valid: #{BURNER_INSTANCES.join(', ')}" unless BURNER_INSTANCES.include?(instance)
      instance
    end

    def port_for(instance)
      BURNER_PORTS[instance]
    end

    def ensure_instance_running(instance)
      status = `docker inspect --format='{{.State.Status}}' ca_burner_#{instance} 2>/dev/null`.strip
      abort "Burner instance #{instance} is not running. Start with: bin/rails burner:up[#{instance}]" if status != "running"
    end

    def build_test_command(suite, base_url)
      case suite
      when "all"
        "npx playwright test --reporter=list"
      when "mobile"
        "npx playwright test tests/e2e/mobile/ --reporter=list"
      when "accessibility"
        "npx playwright test tests/e2e/accessibility/ --reporter=list"
      when "security"
        "npx playwright test tests/e2e/security/ --reporter=list"
      else
        "npx playwright test #{suite} --reporter=list"
      end
    end

    def run_smoke_test(name)
      print "  #{name}... "
      result = yield
      puts result ? "✅ PASS" : "❌ FAIL"
      result
    rescue StandardError => e
      puts "❌ ERROR: #{e.message}"
      false
    end

    def analyze_results(log_file, verbose: false)
      return unless File.exist?(log_file)

      content = File.read(log_file)

      passed = content.scan(/\[PASS\]|\✓|passed/).size
      failed = content.scan(/\[FAIL\]|\✗|failed/).size
      skipped = content.scan(/\[SKIP\]|skipped/).size

      puts "\n📊 Test Results:"
      puts "   ✅ Passed:  #{passed}"
      puts "   ❌ Failed:  #{failed}"
      puts "   ⏭️  Skipped: #{skipped}"

      return unless verbose && failed.positive?
        puts "\n❌ Failed Tests:"
        content.scan(/(?:FAIL|failed|✗)\s*(.+)/).flatten.each do |failure|
          puts "   • #{failure.strip}"
        end
    end

    def parse_log_file(log_file)
      content = File.read(log_file)
      filename = File.basename(log_file)
      timestamp = filename.match(/(\d{8}_\d{6})/)&.captures&.first

      {
        file: filename,
        timestamp: timestamp ? Time.strptime(timestamp, "%Y%m%d_%H%M%S").iso8601 : nil,
        passed: content.scan(/\[PASS\]|\✓|passed/).size,
        failed: content.scan(/\[FAIL\]|\✗|failed/).size,
        skipped: content.scan(/\[SKIP\]|skipped/).size,
        duration: extract_duration(content)
      }
    end

    def extract_duration(content)
      match = content.match(/(\d+(?:\.\d+)?)\s*(?:seconds?|s)\s*(?:total)?/i)
      match ? match[1].to_f : nil
    end
  end

  # Alias for convenience
  desc "Run E2E tests against a burner instance"
  task :e2e, [ :instance, :suite ] => "burner:e2e:run"

  desc "Run smoke tests against a burner instance"
  task :e2e_smoke, [ :instance ] => "burner:e2e:smoke"

  desc "Analyze E2E test logs"
  task :e2e_analyze, [ :instance ] => "burner:e2e:analyze"
end
