# frozen_string_literal: true

# Semantic search service for court forms using flukebase_connect vector search.
#
# Provides natural language search capabilities for finding relevant court forms
# based on semantic similarity rather than just keyword matching.
#
# IMPL-CASC-FBC-002 / EUREKA-CASC-FBC-002
#
# Usage:
#   searcher = Search::FormSemanticSearch.new
#   results = searcher.search("How do I sue someone for unpaid rent?")
#   results = searcher.find_similar("SC-100")
#
# Prerequisites:
# - Python 3.11+ with flukebase_connect installed
# - OPENAI_API_KEY for embeddings (or local embedding model)
# - Index built with `index_build` command
#
module Search
  class FormSemanticSearch
    # Search result container
    SearchResult = Struct.new(:form, :score, :rank, :match_type, keyword_init: true)

    # Configuration
    DEFAULT_LIMIT = 10
    MIN_SCORE = 0.5
    PYTHON_PATH = "/home/cancelei/Projects/flukebase_connect"
    INDEX_SCOPE = "ca_small_claims"

    attr_reader :scope, :provider

    def initialize(scope: INDEX_SCOPE, provider: "auto")
      @scope = scope
      @provider = provider
      @python_available = check_python_available
    end

    # Search for forms matching a natural language query
    #
    # @param query [String] Natural language search query
    # @param limit [Integer] Maximum results to return
    # @param min_score [Float] Minimum similarity score (0.0-1.0)
    # @return [Array<SearchResult>] Matching forms with scores
    def search(query, limit: DEFAULT_LIMIT, min_score: MIN_SCORE)
      return fallback_search(query, limit) unless @python_available

      results = execute_semantic_search(query, limit, min_score)

      # Map results to FormDefinition records
      results.map do |result|
        form = find_form(result[:id])
        next unless form

        SearchResult.new(
          form: form,
          score: result[:score],
          rank: result[:rank],
          match_type: :semantic
        )
      end.compact
    end

    # Find forms similar to a given form
    #
    # @param form_code [String] Form code (e.g., "SC-100")
    # @param limit [Integer] Maximum results to return
    # @return [Array<SearchResult>] Similar forms with scores
    def find_similar(form_code, limit: DEFAULT_LIMIT)
      form = FormDefinition.find_by(code: form_code)
      return [] unless form

      # Use form content for similarity search
      content = build_form_content(form)
      search(content, limit: limit + 1, min_score: 0.3).reject { |r| r.form.code == form_code }.first(limit)
    end

    # Search for forms by category using semantic understanding
    #
    # @param category_description [String] Natural language category description
    # @param limit [Integer] Maximum results to return
    # @return [Array<SearchResult>] Matching forms
    def search_by_category(category_description, limit: DEFAULT_LIMIT)
      search("#{category_description} court forms", limit: limit)
    end

    # Build or update the semantic index for all forms
    #
    # @param incremental [Boolean] Only index changed forms
    # @return [Hash] Indexing statistics
    def build_index(incremental: true)
      return { error: "Python not available" } unless @python_available

      forms = FormDefinition.active
      indexed = 0
      errors = []

      forms.find_each do |form|
        result = index_form(form, incremental: incremental)
        if result[:success]
          indexed += 1
        else
          errors << { form_code: form.code, error: result[:error] }
        end
      end

      {
        total_forms: forms.count,
        indexed: indexed,
        errors: errors,
        scope: @scope
      }
    end

    # Index a single form
    #
    # @param form [FormDefinition] Form to index
    # @param incremental [Boolean] Skip if already indexed with same content
    # @return [Hash] Indexing result
    def index_form(form, incremental: true)
      content = build_form_content(form)
      content_hash = Digest::SHA256.hexdigest(content)[0..15]

      # Skip if content hasn't changed
      return { success: true, skipped: true } if incremental && !needs_update?(form.code, content_hash)

      result = execute_index_memory(
        memory_id: form.code,
        content: content,
        memory_type: "fact",
        metadata: {
          form_code: form.code,
          title: form.title,
          category: form.category&.name,
          content_hash: content_hash
        }
      )

      result
    end

    # Get index statistics
    #
    # @return [Hash] Index statistics
    def index_status
      return { error: "Python not available" } unless @python_available

      execute_index_status
    end

    # Check if Python/flukebase_connect is available
    #
    # @return [Boolean]
    def available?
      @python_available
    end

    private

    def check_python_available
      system('python3 -c "from flukebase_connect.indexing import IndexStore" > /dev/null 2>&1')
    end

    def execute_semantic_search(query, limit, min_score)
      escaped_query = query.gsub("'", "\\\\'").tr("\n", " ")

      result = `python3 << 'PYTHON'
import sys
import json
sys.path.insert(0, '#{PYTHON_PATH}')

try:
    from flukebase_connect.indexing.index_tools import index_search

    # Simulate tool call
    import asyncio

    async def do_search():
        # Use the index_search function pattern
        from flukebase_connect.indexing import IndexStore, get_embedding_engine

        store = IndexStore(scope='#{@scope}')
        engine = get_embedding_engine(provider='#{@provider}')

        query_embedding = await engine.embed('#{escaped_query}')
        results = store.search(
            query_embedding=query_embedding,
            limit=#{limit},
            min_score=#{min_score}
        )

        return [
            {
                'id': r.entry.id,
                'score': r.score,
                'rank': r.rank,
                'content': r.entry.content[:200]
            }
            for r in results
        ]

    results = asyncio.run(do_search())
    print(json.dumps({'success': True, 'results': results}))

except Exception as e:
    print(json.dumps({'success': False, 'error': str(e)}))
PYTHON`

      begin
        parsed = JSON.parse(result.strip)
        return [] unless parsed["success"]

        parsed["results"].map do |r|
          { id: r["id"], score: r["score"], rank: r["rank"] }
        end
      rescue JSON::ParserError
        []
      end
    end

    def execute_index_memory(memory_id:, content:, memory_type:, metadata:)
      escaped_content = content.gsub("'", "\\\\'").tr("\n", " ")
      metadata_json = metadata.to_json.gsub("'", "\\\\'")

      result = `python3 << 'PYTHON'
import sys
import json
sys.path.insert(0, '#{PYTHON_PATH}')

try:
    import asyncio
    from flukebase_connect.indexing import IndexStore, IndexEntry, get_embedding_engine

    async def do_index():
        store = IndexStore(scope='#{@scope}')
        engine = get_embedding_engine(provider='#{@provider}')

        content = '''#{escaped_content}'''
        embedding = await engine.embed(content)

        entry = IndexEntry(
            id='#{memory_id}',
            content=content,
            embedding=embedding,
            entry_type='#{memory_type}',
            metadata=json.loads('#{metadata_json}')
        )

        store.add(entry)
        return True

    result = asyncio.run(do_index())
    print(json.dumps({'success': True}))

except Exception as e:
    print(json.dumps({'success': False, 'error': str(e)}))
PYTHON`

      begin
        JSON.parse(result.strip).symbolize_keys
      rescue JSON::ParserError
        { success: false, error: "JSON parse error: #{result}" }
      end
    end

    def execute_index_status
      result = `python3 << 'PYTHON'
import sys
import json
sys.path.insert(0, '#{PYTHON_PATH}')

try:
    from flukebase_connect.indexing import IndexStore

    store = IndexStore(scope='#{@scope}')
    stats = store.stats()
    print(json.dumps({'success': True, 'stats': stats}))

except Exception as e:
    print(json.dumps({'success': False, 'error': str(e)}))
PYTHON`

      begin
        parsed = JSON.parse(result.strip)
        return { error: parsed["error"] } unless parsed["success"]

        parsed["stats"].symbolize_keys
      rescue JSON::ParserError
        { error: "JSON parse error" }
      end
    end

    def needs_update?(form_code, content_hash)
      # Check via Python if the content has changed
      result = `python3 << 'PYTHON'
import sys
import json
sys.path.insert(0, '#{PYTHON_PATH}')

try:
    from flukebase_connect.indexing import IndexStore

    store = IndexStore(scope='#{@scope}')
    needs = store.needs_update('#{form_code}', '#{content_hash}')
    print(json.dumps({'needs_update': needs}))

except Exception as e:
    print(json.dumps({'needs_update': True}))
PYTHON`

      begin
        JSON.parse(result.strip)["needs_update"]
      rescue JSON::ParserError
        true
      end
    end

    def build_form_content(form)
      parts = [
        "Form: #{form.code}",
        "Title: #{form.title}",
        form.description.presence,
        "Category: #{form.category&.name}".presence,
        form.field_definitions.pluck(:label).compact.join(", ").presence
      ].compact

      parts.join("\n")
    end

    def find_form(form_code)
      FormDefinition.find_by(code: form_code)
    end

    # Fallback to database text search when semantic search unavailable
    def fallback_search(query, limit)
      forms = FormDefinition.active.search(query).limit(limit)

      forms.each_with_index.map do |form, idx|
        SearchResult.new(
          form: form,
          score: 1.0 - (idx * 0.1), # Decreasing score for ranking
          rank: idx + 1,
          match_type: :keyword
        )
      end
    end
  end
end
