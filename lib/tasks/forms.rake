# frozen_string_literal: true

namespace :forms do
  desc "Validate all form schemas"
  task validate: :environment do
    puts "Validating form schemas..."
    puts

    results = Forms::SchemaValidator.validate_all

    if results[:invalid].any?
      puts "ERRORS FOUND:"
      results[:invalid].each do |item|
        puts "  #{item[:file]}:"
        item[:errors].each { |e| puts "    - #{e}" }
      end
      puts
    end

    if results[:warnings].any?
      puts "WARNINGS:"
      results[:warnings].each do |item|
        puts "  #{item[:file]}:"
        item[:warnings].each { |w| puts "    - #{w}" }
      end
      puts
    end

    puts "Summary:"
    puts "  Valid schemas: #{results[:valid].count}"
    puts "  Invalid schemas: #{results[:invalid].count}"
    puts "  Schemas with warnings: #{results[:warnings].count}"

    # Check for shared key collisions
    collisions = Forms::SchemaValidator.check_shared_key_collisions
    if collisions.any?
      puts
      puts "SHARED KEY COLLISIONS:"
      collisions.each do |c|
        puts "  '#{c[:key]}' used in multiple forms: #{c[:forms].join(', ')}"
      end
    end

    exit(1) if results[:invalid].any?
  end

  desc "List all form schemas by category"
  task list: :environment do
    puts "Form Schemas by Category:"
    puts

    Category.roots.active.ordered.each do |parent|
      puts "#{parent.name}:"
      parent.children.active.ordered.each do |child|
        forms = FormDefinition.by_category_id(child.id).ordered
        next if forms.empty?

        puts "  #{child.name} (#{forms.count}):"
        forms.each do |form|
          status = form.fillable ? "fillable" : "non-fillable"
          puts "    - #{form.code}: #{form.title} [#{status}]"
        end
      end
      puts
    end
  end

  desc "Sync form schemas from YAML to database"
  task sync: :environment do
    puts "Syncing form schemas to database..."
    Forms::SchemaLoader.sync_to_database!
    puts "Done. #{FormDefinition.count} forms in database."
  end

  desc "Check for missing PDF templates"
  task check_pdfs: :environment do
    puts "Checking PDF templates..."
    missing = []

    FormDefinition.find_each do |form|
      missing << { code: form.code, file: form.pdf_filename } unless form.pdf_exists?
    end

    if missing.any?
      puts "Missing PDF templates:"
      missing.each { |m| puts "  #{m[:code]}: #{m[:file]}" }
      puts
      puts "Total missing: #{missing.count}"
    else
      puts "All PDF templates present."
    end
  end

  desc "Show schema statistics"
  task stats: :environment do
    puts "Form Schema Statistics"
    puts "======================"
    puts
    puts "Categories:"
    puts "  Parent categories: #{Category.roots.count}"
    puts "  Child categories: #{Category.where.not(parent_id: nil).count}"
    puts "  Active categories: #{Category.active.count}"
    puts
    puts "Forms:"
    puts "  Total forms: #{FormDefinition.count}"
    puts "  Fillable forms: #{FormDefinition.where(fillable: true).count}"
    puts "  Non-fillable forms: #{FormDefinition.where(fillable: false).count}"
    puts "  Active forms: #{FormDefinition.active.count}"
    puts
    puts "Fields:"
    puts "  Total fields: #{FieldDefinition.count}"
    puts "  Required fields: #{FieldDefinition.where(required: true).count}"
    puts "  Fields with shared keys: #{FieldDefinition.where.not(shared_field_key: nil).count}"
    puts
    puts "Workflows:"
    puts "  Total workflows: #{Workflow.count}"
    puts "  Active workflows: #{Workflow.active.count}"
    puts "  Total workflow steps: #{WorkflowStep.count}"
  end
end
