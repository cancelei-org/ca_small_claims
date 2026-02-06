# frozen_string_literal: true

require "open3"

module Schema
  # Compares database schemas between different sources (local, burner instances)
  # and produces structured diff reports
  #
  # @example Compare local schema with burner instance
  #   comparator = Schema::Comparator.new
  #   diff = comparator.compare_local_with_burner("ca1")
  #
  # @example Compare two burner instances
  #   diff = comparator.compare_burners("ca1", "ca2")
  #
  class Comparator
    COMPOSE_FILE = "docker-compose.burner.yml"
    SCHEMA_DIR = Rails.root.join("tmp", "burner_schemas")

    Result = Struct.new(:source1, :source2, :identical, :added_tables, :removed_tables,
                        :modified_tables, :added_columns, :removed_columns,
                        :modified_columns, :added_indexes, :removed_indexes,
                        :summary, keyword_init: true) do
      def differences?
        !identical
      end

      def total_changes
        added_tables.size + removed_tables.size + modified_tables.size
      end
    end

    TableDiff = Struct.new(:table_name, :column_changes, :index_changes, keyword_init: true)
    ColumnChange = Struct.new(:column_name, :change_type, :old_value, :new_value, keyword_init: true)
    IndexChange = Struct.new(:index_name, :change_type, :old_definition, :new_definition, keyword_init: true)

    def initialize
      FileUtils.mkdir_p(SCHEMA_DIR)
    end

    # Compare local schema with a burner instance
    # @param burner_instance [String] the burner instance (ca1, ca2, ca3)
    # @return [Result] comparison result
    def compare_local_with_burner(burner_instance)
      local_schema = parse_local_schema
      burner_schema = parse_burner_schema(burner_instance)

      compare_schemas(
        local_schema,
        burner_schema,
        source1: "local",
        source2: burner_instance
      )
    end

    # Compare two burner instances
    # @param instance1 [String] first burner instance
    # @param instance2 [String] second burner instance
    # @return [Result] comparison result
    def compare_burners(instance1, instance2)
      schema1 = parse_burner_schema(instance1)
      schema2 = parse_burner_schema(instance2)

      compare_schemas(schema1, schema2, source1: instance1, source2: instance2)
    end

    # Dump schema from burner instance to file
    # @param instance [String] burner instance name
    # @return [String] path to dumped schema file
    def dump_burner_schema(instance)
      # Security: Validate instance name to prevent command injection
      # Only allow alphanumeric characters, underscores, and hyphens
      raise ArgumentError, "Invalid instance name: #{instance}" unless instance =~ /\A[a-zA-Z0-9\-_]+\z/

      output_file = SCHEMA_DIR.join("#{instance}_schema.rb")

      # Use Open3.capture3 with array form to avoid shell injection
      stdout, stderr, status = Open3.capture3(
        "docker-compose", "-f", COMPOSE_FILE,
        "exec", "-T", instance,
        "bin/rails", "runner", "puts File.read('db/schema.rb')"
      )

      raise "Failed to dump schema from #{instance}: #{stderr}" unless status.success? && stdout.present?

      File.write(output_file, stdout)
      output_file.to_s
    end

    # Generate human-readable diff report
    # @param result [Result] comparison result
    # @return [String] formatted report
    def format_report(result)
      lines = format_report_header(result)
      return lines.join("\n") if result.identical

      lines.concat(format_report_summary(result))
      lines.concat(format_added_tables_section(result))
      lines.concat(format_removed_tables_section(result))
      lines.concat(format_modified_tables_section(result))
      lines.join("\n")
    end

    def format_report_header(result)
      [
        "=" * 70,
        "Schema Comparison: #{result.source1} vs #{result.source2}",
        "=" * 70,
        "",
        (result.identical ? "✅ Schemas are identical!" : nil)
      ].compact
    end

    def format_report_summary(result)
      [ "📊 Summary: #{result.total_changes} table(s) with differences", "" ]
    end

    def format_added_tables_section(result)
      return [] unless result.added_tables.any?

      [
        "➕ Added Tables (in #{result.source2}, not in #{result.source1}):",
        *result.added_tables.map { |t| "   • #{t}" },
        ""
      ]
    end

    def format_removed_tables_section(result)
      return [] unless result.removed_tables.any?

      [
        "➖ Removed Tables (in #{result.source1}, not in #{result.source2}):",
        *result.removed_tables.map { |t| "   • #{t}" },
        ""
      ]
    end

    def format_modified_tables_section(result)
      return [] unless result.modified_tables.any?

      [
        "🔄 Modified Tables:",
        *result.modified_tables.flat_map { |table_diff| format_table_diff(table_diff) },
        ""
      ]
    end

    def format_table_diff(table_diff)
      [
        "   #{table_diff.table_name}:",
        *table_diff.column_changes.map { |change| format_column_change(change) },
        *table_diff.index_changes.map { |change| format_index_change(change) }
      ]
    end

    private

    def parse_local_schema
      schema_path = Rails.root.join("db", "schema.rb")
      parse_schema_file(schema_path)
    end

    def parse_burner_schema(instance)
      schema_file = dump_burner_schema(instance)
      parse_schema_file(schema_file)
    rescue StandardError => e
      Rails.logger.error("Failed to parse burner schema: #{e.message}")
      { tables: {}, version: nil }
    end

    def parse_schema_file(path)
      content = File.read(path)
      {
        version: extract_version(content),
        tables: extract_tables(content)
      }
    end

    def extract_version(content)
      match = content.match(/ActiveRecord::Schema\[\d+\.\d+\]\.define\(version: (\d+)\)/)
      match ? match[1].to_i : nil
    end

    def extract_tables(content)
      tables = {}

      # Match table definitions
      content.scan(/create_table\s+"([^"]+)"(?:,\s*([^do]+))?\s+do\s+\|t\|(.*?)end/m) do |name, options, body|
        tables[name] = {
          options: parse_table_options(options),
          columns: extract_columns(body),
          indexes: []
        }
      end

      # Match indexes defined outside create_table blocks
      content.scan(/add_index\s+"([^"]+)",\s*(.+)/) do |table_name, index_def|
        tables[table_name][:indexes] << parse_index_definition(index_def) if tables[table_name]
      end

      # Match indexes defined inside create_table blocks
      content.scan(/create_table\s+"([^"]+)".*?do\s+\|t\|.*?((?:t\.index.+?)+)/m) do |name, indexes_block|
        next unless tables[name]

        indexes_block.scan(/t\.index\s+(.+)/) do |index_def|
          tables[name][:indexes] << parse_index_definition(index_def.first)
        end
      end

      tables
    end

    def parse_table_options(options_str)
      return {} if options_str.blank?

      options = {}
      options[:force] = true if options_str.include?("force: :cascade")
      options[:id] = false if options_str.include?("id: false")

      # Extract primary key type
      if (match = options_str.match(/id:\s*:(\w+)/))
        options[:id] = match[1].to_sym
      end

      options
    end

    def extract_columns(body)
      columns = {}

      body.scan(/t\.(\w+)\s+"([^"]+)"(?:,\s*(.+))?$/) do |type, name, options|
        columns[name] = {
          type: type,
          options: parse_column_options(options)
        }
      end

      columns
    end

    def parse_column_options(options_str)
      return {} if options_str.blank?

      options = {}

      # Parse common options
      options[:null] = false if options_str.include?("null: false")
      options[:default] = extract_default(options_str)
      options[:limit] = extract_limit(options_str)
      options[:precision] = extract_precision(options_str)
      options[:scale] = extract_scale(options_str)

      options.compact
    end

    def extract_default(str)
      return nil unless str

      if (match = str.match(/default:\s*"([^"]*)"/))
        match[1]
      elsif (match = str.match(/default:\s*(\d+)/))
        match[1].to_i
      elsif str.include?("default: true")
        true
      elsif str.include?("default: false")
        false
      end
    end

    def extract_limit(str)
      return nil unless str

      if (match = str.match(/limit:\s*(\d+)/))
        match[1].to_i
      end
    end

    def extract_precision(str)
      return nil unless str

      if (match = str.match(/precision:\s*(\d+)/))
        match[1].to_i
      end
    end

    def extract_scale(str)
      return nil unless str

      if (match = str.match(/scale:\s*(\d+)/))
        match[1].to_i
      end
    end

    def parse_index_definition(def_str)
      {
        columns: extract_index_columns(def_str),
        options: extract_index_options(def_str)
      }
    end

    def extract_index_columns(str)
      if (match = str.match(/\[([^\]]+)\]/))
        match[1].scan(/"([^"]+)"/).flatten
      elsif (match = str.match(/"([^"]+)"/))
        [ match[1] ]
      else
        []
      end
    end

    def extract_index_options(str)
      options = {}
      options[:unique] = true if str.include?("unique: true")
      options[:name] = Regexp.last_match(1) if str.match(/name:\s*"([^"]+)"/)
      options
    end

    def compare_schemas(schema1, schema2, source1:, source2:)
      tables1 = schema1[:tables]
      tables2 = schema2[:tables]

      table_changes = identify_table_changes(tables1, tables2)
      change_details = collect_table_diffs(table_changes[:common], tables1, tables2)

      build_comparison_result(
        source1: source1,
        source2: source2,
        added_tables: table_changes[:added],
        removed_tables: table_changes[:removed],
        **change_details
      )
    end

    def identify_table_changes(tables1, tables2)
      table_names1 = Set.new(tables1.keys)
      table_names2 = Set.new(tables2.keys)

      {
        added: (table_names2 - table_names1).to_a.sort,
        removed: (table_names1 - table_names2).to_a.sort,
        common: (table_names1 & table_names2).to_a.sort
      }
    end

    def collect_table_diffs(common_tables, tables1, tables2)
      modified_tables = []
      added_columns = []
      removed_columns = []
      modified_columns = []
      added_indexes = []
      removed_indexes = []

      common_tables.each do |table_name|
        table_diff = compare_tables(table_name, tables1[table_name], tables2[table_name])
        next unless table_diff

        modified_tables << table_diff
        added_columns.concat(table_diff.column_changes.select { |c| c.change_type == :added })
        removed_columns.concat(table_diff.column_changes.select { |c| c.change_type == :removed })
        modified_columns.concat(table_diff.column_changes.select { |c| c.change_type == :modified })
        added_indexes.concat(table_diff.index_changes.select { |c| c.change_type == :added })
        removed_indexes.concat(table_diff.index_changes.select { |c| c.change_type == :removed })
      end

      {
        modified_tables: modified_tables,
        added_columns: added_columns,
        removed_columns: removed_columns,
        modified_columns: modified_columns,
        added_indexes: added_indexes,
        removed_indexes: removed_indexes
      }
    end

    def build_comparison_result(source1:, source2:, added_tables:, removed_tables:, modified_tables:,
                                 added_columns:, removed_columns:, modified_columns:,
                                 added_indexes:, removed_indexes:)
      identical = added_tables.empty? && removed_tables.empty? && modified_tables.empty?

      Result.new(
        source1: source1,
        source2: source2,
        identical: identical,
        added_tables: added_tables,
        removed_tables: removed_tables,
        modified_tables: modified_tables,
        added_columns: added_columns,
        removed_columns: removed_columns,
        modified_columns: modified_columns,
        added_indexes: added_indexes,
        removed_indexes: removed_indexes,
        summary: build_summary(added_tables, removed_tables, modified_tables)
      )
    end

    def compare_tables(table_name, table1, table2)
      column_changes = compare_columns(table1[:columns], table2[:columns])
      index_changes = compare_indexes(table1[:indexes], table2[:indexes])

      return nil if column_changes.empty? && index_changes.empty?

      TableDiff.new(
        table_name: table_name,
        column_changes: column_changes,
        index_changes: index_changes
      )
    end

    def compare_columns(columns1, columns2)
      changes = []

      col_names1 = Set.new(columns1.keys)
      col_names2 = Set.new(columns2.keys)

      # Added columns
      (col_names2 - col_names1).each do |name|
        changes << ColumnChange.new(
          column_name: name,
          change_type: :added,
          old_value: nil,
          new_value: columns2[name]
        )
      end

      # Removed columns
      (col_names1 - col_names2).each do |name|
        changes << ColumnChange.new(
          column_name: name,
          change_type: :removed,
          old_value: columns1[name],
          new_value: nil
        )
      end

      # Modified columns
      (col_names1 & col_names2).each do |name|
        next if columns1[name] == columns2[name]

        changes << ColumnChange.new(
          column_name: name,
          change_type: :modified,
          old_value: columns1[name],
          new_value: columns2[name]
        )
      end

      changes
    end

    def compare_indexes(indexes1, indexes2)
      changes = []

      # Normalize indexes for comparison
      idx_set1 = indexes1.map { |i| normalize_index(i) }.to_set
      idx_set2 = indexes2.map { |i| normalize_index(i) }.to_set

      # Added indexes
      (idx_set2 - idx_set1).each do |idx|
        changes << IndexChange.new(
          index_name: idx[:name],
          change_type: :added,
          old_definition: nil,
          new_definition: idx
        )
      end

      # Removed indexes
      (idx_set1 - idx_set2).each do |idx|
        changes << IndexChange.new(
          index_name: idx[:name],
          change_type: :removed,
          old_definition: idx,
          new_definition: nil
        )
      end

      changes
    end

    def normalize_index(index)
      {
        columns: index[:columns].sort,
        unique: index.dig(:options, :unique) || false,
        name: index.dig(:options, :name) || index[:columns].join("_")
      }
    end

    def build_summary(added, removed, modified)
      parts = []
      parts << "#{added.size} added" if added.any?
      parts << "#{removed.size} removed" if removed.any?
      parts << "#{modified.size} modified" if modified.any?
      parts.any? ? parts.join(", ") : "no changes"
    end

    def format_column_change(change)
      case change.change_type
      when :added
        "      ➕ #{change.column_name}: #{change.new_value[:type]}"
      when :removed
        "      ➖ #{change.column_name}: #{change.old_value[:type]}"
      when :modified
        "      🔄 #{change.column_name}: #{change.old_value[:type]} → #{change.new_value[:type]}"
      end
    end

    def format_index_change(change)
      case change.change_type
      when :added
        "      ➕ index: #{change.new_definition[:columns].join(', ')}"
      when :removed
        "      ➖ index: #{change.old_definition[:columns].join(', ')}"
      end
    end
  end
end
