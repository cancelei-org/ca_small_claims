# frozen_string_literal: true

namespace :import do
  # Default paths - can be overridden with environment variables
  DEFAULT_PDF_SOURCE = "/home/cancelei/new_projects/gather_docs/ca_court_forms/data/by_language/en"
  DEFAULT_METADATA = "/home/cancelei/new_projects/gather_docs/ca_court_forms/data/analysis_results.json"

  desc "Import all California court forms (categories, forms, fields, and PDFs)"
  task all: :environment do
    importer = create_importer(skip_pdfs: false)
    importer.import!
    print_summary(importer)
  end

  desc "Import forms only (no PDF copying) - faster for testing"
  task forms: :environment do
    importer = create_importer(skip_pdfs: true)
    importer.import!
    print_summary(importer)
  end

  desc "Import Small Claims (SC) forms only"
  task small_claims: :environment do
    importer = create_importer(category_filter: "SC", skip_pdfs: false)
    importer.import!
    print_summary(importer)
  end

  desc "Create categories only (no forms or PDFs)"
  task categories: :environment do
    puts "Creating categories..."
    count = Forms::CategoryMapper.create_all!
    puts "Done. #{count} categories in database."
    puts
    puts "Categories by position:"
    Category.order(:position).each do |cat|
      puts "  #{cat.position.to_s.rjust(3)}. #{cat.slug.ljust(8)} - #{cat.name}"
    end
  end

  desc "Copy PDF templates only (no database changes)"
  task pdfs: :environment do
    source_dir = ENV.fetch("PDF_SOURCE_DIR", DEFAULT_PDF_SOURCE)

    puts "Copying PDF templates..."
    puts "  Source: #{source_dir}"
    puts "  Target: #{Rails.root.join('lib', 'pdf_templates')}"
    puts

    copier = Pdf::TemplateCopier.new(source_dir: source_dir)
    copier.copy_all!

    puts "Done!"
    puts "  Copied: #{copier.stats[:copied]}"
    puts "  Skipped (already up to date): #{copier.stats[:skipped]}"
    puts "  Errors: #{copier.stats[:errors]}"

    if copier.errors.any?
      puts
      puts "Errors:"
      copier.errors.each { |e| puts "  - #{e[:filename]}: #{e[:error]}" }
    end
  end

  desc "Dry run - preview what would be imported (no changes made)"
  task dry_run: :environment do
    importer = create_importer(dry_run: true, skip_pdfs: true)
    importer.import!
    print_summary(importer)
  end

  desc "Verbose dry run with detailed output"
  task dry_run_verbose: :environment do
    importer = create_importer(dry_run: true, skip_pdfs: true, verbose: true)
    importer.import!
    print_summary(importer)
  end

  desc "Show metadata statistics (no database changes)"
  task stats: :environment do
    metadata_path = ENV.fetch("METADATA_PATH", DEFAULT_METADATA)

    puts "Parsing metadata from: #{metadata_path}"
    puts

    parser = Forms::MetadataParser.new(metadata_path)
    stats = parser.stats

    puts "California Court Forms Statistics"
    puts "=" * 50
    puts
    puts "Overview:"
    puts "  Total forms: #{stats[:total_forms]}"
    puts "  Fillable forms: #{stats[:fillable_forms]} (#{(stats[:fillable_forms].to_f / stats[:total_forms] * 100).round(1)}%)"
    puts "  Non-fillable forms: #{stats[:non_fillable_forms]}"
    puts "  Total fields: #{stats[:total_fields]}"
    puts "  PII fields: #{stats[:total_pii_fields]}"
    puts "  Total size: #{(stats[:total_size_bytes] / 1024.0 / 1024.0).round(1)} MB"
    puts

    puts "Forms by Category (top 20):"
    parser.forms_by_category
          .sort_by { |_, count| -count }
          .first(20)
          .each do |prefix, count|
      prefix_str = prefix.to_s
      fillable = parser.fillable_by_category[prefix] || 0
      name = Forms::CategoryMapper.category_name(prefix_str) || "Unknown"
      puts "  #{prefix_str.ljust(8)} #{count.to_s.rjust(4)} forms (#{fillable.to_s.rjust(3)} fillable) - #{name}"
    end

    puts
    puts "Field Types:"
    stats[:field_types].sort_by { |_, count| -count }.each do |type, count|
      puts "  #{type.to_s.ljust(12)} #{count.to_s.rjust(6)}"
    end
  end

  desc "Rollback imported forms (CAUTION: deletes form data)"
  task rollback: :environment do
    puts "WARNING: This will delete all imported forms and their fields."
    puts "This action cannot be undone."
    puts
    print "Type 'DELETE' to confirm: "
    confirmation = $stdin.gets.chomp

    unless confirmation == "DELETE"
      puts "Aborted."
      exit 1
    end

    puts
    puts "Rolling back..."

    # Count before deletion
    form_count = FormDefinition.count
    field_count = FieldDefinition.count
    category_count = Category.count

    # Delete in order (respecting foreign keys)
    FieldDefinition.delete_all
    puts "  Deleted #{field_count} field definitions"

    # Delete forms that look like imports (have category prefix pattern)
    FormDefinition.where("code ~ '^[A-Z]+-\\d+'").delete_all
    deleted_forms = form_count - FormDefinition.count
    puts "  Deleted #{deleted_forms} form definitions"

    # Delete categories that are empty
    empty_categories = Category.left_joins(:form_definitions)
                               .where(form_definitions: { id: nil })
    deleted_categories = empty_categories.count
    empty_categories.delete_all
    puts "  Deleted #{deleted_categories} empty categories"

    puts
    puts "Rollback complete."
  end

  desc "Verify import - check for missing PDFs and data integrity"
  task verify: :environment do
    puts "Verifying import..."
    puts

    issues = []

    # Check for active forms without categories
    orphan_forms = FormDefinition.active.where(category_id: nil)
    issues << "#{orphan_forms.count} active forms without category_id" if orphan_forms.any?

    # Check for missing PDF files (only active forms)
    missing_pdfs = []
    FormDefinition.active.find_each do |form|
      missing_pdfs << form.code unless form.pdf_exists?
    end
    issues << "#{missing_pdfs.count} active forms with missing PDF files" if missing_pdfs.any?

    # Check for fillable forms without fields (only active forms)
    fillable_without_fields = FormDefinition.active.where(fillable: true)
                                            .left_joins(:field_definitions)
                                            .group("form_definitions.id")
                                            .having("COUNT(field_definitions.id) = 0")
                                            .count
                                            .count
    issues << "#{fillable_without_fields} active fillable forms without field definitions" if fillable_without_fields.positive?

    # Print results
    inactive_count = FormDefinition.where(active: false).count
    puts "Database counts:"
    puts "  Categories: #{Category.count}"
    puts "  Forms: #{FormDefinition.count} (#{inactive_count} inactive)"
    puts "  Fields: #{FieldDefinition.count}"
    puts "  Fillable forms: #{FormDefinition.active.where(fillable: true).count}"
    puts

    if issues.empty?
      puts "No issues found."
    else
      puts "Issues found:"
      issues.each { |issue| puts "  - #{issue}" }

      if missing_pdfs.any? && missing_pdfs.count <= 20
        puts
        puts "Missing PDFs:"
        missing_pdfs.each { |code| puts "  - #{code}" }
      end
    end
  end

  private

  def create_importer(options = {})
    pdf_source = ENV.fetch("PDF_SOURCE_DIR", DEFAULT_PDF_SOURCE)
    metadata = ENV.fetch("METADATA_PATH", DEFAULT_METADATA)

    Forms::BulkImporter.new(
      metadata_path: metadata,
      pdf_source_dir: pdf_source,
      options: options
    )
  end

  def print_summary(importer)
    if importer.stats[:errors].positive?
      exit_code = 1
      puts
      puts "Import completed with #{importer.stats[:errors]} errors."
    else
      exit_code = 0
    end

    exit(exit_code) if ENV["CI"]
  end
end
