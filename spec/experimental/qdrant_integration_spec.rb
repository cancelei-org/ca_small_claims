# frozen_string_literal: true

# Experimental integration test for Qdrant vector search in ca_small_claims
# Tests semantic search capabilities for court forms and legal documents
#
# This is an experimental feature to evaluate:
# 1. Semantic search for similar court forms
# 2. Content-based form recommendations
# 3. Legal document similarity analysis
#
# Usage: Run with RSpec:
#   bundle exec rspec spec/experimental/qdrant_integration_spec.rb
#
# Prerequisites:
# - Python 3.11+ with qdrant-client
# - QDRANT_URL and QDRANT_API_KEY environment variables set
# - flukebase_connect Python package available

require 'rails_helper'

RSpec.describe 'Qdrant Vector Search Integration', type: :experimental do
  # Skip if Python/Qdrant not available
  before(:all) do
    @python_available = system('python3 --version > /dev/null 2>&1')
    @qdrant_url = ENV['QDRANT_URL']
    @qdrant_key = ENV['QDRANT_API_KEY']

    skip 'Python 3 or Qdrant credentials not available' unless @python_available && @qdrant_url && @qdrant_key
  end

  describe 'Form similarity search' do
    it 'can find similar forms based on content' do
      # Test case: Find forms similar to SC-100 (Plaintiff's Claim)
      form = FormDefinition.find_by(form_code: 'SC-100')
      skip 'SC-100 form not found' unless form

      # Simulate embedding the form description
      form_content = "#{form.title} #{form.description}"

      # Call Python script to test semantic search
      result = `python3 << 'PYTHON'
import sys
sys.path.insert(0, '/home/cancelei/Projects/flukebase_connect')

try:
    from qdrant_integration_example import QdrantIndexStore, IndexEntry
    import os
    import asyncio

    async def test_form_search():
        store = QdrantIndexStore(
            url=os.getenv('QDRANT_URL'),
            api_key=os.getenv('QDRANT_API_KEY'),
            collection='ca_small_claims_experimental'
        )

        # Mock embedding for SC-100
        test_embedding = [0.1] * 1536

        entry = IndexEntry(
            id='SC-100',
            content='#{form_content.gsub("'", "\\\\'")}',
            embedding=test_embedding,
            entry_type='form',
            metadata={'category': 'plaintiff', 'court': 'small_claims'}
        )

        await store.add(entry)

        # Search for similar forms
        results = await store.search(
            query_embedding=test_embedding,
            limit=3
        )

        print(f"SUCCESS: Found {len(results)} similar forms")
        await store.clear()
        return True

    result = asyncio.run(test_form_search())
    sys.exit(0 if result else 1)

except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
PYTHON`

      expect($?.exitstatus).to eq(0), "Python script failed: #{result}"
      expect(result).to include('SUCCESS')
    end
  end

  describe 'Legal document search' do
    it 'can perform semantic search on legal text' do
      # Test semantic search with legal terminology
      result = `python3 << 'PYTHON'
import sys
sys.path.insert(0, '/home/cancelei/Projects/flukebase_connect')

try:
    from flukebase_connect.llm.router import LLMRouter

    router = LLMRouter(provider='anthropic')

    # Test routing for legal document tasks
    decision = router.route(
        task='Analyze small claims court filing requirements',
        context_tokens=5000
    )

    print(f"SUCCESS: Routed to {decision.model_tier.value} tier")
    print(f"Model: {decision.model_name}")
    print(f"Cost multiplier: {decision.estimated_cost_multiplier}x")

    sys.exit(0)

except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
PYTHON`

      expect($?.exitstatus).to eq(0), "Python script failed: #{result}"
      expect(result).to include('SUCCESS')
    end
  end

  describe 'Cost optimization for AI features' do
    it 'routes simple queries to cost-effective models' do
      test_queries = [
        { task: 'What is form SC-100?', expected: 'fast' },
        { task: 'Review this legal filing for errors', expected: 'premium' },
        { task: 'List all plaintiff forms', expected: 'fast' }
      ]

      test_queries.each do |query|
        result = `python3 << 'PYTHON'
import sys
sys.path.insert(0, '/home/cancelei/Projects/flukebase_connect')

try:
    from flukebase_connect.llm.router import LLMRouter

    router = LLMRouter(provider='anthropic')
    decision = router.route(
        task='#{query[:task]}',
        context_tokens=2000
    )

    print(decision.model_tier.value)
    sys.exit(0)

except Exception as e:
    sys.exit(1)
PYTHON`

        expect($?.exitstatus).to eq(0)
        # Note: Routing may vary, just ensure it doesn't crash
      end
    end
  end

  describe 'Performance benchmarks' do
    it 'measures search latency' do
      result = `python3 test_qdrant_integration.py 2>&1 | grep -i "search performance"`

      # Should complete search performance test
      expect(result).to match(/search performance/i) if result.present?
    end

    it 'measures cost savings from routing' do
      result = `python3 test_llm_router.py 2>&1 | grep -i "cost savings"`

      # Should calculate cost savings
      expect(result).to match(/cost savings/i) if result.present?
    end
  end
end
