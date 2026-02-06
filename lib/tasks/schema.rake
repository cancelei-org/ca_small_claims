# frozen_string_literal: true

# Schema Analysis and Comparison Tasks
# Tools for comparing and validating database schemas
#
# Usage:
#   bin/rails schema:compare[ca1]           # Compare local with burner
#   bin/rails schema:compare_burners[ca1,ca2]  # Compare two burners
#   bin/rails schema:report[ca1]            # Generate detailed report
#   bin/rails schema:validate               # Validate local schema structure

namespace :schema do
  desc "Compare local schema with burner instance"
  task :compare, [ :instance ] => :environment do |_t, args|
    instance = args[:instance] || "ca1"
    validate_burner_instance(instance)

    puts "Comparing local schema with #{instance}..."
    comparator = Schema::Comparator.new
    result = comparator.compare_local_with_burner(instance)

    puts comparator.format_report(result)

    exit(result.differences? ? 1 : 0)
  end

  desc "Compare schemas between two burner instances"
  task :compare_burners, [ :instance1, :instance2 ] => :environment do |_t, args|
    instance1 = args[:instance1] || "ca1"
    instance2 = args[:instance2] || "ca2"
    validate_burner_instance(instance1)
    validate_burner_instance(instance2)

    puts "Comparing #{instance1} with #{instance2}..."
    comparator = Schema::Comparator.new
    result = comparator.compare_burners(instance1, instance2)

    puts comparator.format_report(result)

    exit(result.differences? ? 1 : 0)
  end

  desc "Generate detailed comparison report as JSON"
  task :report, [ :instance ] => :environment do |_t, args|
    instance = args[:instance] || "ca1"
    validate_burner_instance(instance)

    comparator = Schema::Comparator.new
    result = comparator.compare_local_with_burner(instance)

    output_file = Rails.root.join("tmp", "schema_reports", "#{instance}_comparison.json")
    FileUtils.mkdir_p(output_file.dirname)

    report = {
      generated_at: Time.current.iso8601,
      source1: result.source1,
      source2: result.source2,
      identical: result.identical,
      summary: result.summary,
      added_tables: result.added_tables,
      removed_tables: result.removed_tables,
      modified_tables: result.modified_tables.map { |t| serialize_table_diff(t) }
    }

    File.write(output_file, JSON.pretty_generate(report))
    puts "Report saved to: #{output_file}"
  end

  desc "Validate local schema structure"
  task validate: :environment do
    puts "Validating schema structure..."

    schema_path = Rails.root.join("db", "schema.rb")
    abort "❌ Schema file not found: #{schema_path}" unless File.exist?(schema_path)

    content = File.read(schema_path)
    errors = []
    warnings = []

    # Check for version
    errors << "Missing or invalid schema version" unless content.match?(/ActiveRecord::Schema\[\d+\.\d+\]\.define\(version:/)

    # Check for common issues
    warnings << "Schema contains both force: :cascade and if_exists options" if content.include?("force: :cascade") && content.include?("if_exists")

    # Check table definitions
    tables = content.scan(/create_table\s+"([^"]+)"/).flatten
    if tables.empty?
      warnings << "No tables found in schema"
    else
      puts "✅ Found #{tables.size} tables"
    end

    # Check for duplicate table definitions
    duplicates = tables.group_by(&:itself).select { |_, v| v.size > 1 }.keys
    duplicates.each do |table|
      errors << "Duplicate table definition: #{table}"
    end

    # Check for orphaned indexes
    index_tables = content.scan(/add_index\s+"([^"]+)"/).flatten
    orphaned_indexes = index_tables - tables
    orphaned_indexes.each do |table|
      errors << "Index references non-existent table: #{table}"
    end

    # Check for foreign keys referencing missing tables
    fk_tables = content.scan(/add_foreign_key\s+"([^"]+)",\s*"([^"]+)"/).flatten.uniq
    missing_fk_tables = fk_tables - tables
    missing_fk_tables.each do |table|
      warnings << "Foreign key references potentially missing table: #{table}"
    end

    if errors.any?
      puts "\n❌ Errors:"
      errors.each { |e| puts "   • #{e}" }
    end

    if warnings.any?
      puts "\n⚠️  Warnings:"
      warnings.each { |w| puts "   • #{w}" }
    end

    puts "\n✅ Schema validation passed!" if errors.empty? && warnings.empty?

    abort if errors.any?
  end

  desc "Dump local schema to temp directory for comparison"
  task dump: :environment do
    output_file = Rails.root.join("tmp", "burner_schemas", "local_schema.rb")
    FileUtils.mkdir_p(output_file.dirname)
    FileUtils.cp(Rails.root.join("db", "schema.rb"), output_file)
    puts "Schema dumped to: #{output_file}"
  end

  desc "Generate migration from schema differences"
  task :generate_migration, [ :instance, :name ] => :environment do |_t, args|
    instance = args[:instance] || "ca1"
    name = args[:name] || "sync_with_#{instance}"
    validate_burner_instance(instance)

    comparator = Schema::Comparator.new
    result = comparator.compare_local_with_burner(instance)

    if result.identical
      puts "✅ Schemas are identical - no migration needed"
      exit 0
    end

    migration_content = generate_migration_content(result, name)

    # Generate migration file
    timestamp = Time.current.strftime("%Y%m%d%H%M%S")
    migration_file = Rails.root.join("db", "migrate", "#{timestamp}_#{name.underscore}.rb")

    File.write(migration_file, migration_content)
    puts "Migration generated: #{migration_file}"
  end

  # Helper methods
  def validate_burner_instance(instance)
    valid = %w[ca1 ca2 ca3]
    abort "Invalid burner instance: #{instance}. Valid: #{valid.join(', ')}" unless valid.include?(instance)
  end

  def serialize_table_diff(table_diff)
    {
      table_name: table_diff.table_name,
      column_changes: table_diff.column_changes.map do |c|
        {
          column_name: c.column_name,
          change_type: c.change_type.to_s,
          old_value: c.old_value,
          new_value: c.new_value
        }
      end,
      index_changes: table_diff.index_changes.map do |i|
        {
          index_name: i.index_name,
          change_type: i.change_type.to_s
        }
      end
    }
  end

  def generate_migration_content(result, name)
    lines = generate_migration_header(result, name)
    lines.concat(generate_added_tables(result))
    lines.concat(generate_removed_tables(result))
    lines.concat(generate_modified_tables(result))
    lines << "  end"
    lines << "end"
    lines << ""

    lines.join("\n")
  end

  def generate_migration_header(result, name)
    [
      "# frozen_string_literal: true",
      "",
      "# Auto-generated migration to sync schema differences",
      "# Source: #{result.source1} vs #{result.source2}",
      "# Generated: #{Time.current.iso8601}",
      "",
      "class #{name.camelize} < ActiveRecord::Migration[8.0]",
      "  def change"
    ]
  end

  def generate_added_tables(result)
    result.added_tables.flat_map do |table_name|
      [
        "    # TODO: Define table structure for #{table_name}",
        "    # create_table :#{table_name} do |t|",
        "    #   t.timestamps",
        "    # end",
        ""
      ]
    end
  end

  def generate_removed_tables(result)
    result.removed_tables.map do |table_name|
      "    drop_table :#{table_name}, if_exists: true"
    end
  end

  def generate_modified_tables(result)
    result.modified_tables.flat_map do |table_diff|
      [
        "",
        "    # Changes for #{table_diff.table_name}",
        *generate_column_changes(table_diff),
        *generate_index_changes(table_diff)
      ]
    end
  end

  def generate_column_changes(table_diff)
    table_diff.column_changes.map do |change|
      case change.change_type
      when :added
        "    add_column :#{table_diff.table_name}, :#{change.column_name}, :#{change.new_value[:type]}"
      when :removed
        "    remove_column :#{table_diff.table_name}, :#{change.column_name}"
      when :modified
        "    change_column :#{table_diff.table_name}, :#{change.column_name}, :#{change.new_value[:type]}"
      end
    end
  end

  def generate_index_changes(table_diff)
    table_diff.index_changes.map do |change|
      case change.change_type
      when :added
        cols = change.new_definition[:columns].map { |c| ":#{c}" }.join(", ")
        "    add_index :#{table_diff.table_name}, [#{cols}]"
      when :removed
        cols = change.old_definition[:columns].map { |c| ":#{c}" }.join(", ")
        "    remove_index :#{table_diff.table_name}, [#{cols}]"
      end
    end
  end
end
