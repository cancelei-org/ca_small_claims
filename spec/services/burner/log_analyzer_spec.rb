# frozen_string_literal: true

require "rails_helper"

RSpec.describe Burner::LogAnalyzer do
  let(:analyzer) { described_class.new("ca1") }
  let(:log_dir) { described_class::LOG_DIR }

  describe Burner::LogAnalyzer::TestRun do
    let(:test_run) do
      described_class.new(
        instance: "ca1",
        timestamp: Time.now,
        passed: 10,
        failed: 2,
        skipped: 1,
        duration: 45.5,
        failures: [],
        file: "ca1_20260113_120000.log"
      )
    end

    describe "#success?" do
      it "returns true when failed is zero" do
        test_run.failed = 0
        expect(test_run.success?).to be true
      end

      it "returns false when failed is non-zero" do
        test_run.failed = 2
        expect(test_run.success?).to be false
      end
    end

    describe "#pass_rate" do
      it "calculates pass rate percentage" do
        expect(test_run.pass_rate).to eq(83.33)
      end

      it "returns 0.0 when no tests ran" do
        test_run.passed = 0
        test_run.failed = 0
        expect(test_run.pass_rate).to eq(0.0)
      end

      it "returns 100.0 when all tests pass" do
        test_run.passed = 10
        test_run.failed = 0
        expect(test_run.pass_rate).to eq(100.0)
      end
    end
  end

  describe "#initialize" do
    it "accepts an instance name" do
      analyzer = described_class.new("ca2")
      expect(analyzer.instance_variable_get(:@instance)).to eq("ca2")
    end

    it "allows nil instance" do
      analyzer = described_class.new
      expect(analyzer.instance_variable_get(:@instance)).to be_nil
    end
  end

  describe "#latest" do
    context "when no log files exist" do
      before do
        allow(analyzer).to receive(:logs_for).and_return([])
      end

      it "returns nil" do
        expect(analyzer.latest).to be_nil
      end
    end

    context "when log files exist" do
      # Use log format that doesn't double-match (checkmark only, no 'passed' word)
      let(:log_content) do
        <<~LOG
          Running E2E tests on ca1
          ✓ Test 1
          ✓ Test 2
          ✗ Test 3
          Duration: 30.5 seconds total
        LOG
      end

      before do
        allow(analyzer).to receive(:logs_for).and_return([ "/tmp/ca1_20260113_120000.log" ])
        allow(File).to receive(:read).and_return(log_content)
        allow(File).to receive(:basename).and_return("ca1_20260113_120000.log")
      end

      it "returns a TestRun" do
        result = analyzer.latest
        expect(result).to be_a(Burner::LogAnalyzer::TestRun)
      end

      it "parses passed count" do
        result = analyzer.latest
        expect(result.passed).to eq(2)
      end

      it "parses failed count" do
        result = analyzer.latest
        expect(result.failed).to eq(1)
      end

      it "extracts duration" do
        result = analyzer.latest
        expect(result.duration).to eq(30.5)
      end
    end
  end

  describe "#all_runs" do
    before do
      allow(analyzer).to receive(:logs_for).and_return([])
    end

    it "returns an array" do
      expect(analyzer.all_runs).to be_an(Array)
    end

    it "respects the limit parameter" do
      log_files = Array.new(20) { |i| "/tmp/ca1_#{i}.log" }
      allow(analyzer).to receive(:logs_for).and_return(log_files)
      allow(File).to receive(:read).and_return("✓ Test passed")
      allow(File).to receive(:basename).and_return("ca1_test.log")

      results = analyzer.all_runs("ca1", limit: 5)
      expect(results.size).to eq(5)
    end
  end

  describe "#trend_analysis" do
    context "when no test runs exist" do
      before do
        allow(analyzer).to receive(:all_runs).and_return([])
      end

      it "returns nil" do
        expect(analyzer.trend_analysis).to be_nil
      end
    end

    context "with test runs" do
      let(:test_runs) do
        [
          Burner::LogAnalyzer::TestRun.new(passed: 10, failed: 0, duration: 30.0, failures: []),
          Burner::LogAnalyzer::TestRun.new(passed: 9, failed: 1, duration: 32.0, failures: []),
          Burner::LogAnalyzer::TestRun.new(passed: 8, failed: 2, duration: 28.0, failures: [])
        ]
      end

      before do
        allow(analyzer).to receive(:all_runs).and_return(test_runs)
      end

      it "returns a TrendReport" do
        result = analyzer.trend_analysis
        expect(result).to be_a(Burner::LogAnalyzer::TrendReport)
      end

      it "calculates average pass rate" do
        result = analyzer.trend_analysis
        # (100 + 90 + 80) / 3 = 90
        expect(result.avg_pass_rate).to eq(90.0)
      end

      it "calculates average duration" do
        result = analyzer.trend_analysis
        # (30 + 32 + 28) / 3 = 30
        expect(result.avg_duration).to eq(30.0)
      end

      it "identifies common failures" do
        failures = [
          Burner::LogAnalyzer::FailureDetail.new(test_name: "Test A"),
          Burner::LogAnalyzer::FailureDetail.new(test_name: "Test A"),
          Burner::LogAnalyzer::FailureDetail.new(test_name: "Test B")
        ]
        test_runs.each { |r| r.failures = failures }

        result = analyzer.trend_analysis
        expect(result.common_failures).to be_an(Array)
      end
    end
  end

  describe "#compare_instances" do
    context "when both instances have runs" do
      let(:run1) { Burner::LogAnalyzer::TestRun.new(passed: 10, failed: 0, duration: 30.0, failures: []) }
      let(:run2) { Burner::LogAnalyzer::TestRun.new(passed: 8, failed: 2, duration: 35.0, failures: []) }

      before do
        allow(analyzer).to receive(:latest).with("ca1").and_return(run1)
        allow(analyzer).to receive(:latest).with("ca2").and_return(run2)
      end

      it "returns comparison hash" do
        result = analyzer.compare_instances("ca1", "ca2")
        expect(result).to have_key(:instance1)
        expect(result).to have_key(:instance2)
        expect(result).to have_key(:comparison)
      end

      it "calculates pass rate difference" do
        result = analyzer.compare_instances("ca1", "ca2")
        # 100 - 80 = 20
        expect(result[:comparison][:pass_rate_diff]).to eq(20.0)
      end

      it "calculates duration difference" do
        result = analyzer.compare_instances("ca1", "ca2")
        # 30 - 35 = -5
        expect(result[:comparison][:duration_diff]).to eq(-5.0)
      end
    end

    context "when an instance has no runs" do
      before do
        allow(analyzer).to receive(:latest).with("ca1").and_return(nil)
        allow(analyzer).to receive(:latest).with("ca2").and_return(nil)
      end

      it "returns nil" do
        expect(analyzer.compare_instances("ca1", "ca2")).to be_nil
      end
    end
  end

  describe "#summary_report" do
    before do
      allow(analyzer).to receive(:latest).and_return(nil)
    end

    it "returns a hash" do
      expect(analyzer.summary_report).to be_a(Hash)
    end

    context "with test runs for some instances" do
      let(:run) { Burner::LogAnalyzer::TestRun.new(passed: 10, failed: 0, timestamp: Time.now, failures: []) }

      before do
        allow(analyzer).to receive(:latest).with("ca1").and_return(run)
        allow(analyzer).to receive(:latest).with("ca2").and_return(nil)
        allow(analyzer).to receive(:latest).with("ca3").and_return(nil)
      end

      it "includes only instances with runs" do
        result = analyzer.summary_report
        expect(result).to have_key("ca1")
        expect(result).not_to have_key("ca2")
      end
    end
  end

  describe "private methods" do
    describe "#extract_timestamp" do
      it "extracts timestamp from filename" do
        timestamp = analyzer.send(:extract_timestamp, "ca1_20260113_120000.log")
        expect(timestamp).to be_a(Time)
        expect(timestamp.year).to eq(2026)
        expect(timestamp.month).to eq(1)
        expect(timestamp.day).to eq(13)
      end

      it "returns nil for invalid filename" do
        timestamp = analyzer.send(:extract_timestamp, "invalid.log")
        expect(timestamp).to be_nil
      end
    end

    describe "#count_patterns" do
      it "counts PASS patterns" do
        content = "[PASS] Test 1\n[PASS] Test 2\n[FAIL] Test 3"
        count = analyzer.send(:count_patterns, content, /\[PASS\]/)
        expect(count).to eq(2)
      end

      it "counts checkmark patterns" do
        content = "✓ Test 1\n✓ Test 2\n✗ Test 3"
        count = analyzer.send(:count_patterns, content, /✓/)
        expect(count).to eq(2)
      end
    end

    describe "#extract_duration" do
      it "extracts seconds format" do
        content = "Finished in 45.5 seconds total"
        duration = analyzer.send(:extract_duration, content)
        expect(duration).to eq(45.5)
      end

      it "extracts s abbreviation format" do
        content = "Duration: 30.25s"
        duration = analyzer.send(:extract_duration, content)
        expect(duration).to eq(30.25)
      end

      it "returns nil when no duration found" do
        content = "No duration info here"
        duration = analyzer.send(:extract_duration, content)
        expect(duration).to be_nil
      end
    end

    describe "#calculate_trend" do
      it "returns stable for less than 3 runs" do
        trend = analyzer.send(:calculate_trend, [ 100.0, 90.0 ])
        expect(trend).to eq(:stable)
      end

      it "returns improving when recent rates are higher" do
        trend = analyzer.send(:calculate_trend, [ 100.0, 95.0, 90.0, 70.0, 60.0, 50.0 ])
        expect(trend).to eq(:improving)
      end

      it "returns degrading when recent rates are lower" do
        trend = analyzer.send(:calculate_trend, [ 50.0, 60.0, 70.0, 90.0, 95.0, 100.0 ])
        expect(trend).to eq(:degrading)
      end

      it "returns stable when difference is within threshold" do
        trend = analyzer.send(:calculate_trend, [ 90.0, 91.0, 89.0, 90.0 ])
        expect(trend).to eq(:stable)
      end
    end

    describe "#extract_failures" do
      it "extracts Playwright format failures" do
        content = "✘ [chromium] › tests/e2e/form.spec.js:42:5 › Form fills correctly"
        failures = analyzer.send(:extract_failures, content)
        expect(failures.first.test_name).to eq("Form fills correctly")
        expect(failures.first.file).to eq("tests/e2e/form.spec.js")
        expect(failures.first.line).to eq(42)
      end

      it "extracts Jest format failures" do
        content = "✕ should validate required fields"
        failures = analyzer.send(:extract_failures, content)
        expect(failures.first.test_name).to eq("should validate required fields")
      end

      it "deduplicates failures by test name" do
        content = "✕ Test A\n✕ Test A"
        failures = analyzer.send(:extract_failures, content)
        expect(failures.size).to eq(1)
      end
    end
  end
end
