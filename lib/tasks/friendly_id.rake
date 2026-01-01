# frozen_string_literal: true

namespace :friendly_id do
  desc "Generate slugs for all FormDefinitions that don't have one"
  task generate_slugs: :environment do
    puts "Generating slugs for FormDefinitions..."

    count = 0
    errors = []

    FormDefinition.find_each do |form|
      if form.slug.blank?
        # Generate slug from code: SC-100 → sc-100
        new_slug = form.code.downcase.gsub(/[^a-z0-9]/, "-").gsub(/-+/, "-").gsub(/^-|-$/, "")
        form.slug = new_slug
        if form.save
          puts "  ✓ #{form.code} → #{form.slug}"
          count += 1
        else
          errors << "  ✗ #{form.code}: #{form.errors.full_messages.join(', ')}"
        end
      end
    end

    puts "\nGenerated #{count} slugs"
    if errors.any?
      puts "\nErrors:"
      errors.each { |e| puts e }
    end
  end

  desc "Regenerate all slugs (overwrites existing)"
  task regenerate_slugs: :environment do
    puts "Regenerating all slugs for FormDefinitions..."

    count = 0
    FormDefinition.find_each do |form|
      new_slug = form.code.downcase.gsub(/[^a-z0-9]/, "-").gsub(/-+/, "-").gsub(/^-|-$/, "")
      form.update_column(:slug, new_slug)
      puts "  #{form.code} → #{new_slug}"
      count += 1
    end

    puts "\nRegenerated #{count} slugs"
  end

  desc "Show slug mapping for all forms"
  task show_slugs: :environment do
    puts "Form Code → Slug mapping:\n\n"
    FormDefinition.order(:code).each do |form|
      puts "  #{form.code.ljust(15)} → #{form.slug || '(none)'}"
    end
  end
end
