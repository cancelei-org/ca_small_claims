# frozen_string_literal: true

namespace :schemas do
  desc "Generate YAML schema for a single form (e.g., rake schemas:generate[SC-100])"
  task :generate, [ :form_code ] => :environment do |_t, args|
    unless args[:form_code]
      puts "Usage: rake schemas:generate[FORM_CODE]"
      puts "Example: rake schemas:generate[SC-100]"
      exit(1)
    end

    form_code = args[:form_code]
    puts "Generating schema for #{form_code}..."

    generator = Forms::SchemaGenerator.new(form_code)
    output_path = generator.generate_to_file

    if output_path
      puts "Schema generated: #{output_path}"
      puts "Warnings:" if generator.warnings.any?
      generator.warnings.each { |w| puts "  - #{w}" }
    else
      puts "Failed to generate schema:"
      generator.errors.each { |e| puts "  - #{e}" }
      exit(1)
    end
  end

  desc "Generate schemas for all forms with a given prefix (e.g., rake schemas:generate_category[SC])"
  task :generate_category, [ :prefix ] => :environment do |_t, args|
    unless args[:prefix]
      puts "Usage: rake schemas:generate_category[PREFIX]"
      puts "Example: rake schemas:generate_category[SC]"
      puts "Available prefixes: SC, FL, DV, CH, EA, GV, WV, SV, GC, JV, CR, etc."
      exit(1)
    end

    prefix = args[:prefix].upcase
    force = ENV["FORCE"] == "true"

    puts "Generating schemas for #{prefix} forms..."
    puts "Force mode: #{force}" if force
    puts

    results = Forms::SchemaGenerator.generate_batch(prefix, force: force)

    puts "Results:"
    puts "  Success: #{results[:success].count}"
    puts "  Failed: #{results[:failed].count}"
    puts "  Skipped (existing): #{results[:skipped].count}"
    puts

    if results[:success].any?
      puts "Generated schemas for:"
      results[:success].each { |code| puts "  - #{code}" }
      puts
    end

    if results[:failed].any?
      puts "Failed forms:"
      results[:failed].each do |item|
        puts "  - #{item[:code]}:"
        item[:errors].each { |e| puts "      #{e}" }
      end
      puts
    end

    if results[:skipped].any?
      puts "Skipped (use FORCE=true to regenerate):"
      results[:skipped].each { |code| puts "  - #{code}" }
    end
  end

  desc "Analyze PDFs and generate fillability report for a prefix"
  task :analyze, [ :prefix ] => :environment do |_t, args|
    unless args[:prefix]
      puts "Usage: rake schemas:analyze[PREFIX]"
      puts "Example: rake schemas:analyze[SC]"
      exit(1)
    end

    prefix = args[:prefix].upcase
    puts "Analyzing #{prefix} forms..."
    puts

    report = Forms::SchemaGenerator.analyze(prefix)

    if report.empty?
      puts "No PDFs found with prefix #{prefix}"
      exit(0)
    end

    fillable = report.count { |r| r[:fillable] }
    non_fillable = report.count { |r| !r[:fillable] }
    with_schema = report.count { |r| r[:has_schema] }

    puts format("%-15s %-10s %-10s %-10s", "Code", "Fillable?", "Fields", "Has Schema?")
    puts "-" * 50

    report.each do |r|
      puts format(
        "%-15s %-10s %-10d %-10s",
        r[:code],
        r[:fillable] ? "Yes" : "No",
        r[:field_count],
        r[:has_schema] ? "Yes" : "No"
      )
    end

    puts
    puts "Summary:"
    puts "  Total forms: #{report.count}"
    puts "  Fillable: #{fillable}"
    puts "  Non-fillable: #{non_fillable}"
    puts "  With schema: #{with_schema}"
    puts "  Without schema: #{report.count - with_schema}"
  end

  desc "Show implementation progress for all forms"
  task progress: :environment do
    tracker = Forms::ImplementationTracker.new
    tracker.print_summary
    tracker.save_progress
    puts "\nProgress saved to db/form_implementation_status.json"
  end

  desc "Show detailed progress for a specific category"
  task :progress_category, [ :prefix ] => :environment do |_t, args|
    unless args[:prefix]
      puts "Usage: rake schemas:progress_category[PREFIX]"
      exit(1)
    end

    prefix = args[:prefix].upcase
    tracker = Forms::ImplementationTracker.new
    report = tracker.category_report(prefix)

    puts "Progress for #{prefix} forms:"
    puts "=" * 50
    puts "  Total: #{report[:total]}"
    puts "  With schema: #{report[:with_schema]} (#{report[:schema_percent]}%)"
    puts "  In database: #{report[:in_database]} (#{report[:db_percent]}%)"
    puts "  With HTML template: #{report[:with_html_template]}"
    puts
    puts "Form details:"
    puts format("%-15s %-8s %-8s %-8s %-8s", "Code", "Schema", "DB", "HTML", "Fillable")
    puts "-" * 55

    report[:forms].each do |form|
      puts format(
        "%-15s %-8s %-8s %-8s %-8s",
        form[:code],
        form[:schema_exists] ? "Yes" : "No",
        form[:in_database] ? "Yes" : "No",
        form[:html_template_exists] ? "Yes" : "No",
        form[:fillable].nil? ? "-" : (form[:fillable] ? "Yes" : "No")
      )
    end
  end

  desc "List forms missing schemas"
  task missing: :environment do
    tracker = Forms::ImplementationTracker.new
    missing = tracker.missing_schemas

    if missing.empty?
      puts "All PDFs have corresponding schemas!"
    else
      puts "Forms missing schemas (#{missing.count}):"
      missing.each { |code| puts "  - #{code}" }
    end
  end

  desc "List non-fillable forms missing HTML templates"
  task missing_html: :environment do
    tracker = Forms::ImplementationTracker.new
    missing = tracker.missing_html_templates

    if missing.empty?
      puts "All non-fillable forms have HTML templates!"
    else
      puts "Non-fillable forms missing HTML templates (#{missing.count}):"
      missing.each { |code| puts "  - #{code}" }
    end
  end

  desc "Show manual review queue"
  task manual_review: :environment do
    tracker = Forms::ImplementationTracker.new
    queue = tracker.manual_review_queue

    pending = queue.select { |_k, v| v["status"] == "pending" }
    resolved = queue.select { |_k, v| v["status"] == "resolved" }

    if pending.empty?
      puts "No forms in manual review queue."
    else
      puts "Pending manual review (#{pending.count}):"
      pending.each do |code, info|
        puts "  #{code}:"
        puts "    Reason: #{info['reason']}"
        puts "    Added: #{info['added_at']}"
      end
    end

    if resolved.any?
      puts
      puts "Resolved (#{resolved.count}):"
      resolved.each do |code, info|
        puts "  #{code} - resolved at #{info['resolved_at']}"
      end
    end
  end

  desc "Add a form to manual review queue"
  task :add_manual_review, [ :form_code, :reason ] => :environment do |_t, args|
    unless args[:form_code] && args[:reason]
      puts "Usage: rake schemas:add_manual_review[FORM_CODE,'Reason for review']"
      exit(1)
    end

    tracker = Forms::ImplementationTracker.new
    tracker.add_to_manual_review(args[:form_code], args[:reason])
    puts "Added #{args[:form_code]} to manual review queue."
  end

  desc "Resolve a form from manual review queue"
  task :resolve_manual_review, [ :form_code ] => :environment do |_t, args|
    unless args[:form_code]
      puts "Usage: rake schemas:resolve_manual_review[FORM_CODE]"
      exit(1)
    end

    tracker = Forms::ImplementationTracker.new
    tracker.resolve_manual_review(args[:form_code])
    puts "Marked #{args[:form_code]} as resolved."
  end

  desc "Rollback schemas for a category (DELETE from database)"
  task :rollback_category, [ :prefix ] => :environment do |_t, args|
    unless args[:prefix]
      puts "Usage: rake schemas:rollback_category[PREFIX]"
      puts "WARNING: This will delete forms from the database!"
      exit(1)
    end

    prefix = args[:prefix].upcase

    unless ENV["CONFIRM"] == "true"
      puts "This will DELETE all #{prefix} forms from the database."
      puts "Run with CONFIRM=true to proceed."
      exit(1)
    end

    forms = FormDefinition.where("code LIKE ?", "#{prefix}-%")
    count = forms.count

    forms.find_each do |form|
      form.field_definitions.destroy_all
      form.destroy
    end

    puts "Rolled back #{count} #{prefix} forms."
  end

  desc "Full batch processing pipeline for a category"
  task :batch_process, [ :prefix ] => :environment do |_t, args|
    unless args[:prefix]
      puts "Usage: rake schemas:batch_process[PREFIX]"
      exit(1)
    end

    prefix = args[:prefix].upcase
    puts "=" * 60
    puts "BATCH PROCESSING: #{prefix} Forms"
    puts "=" * 60
    puts

    # Step 1: Analyze
    puts "Step 1: Analyzing PDFs..."
    Rake::Task["schemas:analyze"].invoke(prefix)
    Rake::Task["schemas:analyze"].reenable
    puts

    # Step 2: Generate schemas
    puts "Step 2: Generating schemas..."
    Rake::Task["schemas:generate_category"].invoke(prefix)
    Rake::Task["schemas:generate_category"].reenable
    puts

    # Step 3: Validate
    puts "Step 3: Validating schemas..."
    Rake::Task["forms:validate"].invoke
    Rake::Task["forms:validate"].reenable
    puts

    # Step 4: Sync to database
    puts "Step 4: Syncing to database..."
    Rake::Task["forms:sync"].invoke
    Rake::Task["forms:sync"].reenable
    puts

    # Step 5: Show progress
    puts "Step 5: Final progress..."
    Rake::Task["schemas:progress_category"].invoke(prefix)
    Rake::Task["schemas:progress_category"].reenable

    puts
    puts "=" * 60
    puts "Batch processing complete for #{prefix}"
    puts "=" * 60
  end
end
