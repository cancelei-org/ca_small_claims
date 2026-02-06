# frozen_string_literal: true

# Experimental integration test for LLM Router in ca_small_claims
# Tests tiered routing for AI-powered legal services
#
# This validates the flukebase_connect LLM Router integration for:
# 1. FormAnalyzer - Analyze court form content and requirements
# 2. LegalTermExplainer - Explain legal terminology in plain language
# 3. DocumentSummarizer - Summarize legal documents and filings
#
# Usage: Run with RSpec:
#   bundle exec rspec spec/experimental/llm_router_integration_spec.rb
#
# Prerequisites:
# - Python 3.11+ with flukebase_connect
# - ANTHROPIC_API_KEY environment variable set (for live tests)
#
# EUREKA-CASC-FBC-001 / IMPL-CASC-FBC-001

require 'rails_helper'

RSpec.describe 'LLM Router Integration', type: :experimental do
  # Skip if Python/flukebase_connect not available
  before(:all) do
    @python_available = system('python3 --version > /dev/null 2>&1')
    @flukebase_available = system('python3 -c "from flukebase_connect.llm.router import LLMRouter" > /dev/null 2>&1')

    skip 'Python 3 or flukebase_connect not available' unless @python_available && @flukebase_available
  end

  # Cost tracking for test analysis
  let(:cost_tracker) { [] }

  describe 'FormAnalyzer routing' do
    context 'simple form lookups' do
      it 'routes to FAST tier for basic form info queries' do
        result = route_task(
          task: 'What is the purpose of form SC-100?',
          context_tokens: 500,
          expected_tier: 'fast'
        )

        expect(result[:success]).to be true
        expect(result[:tier]).to eq('fast')
        expect(result[:cost_multiplier]).to be <= 1.0
      end

      it 'routes to FAST tier for field listing' do
        result = route_task(
          task: 'List the required fields on form SC-100',
          context_tokens: 800,
          expected_tier: 'fast'
        )

        expect(result[:success]).to be true
        expect(result[:tier]).to eq('fast')
      end
    end

    context 'complex form analysis' do
      it 'routes to BALANCED tier for form comparison' do
        result = route_task(
          task: 'Compare the requirements of SC-100 and SC-103 forms for a plaintiff',
          context_tokens: 2000,
          expected_tier: 'balanced'
        )

        expect(result[:success]).to be true
        expect([ 'balanced', 'premium' ]).to include(result[:tier])
      end

      it 'routes to PREMIUM tier for legal validity analysis' do
        result = route_task(
          task: 'Analyze this court filing for legal validity, missing required elements, and potential procedural issues that could lead to dismissal',
          context_tokens: 8000,
          expected_tier: 'premium'
        )

        expect(result[:success]).to be true
        expect(result[:tier]).to eq('premium')
        expect(result[:cost_multiplier]).to be >= 3.0
      end
    end
  end

  describe 'LegalTermExplainer routing' do
    context 'simple term definitions' do
      it 'routes to FAST tier for single term lookup' do
        result = route_task(
          task: 'Define the term "plaintiff" in simple language',
          context_tokens: 200,
          expected_tier: 'fast'
        )

        expect(result[:success]).to be true
        expect(result[:tier]).to eq('fast')
      end

      it 'routes to FAST tier for common legal term' do
        result = route_task(
          task: 'What does "small claims court" mean?',
          context_tokens: 300,
          expected_tier: 'fast'
        )

        expect(result[:success]).to be true
        expect(result[:tier]).to eq('fast')
      end
    end

    context 'complex legal explanations' do
      it 'routes to BALANCED tier for procedural explanations' do
        result = route_task(
          task: 'Explain the service of process requirements in California small claims court and the consequences of improper service',
          context_tokens: 1500,
          expected_tier: 'balanced'
        )

        expect(result[:success]).to be true
        expect([ 'balanced', 'premium' ]).to include(result[:tier])
      end

      it 'routes to PREMIUM tier for jurisdiction analysis' do
        result = route_task(
          task: 'Analyze whether this case falls under California small claims court jurisdiction considering venue, monetary limits, and subject matter restrictions',
          context_tokens: 5000,
          expected_tier: 'premium'
        )

        expect(result[:success]).to be true
        expect(result[:tier]).to eq('premium')
      end
    end
  end

  describe 'DocumentSummarizer routing' do
    context 'short document summaries' do
      it 'routes to FAST tier for brief summaries' do
        result = route_task(
          task: 'Summarize this 1-page demand letter in 2 sentences',
          context_tokens: 1000,
          expected_tier: 'fast'
        )

        expect(result[:success]).to be true
        expect([ 'fast', 'balanced' ]).to include(result[:tier])
      end
    end

    context 'comprehensive document analysis' do
      it 'routes to BALANCED tier for multi-page summary' do
        result = route_task(
          task: 'Summarize this 10-page contract dispute documentation including key dates, amounts, and parties involved',
          context_tokens: 15_000,
          expected_tier: 'balanced'
        )

        expect(result[:success]).to be true
        expect([ 'balanced', 'premium' ]).to include(result[:tier])
      end

      it 'routes to PREMIUM tier for legal document review' do
        result = route_task(
          task: 'Review and summarize this complete case file including all exhibits, identify strengths and weaknesses of the claim, and recommend next steps',
          context_tokens: 50_000,
          expected_tier: 'premium'
        )

        expect(result[:success]).to be true
        expect(result[:tier]).to eq('premium')
      end
    end
  end

  describe 'Cost optimization measurements' do
    it 'measures cost per request type' do
      request_types = {
        form_lookup: { task: 'What is SC-100?', tokens: 500 },
        term_definition: { task: 'Define plaintiff', tokens: 200 },
        brief_summary: { task: 'Summarize this letter', tokens: 1000 },
        form_comparison: { task: 'Compare SC-100 and SC-103', tokens: 3000 },
        legal_analysis: { task: 'Analyze jurisdiction and venue', tokens: 8000 },
        full_review: { task: 'Complete case review with recommendations', tokens: 50_000 }
      }

      costs = {}

      request_types.each do |type, config|
        result = route_task(
          task: config[:task],
          context_tokens: config[:tokens],
          expected_tier: nil # Don't assert, just measure
        )

        costs[type] = {
          tier: result[:tier],
          cost_multiplier: result[:cost_multiplier],
          estimated_cost_usd: calculate_estimated_cost(config[:tokens], result[:cost_multiplier])
        }
      end

      # Output cost analysis for review
      puts "\n--- Cost Analysis by Request Type ---"
      costs.each do |type, data|
        puts "#{type}: #{data[:tier]} tier, #{data[:cost_multiplier]}x multiplier, ~$#{data[:estimated_cost_usd].round(4)} per request"
      end

      # Verify cost optimization is working
      expect(costs[:form_lookup][:cost_multiplier]).to be < costs[:full_review][:cost_multiplier]
      expect(costs[:term_definition][:cost_multiplier]).to be <= costs[:legal_analysis][:cost_multiplier]
    end

    it 'calculates potential monthly cost savings' do
      # Simulate typical monthly usage pattern
      monthly_requests = {
        form_lookup: 5000,      # High volume, simple
        term_definition: 3000,  # Medium volume
        brief_summary: 1000,    # Medium volume
        form_comparison: 500,   # Lower volume
        legal_analysis: 200,    # Lower volume, complex
        full_review: 50         # Rare, expensive
      }

      # Calculate costs with routing vs all-premium
      routed_cost = 0.0
      premium_cost = 0.0

      monthly_requests.each do |type, count|
        result = route_task(
          task: request_type_to_task(type),
          context_tokens: request_type_to_tokens(type),
          expected_tier: nil
        )

        avg_tokens = request_type_to_tokens(type)
        routed_cost += count * calculate_estimated_cost(avg_tokens, result[:cost_multiplier])
        premium_cost += count * calculate_estimated_cost(avg_tokens, 5.0) # Premium baseline
      end

      savings = premium_cost - routed_cost
      savings_percentage = (savings / premium_cost) * 100

      puts "\n--- Monthly Cost Projection ---"
      puts "With LLM Router: $#{routed_cost.round(2)}"
      puts "All Premium: $#{premium_cost.round(2)}"
      puts "Savings: $#{savings.round(2)} (#{savings_percentage.round(1)}%)"

      # Expect meaningful savings
      expect(savings_percentage).to be > 30 # At least 30% savings expected
    end
  end

  describe 'Latency measurements' do
    it 'measures routing decision latency' do
      latencies = []

      10.times do
        start_time = Time.now
        route_task(
          task: 'Simple form lookup',
          context_tokens: 500,
          expected_tier: nil
        )
        latencies << (Time.now - start_time) * 1000 # Convert to ms
      end

      avg_latency = latencies.sum / latencies.size
      max_latency = latencies.max
      p95_latency = latencies.sort[8] # 95th percentile

      puts "\n--- Routing Latency ---"
      puts "Average: #{avg_latency.round(2)}ms"
      puts "Max: #{max_latency.round(2)}ms"
      puts "P95: #{p95_latency.round(2)}ms"

      # Routing should be fast (< 500ms as per PROD-CASC-FBC-001)
      expect(avg_latency).to be < 500
    end
  end

  describe 'Error handling' do
    it 'handles missing API key gracefully' do
      result = `python3 << 'PYTHON'
import sys
sys.path.insert(0, '/home/cancelei/Projects/flukebase_connect')
import os

# Temporarily unset API key
original_key = os.environ.get('ANTHROPIC_API_KEY', '')
os.environ['ANTHROPIC_API_KEY'] = ''

try:
    from flukebase_connect.llm.router import LLMRouter
    router = LLMRouter(provider='anthropic')

    # Routing should still work (doesn't need API key)
    decision = router.route(task='Test task', context_tokens=1000)
    print(f"SUCCESS: Routed to {decision.model_tier.value}")

except Exception as e:
    print(f"ERROR: {e}")

finally:
    os.environ['ANTHROPIC_API_KEY'] = original_key

sys.exit(0)
PYTHON`

      expect($?.exitstatus).to eq(0)
      expect(result).to include('SUCCESS')
    end

    it 'handles invalid context tokens' do
      result = `python3 << 'PYTHON'
import sys
sys.path.insert(0, '/home/cancelei/Projects/flukebase_connect')

try:
    from flukebase_connect.llm.router import LLMRouter
    router = LLMRouter(provider='anthropic')

    # Test with extreme values
    decision = router.route(task='Test', context_tokens=0)
    print(f"Zero tokens: {decision.model_tier.value}")

    decision = router.route(task='Test', context_tokens=1000000)
    print(f"Large tokens: {decision.model_tier.value}")

    print("SUCCESS")
    sys.exit(0)

except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
PYTHON`

      expect($?.exitstatus).to eq(0)
      expect(result).to include('SUCCESS')
    end
  end

  private

  def route_task(task:, context_tokens:, expected_tier:)
    result = `python3 << 'PYTHON'
import sys
import json
sys.path.insert(0, '/home/cancelei/Projects/flukebase_connect')

try:
    from flukebase_connect.llm.router import LLMRouter

    router = LLMRouter(provider='anthropic')
    decision = router.route(
        task='#{task.gsub("'", "\\\\'")}',
        context_tokens=#{context_tokens}
    )

    output = {
        'success': True,
        'tier': decision.model_tier.value,
        'model': decision.model_name,
        'cost_multiplier': decision.estimated_cost_multiplier,
        'reasoning': decision.reasoning
    }
    print(json.dumps(output))
    sys.exit(0)

except Exception as e:
    output = {'success': False, 'error': str(e)}
    print(json.dumps(output))
    sys.exit(1)
PYTHON`

    begin
      parsed = JSON.parse(result.strip)
      {
        success: parsed['success'],
        tier: parsed['tier'],
        model: parsed['model'],
        cost_multiplier: parsed['cost_multiplier'] || 1.0,
        reasoning: parsed['reasoning']
      }
    rescue JSON::ParserError
      { success: false, error: result }
    end
  end

  def calculate_estimated_cost(tokens, multiplier)
    # Base cost: ~$0.003 per 1K tokens (Claude 3 Haiku baseline)
    base_cost_per_1k = 0.003
    (tokens / 1000.0) * base_cost_per_1k * multiplier
  end

  def request_type_to_task(type)
    {
      form_lookup: 'What is SC-100?',
      term_definition: 'Define plaintiff',
      brief_summary: 'Summarize this letter',
      form_comparison: 'Compare SC-100 and SC-103 requirements',
      legal_analysis: 'Analyze jurisdiction and venue for this case',
      full_review: 'Complete case review with all exhibits and recommendations'
    }[type]
  end

  def request_type_to_tokens(type)
    {
      form_lookup: 500,
      term_definition: 200,
      brief_summary: 1000,
      form_comparison: 3000,
      legal_analysis: 8000,
      full_review: 50_000
    }[type]
  end
end
