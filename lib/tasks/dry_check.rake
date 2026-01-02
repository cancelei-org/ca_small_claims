# frozen_string_literal: true

namespace :dry do
  desc "Run all DRY code analysis tools"
  task check: :environment do
    puts "\n" + "=" * 60
    puts "🔍 DRY Code Analysis"
    puts "=" * 60

    results = []

    # Run RuboCop with DRY-focused cops
    puts "\n📋 Running RuboCop (metrics & duplication)..."
    rubocop_result = system("bundle exec rubocop --only Metrics,Lint/Duplicate --format simple")
    results << { name: "RuboCop", success: rubocop_result }

    # Run Flay for structural similarity
    puts "\n🔄 Running Flay (structural similarity detection)..."
    puts "   Checking for duplicated code patterns..."
    flay_result = system("bundle exec flay app/ lib/ --mass 25 2>/dev/null || true")
    results << { name: "Flay", success: flay_result }

    # Run Reek for code smells
    puts "\n👃 Running Reek (code smell detection)..."
    reek_result = system("bundle exec reek app/ lib/ --no-progress --format simple 2>/dev/null || true")
    results << { name: "Reek", success: reek_result }

    # Run ESLint with DRY rules
    puts "\n📜 Running ESLint (JavaScript DRY rules)..."
    eslint_result = system("npm run js-lint -- --quiet 2>/dev/null || true")
    results << { name: "ESLint", success: eslint_result }

    # Summary
    puts "\n" + "=" * 60
    puts "📊 Summary"
    puts "=" * 60
    results.each do |r|
      status = r[:success] ? "✅" : "⚠️ "
      puts "  #{status} #{r[:name]}"
    end
    puts ""
  end

  desc "Run Flay to detect structurally similar code"
  task flay: :environment do
    puts "🔄 Detecting structurally similar code..."
    puts "   (Lower scores = less duplication, threshold = 25)"
    puts ""
    system("bundle exec flay app/ lib/ --mass 25 --diff")
  end

  desc "Run Reek to detect code smells"
  task reek: :environment do
    puts "👃 Detecting code smells..."
    system("bundle exec reek app/ lib/ --no-progress")
  end

  desc "Show DRY metrics summary"
  task metrics: :environment do
    puts "\n📊 Code Metrics Summary"
    puts "=" * 60

    # Count Ruby files and lines
    ruby_files = Dir.glob("app/**/*.rb").count
    ruby_lines = Dir.glob("app/**/*.rb").sum { |f| File.readlines(f).count rescue 0 }

    # Count JS files and lines
    js_files = Dir.glob("app/javascript/**/*.js").count
    js_lines = Dir.glob("app/javascript/**/*.js").sum { |f| File.readlines(f).count rescue 0 }

    # Count view files
    view_files = Dir.glob("app/views/**/*.erb").count

    puts "Ruby:       #{ruby_files} files, #{ruby_lines} lines"
    puts "JavaScript: #{js_files} files, #{js_lines} lines"
    puts "Views:      #{view_files} files"
    puts ""

    # Show largest files (potential refactor candidates)
    puts "🔴 Largest Ruby files (potential refactor candidates):"
    large_files = Dir.glob("app/**/*.rb")
      .map { |f| [ f, File.readlines(f).count ] rescue [ f, 0 ] }
      .sort_by { |_, lines| -lines }
      .first(5)

    large_files.each do |file, lines|
      puts "   #{lines.to_s.rjust(4)} lines: #{file.sub('app/', '')}"
    end
    puts ""
  end
end

# Add dry:check to the default lint task if it exists
Rake::Task[:lint].enhance([ "dry:check" ]) if Rake::Task.task_defined?(:lint)
